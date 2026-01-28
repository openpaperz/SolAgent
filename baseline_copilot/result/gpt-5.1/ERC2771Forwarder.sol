// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EIP712} from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ERC2771Forwarder
 * @notice A minimal ERC-2771 style forwarder using EIP-712 signed meta-transactions.
 */
contract ERC2771Forwarder is EIP712 {
    using ECDSA for bytes32;

    /**
     * @notice Defines a struct `ForwardRequestData` used for forwarding transactions.
     *
     * @param from The address initiating the transaction (sender).
     * @param to The address receiving the transaction (recipient).
     * @param value The amount of Ether (in wei) to be sent with the transaction.
     * @param gas The amount of gas allocated for the transaction.
     * @param deadline The timestamp until which the transaction is valid.
     * @param data The encoded function call data to be executed.
     * @param signature The signature of the transaction for verification purposes.
     */
    struct ForwardRequestData {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 deadline;
        bytes data;
        bytes signature;
    }

    /// @dev Nonces for each signer to prevent replay attacks.
    mapping(address => uint256) private _nonces;

    /// @dev EIP712 type hash for ForwardRequestData.
    bytes32 private constant _FORWARD_REQUEST_TYPEHASH =
        keccak256(
            "ForwardRequestData(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint256 deadline,bytes data)"
        );

    /// @notice Emitted after executing a forwarded request.
    event ForwardRequestExecuted(
        address indexed from,
        address indexed to,
        bool success,
        uint256 value,
        bytes data
    );

    /// @notice Nonce used when hashing/signing a request.
    function nonces(address account) external view returns (uint256) {
        return _nonces[account];
    }

    /**
     * @notice Initializes the contract with a name and sets up EIP712 domain separator.
     *
     * @param name The name of the contract, used to generate the EIP712 domain separator.
     *
     * Steps:
     * 1. Call the EIP712 constructor with the provided name and version "1" to set up the domain separator.
     */
    constructor(string memory name) EIP712(name, "1") {}

    /**
     * @notice Verifies the validity of a forward request by checking if the forwarder is trusted, active, and if the signer matches.
     *
     * Steps:
     * 1. Calls the internal `_validate` function to check the following:
     *    - Whether the forwarder is trusted.
     *    - Whether the forwarder is active.
     *    - Whether the signer of the request matches the expected signer.
     *
     * 2. Returns `true` if all checks pass (forwarder is trusted, active, and signer matches), otherwise returns `false`.
     */
    function verify(ForwardRequestData calldata request) public virtual view returns (bool) {
        (bool isTrustedForwarder, bool active, bool signerMatch, ) = _validate(request);
        return isTrustedForwarder && active && signerMatch;
    }

    /**
     * @notice Executes a forwarded request, ensuring the sent value matches the requested value.
     *
     * Steps:
     * 1. Check if the sent value (`msg.value`) matches the requested value (`request.value`).
     *    - If they do not match, revert with an error indicating the mismatch.
     * 2. Attempt to execute the request using the internal `_execute` function.
     *    - If the execution fails, revert with a "FailedCall" error.
     * 3. The function ensures that no value is stuck if the request is invalid or the call reverts.
     */
    function execute(ForwardRequestData calldata request) public virtual payable {
        if (msg.value != request.value) {
            revert("ERC2771Forwarder: value mismatch");
        }

        bool success = _execute(request, true);
        if (!success) {
            revert("ERC2771Forwarder: FailedCall");
        }
    }

    /**
     * @notice Executes a batch of forward requests and handles refunds for failed requests.
     *
     * Steps:
     * 1. Determine if the batch execution is atomic (no refund receiver provided).
     * 2. Initialize variables to track the total value of requests and refunds.
     *
     * 3. Iterate through each request in the batch:
     *    - Accumulate the total value of all requests.
     *    - Attempt to execute the request using `_execute`.
     *    - If the execution fails, accumulate the refund value.
     *
     * 4. Revert the entire batch if the total value of requests does not match the provided `msg.value`.
     *    This prevents tampering with request values.
     *
     * 5. If there are any refunds due to failed requests:
     *    - Send the refund value to the specified `refundReceiver`.
     *    - Ensure the refund does not affect the contract's balance and is sent to a known account.
     */
    function executeBatch(ForwardRequestData[] calldata requests, address payable refundReceiver) public virtual payable {
        uint256 length = requests.length;
        uint256 totalRequestedValue = 0;
        uint256 refundValue = 0;
        bool atomic = refundReceiver == address(0);

        for (uint256 i = 0; i < length; i++) {
            ForwardRequestData calldata req = requests[i];
            totalRequestedValue += req.value;

            bool success = _execute(req, !atomic);
            if (!success) {
                refundValue += req.value;
                if (atomic) {
                    revert("ERC2771Forwarder: atomic batch failed");
                }
            }
        }

        if (totalRequestedValue != msg.value) {
            revert("ERC2771Forwarder: total value mismatch");
        }

        if (refundValue > 0) {
            require(refundReceiver != address(0), "ERC2771Forwarder: refund receiver required");
            (bool sent, ) = refundReceiver.call{value: refundValue}("");
            require(sent, "ERC2771Forwarder: refund failed");
        }
    }

    /**
     * @notice Validates a forward request by checking the following:
     * 1. Whether the forwarder is trusted by the target contract.
     * 2. Whether the request is still active (i.e., the deadline has not passed).
     * 3. Whether the recovered signer matches the `from` address in the request.
     * 4. Returns the recovered signer address.
     *
     * @param request The forward request data to validate.
     * @return isTrustedForwarder True if the forwarder is trusted by the target.
     * @return active True if the request is still active (deadline not passed).
     * @return signerMatch True if the recovered signer matches the `from` address.
     * @return signer The address of the recovered signer.
     */
    function _validate(
        ForwardRequestData calldata request
    ) internal virtual view returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        isTrustedForwarder = _isTrustedByTarget(request.to);
        active = request.deadline == 0 || block.timestamp <= request.deadline;

        (bool isValid, address recovered) = _recoverForwardRequestSigner(request);
        signer = recovered;
        signerMatch = isValid && recovered == request.from;
    }

    /**
     * @notice Recovers the signer of a forward request and checks if the signature is valid.
     *
     * Steps:
     * 1. Compute the hash of the forward request data using the EIP-712 typed data format.
     * 2. Attempt to recover the signer's address from the provided signature using the computed hash.
     * 3. Return a tuple containing:
     *    - A boolean indicating whether the signature is valid (no error during recovery).
     *    - The recovered signer's address.
     */
    function _recoverForwardRequestSigner(
        ForwardRequestData calldata request
    ) internal virtual view returns (bool isValid, address signer) {
        bytes32 structHash = keccak256(
            abi.encode(
                _FORWARD_REQUEST_TYPEHASH,
                request.from,
                request.to,
                request.value,
                request.gas,
                _nonces[request.from],
                request.deadline,
                keccak256(request.data)
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        (address recovered, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, request.signature);
        isValid = (err == ECDSA.RecoverError.NoError) && recovered != address(0);
        signer = recovered;
    }

    /**
     * @notice Executes a forwarded request after validating its authenticity and expiration.
     *
     * Steps:
     * 1. Validate the request by checking if the forwarder is trusted, if the request is active, and if the signer matches.
     * 2. If `requireValidRequest` is true, revert the transaction if:
     *    - The forwarder is not trusted.
     *    - The request is expired.
     *    - The signer does not match the expected signer.
     * 3. If the request is valid (trusted forwarder, active, and signer match), proceed with execution:
     *    - Use the signer's nonce to prevent replay attacks.
     *    - Extract the gas, target address, value, and data from the request.
     *    - Execute the call to the target address with the provided data and gas.
     *    - Check the remaining gas to ensure the call was executed correctly.
     *    - Emit an event indicating the execution status of the request.
     *
     * @param request The forwarded request data containing details like target address, gas, value, and data.
     * @param requireValidRequest A flag indicating whether the request must be valid for execution.
     * @return success A boolean indicating whether the execution was successful.
     */
    function _execute(
        ForwardRequestData calldata request,
        bool requireValidRequest
    ) internal virtual returns (bool success) {
        (bool isTrustedForwarder, bool active, bool signerMatch, ) = _validate(request);

        if (requireValidRequest) {
            require(isTrustedForwarder, "ERC2771Forwarder: untrusted forwarder");
            require(active, "ERC2771Forwarder: request expired");
            require(signerMatch, "ERC2771Forwarder: invalid signature");
        }

        if (!(isTrustedForwarder && active && signerMatch)) {
            return false;
        }

        // Increment nonce to prevent replay
        _nonces[request.from]++;

        uint256 gasLimit = request.gas;
        address to = request.to;
        uint256 value = request.value;
        bytes calldata data = request.data;

        // solhint-disable-next-line avoid-low-level-calls
        (success, ) = to.call{gas: gasLimit, value: value}(data);

        uint256 gasLeft = gasleft();
        _checkForwardedGas(gasLeft, request);

        emit ForwardRequestExecuted(request.from, to, success, value, data);
    }

    /**
     * @notice Checks if the current contract is trusted by the target contract.
     *
     * Steps:
     * 1. Encode the `isTrustedForwarder` function call with the current contract's address as the parameter.
     * 2. Perform a static call to the target contract using the encoded parameters.
     * 3. Check if the call was successful and if the return data size is at least 32 bytes.
     * 4. Return true if the call was successful, the return data size is valid, and the return value is greater than 0.
     */
    function _isTrustedByTarget(address target) private view returns (bool) {
        bytes memory encoded = abi.encodeWithSignature("isTrustedForwarder(address)", address(this));

        (bool ok, bytes memory returndata) = target.staticcall(encoded);
        if (!ok || returndata.length < 32) {
            return false;
        }

        uint256 result;
        assembly {
            result := mload(add(returndata, 0x20))
        }

        return result != 0;
    }

    /**
     * @notice Checks if the forwarded gas is sufficient to avoid insufficient gas griefing attacks.
     *
     * @dev This function ensures that the subcall received sufficient gas by inspecting `gasleft()` after the forwarding.
     * A malicious relayer could attempt to shrink the gas forwarded, causing the subcall to revert out-of-gas while the
     * forwarding itself succeeds. This function prevents such attacks by verifying that the gas left after the subcall
     * is sufficient.
     *
     * Steps:
     * 1. Calculate if the remaining gas (`gasLeft`) is less than `request.gas / 63`.
     * 2. If the condition is met, trigger an invalid opcode to consume all gas and revert the transaction.
     *    This ensures that the relayer cannot exploit insufficient gas scenarios.
     *
     * @param gasLeft The amount of gas remaining after the subcall.
     * @param request The forwarded request data containing the required gas amount.
     */
    function _checkForwardedGas(uint256 gasLeft, ForwardRequestData calldata request) private pure {
        if (gasLeft < request.gas / 63) {
            // Consume all gas and revert using invalid opcode
            assembly {
                invalid()
            }
        }
    }
}