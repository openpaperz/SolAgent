// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/utils/cryptography/ECDSA.sol";
import "contracts/utils/cryptography/EIP712.sol";

/// @notice Minimal ERC-2771 compatible forwarder contract implementing forwarding logic,
///         EIP-712 signature verification and batch execution with refund support.
contract ERC2771Forwarder is EIP712 {
    using ECDSA for bytes32;

    /// @notice Struct describing a forwarded request.
    struct ForwardRequestData {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 deadline;
        bytes data;
        bytes signature;
    }

    // EIP-712 typehash for ForwardRequestData (note: `data` is hashed as bytes)
    bytes32 private constant _FORWARD_REQUEST_TYPEHASH =
        keccak256(
            "ForwardRequestData(address from,address to,uint256 value,uint256 gas,uint256 deadline,bytes data)"
        );

    /* Errors */
    error FailedCall();
    error NotTrustedForwarder();
    error RequestExpired();
    error InvalidSigner();
    error ValueMismatch();
    error RefundFailed();

    /* Events */
    event ForwardRequestExecuted(address indexed from, address indexed to, uint256 value, bool success);

    /// @notice Initialize EIP-712 domain with provided name and version "1".
    constructor(string memory name) EIP712(name, "1") {}

    /**
     * @notice Verifies the validity of a forward request by checking if the forwarder is trusted,
     *         active (not expired), and if the signer matches.
     */
    function verify(ForwardRequestData calldata request) public virtual view returns (bool) {
        (bool isTrustedForwarder, bool active, bool signerMatch, ) = _validate(request);
        return isTrustedForwarder && active && signerMatch;
    }

    /**
     * @notice Executes a forwarded request, ensuring the sent value matches the requested value.
     *         Reverts if the forwarded call fails.
     */
    function execute(ForwardRequestData calldata request) public virtual payable {
        if (msg.value != request.value) revert ValueMismatch();

        bool success = _execute(request, true);
        if (!success) revert FailedCall();
    }

    /**
     * @notice Executes a batch of forward requests and handles refunds for failed requests.
     *
     * @param requests Array of ForwardRequestData
     * @param refundReceiver If address(0) -> atomic (no refunds). Otherwise, non-atomic and refunds to this address.
     */
    function executeBatch(ForwardRequestData[] calldata requests, address payable refundReceiver)
        public
        virtual
        payable
    {
        bool atomic = (refundReceiver == address(0));
        uint256 totalValue = 0;
        uint256 refunds = 0;

        // Execute each request
        for (uint256 i = 0; i < requests.length; ++i) {
            ForwardRequestData calldata req = requests[i];
            totalValue += req.value;

            if (atomic) {
                // atomic: require all succeed, revert on any failure
                bool ok = _execute(req, true);
                if (!ok) revert FailedCall();
            } else {
                // non-atomic: attempt to execute but collect refunds for failed ones
                bool ok = _execute(req, false);
                if (!ok) {
                    refunds += req.value;
                }
            }
        }

        // Ensure total value matches supplied value (prevents tampering)
        if (totalValue != msg.value) revert ValueMismatch();

        // If refunds are due, send them to refundReceiver (non-atomic only)
        if (!atomic && refunds > 0) {
            (bool sent, ) = refundReceiver.call{value: refunds}("");
            if (!sent) revert RefundFailed();
        }
    }

    /**
     * @notice Validates a forward request:
     *  - whether this forwarder is trusted by the target,
     *  - whether the request is still active (deadline),
     *  - whether the recovered signer matches request.from.
     *
     * @return isTrustedForwarder True if target contract recognizes this forwarder.
     * @return active True if block.timestamp <= deadline.
     * @return signerMatch True if recovered signer equals request.from.
     * @return signer The recovered signer address (zero if invalid).
     */
    function _validate(ForwardRequestData calldata request)
        internal
        virtual
        view
        returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer)
    {
        isTrustedForwarder = _isTrustedByTarget(request.to);
        active = block.timestamp <= request.deadline;

        (bool isValidSig, address recovered) = _recoverForwardRequestSigner(request);
        signer = isValidSig ? recovered : address(0);
        signerMatch = isValidSig && (recovered == request.from);
    }

    /**
     * @notice Recovers the signer of a forward request and checks if signature is valid.
     *
     * @return isValid true if a signer could be recovered without error.
     * @return signer recovered address (address(0) on failure).
     */
    function _recoverForwardRequestSigner(ForwardRequestData calldata request)
        internal
        virtual
        view
        returns (bool isValid, address signer)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                _FORWARD_REQUEST_TYPEHASH,
                request.from,
                request.to,
                request.value,
                request.gas,
                request.deadline,
                keccak256(request.data)
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);

        // tryRecover returns (address, RecoverError)
        (address recovered, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, request.signature);
        if (err == ECDSA.RecoverError.NoError) {
            return (true, recovered);
        } else {
            return (false, address(0));
        }
    }

    /**
     * @notice Executes a forwarded request after validating authenticity and expiration.
     *
     * @param request The forwarded request data.
     * @param requireValidRequest If true, revert on invalid requests; if false, try to execute regardless.
     * @return success True if the low-level call to target returned successfully.
     */
    function _execute(ForwardRequestData calldata request, bool requireValidRequest)
        internal
        virtual
        returns (bool success)
    {
        (bool isTrustedForwarder, bool active, bool signerMatch, ) = _validate(request);

        if (requireValidRequest) {
            if (!isTrustedForwarder) revert NotTrustedForwarder();
            if (!active) revert RequestExpired();
            if (!signerMatch) revert InvalidSigner();
        }

        // Perform the call to target with provided gas and value.
        // Note: we do not append the original sender's address to calldata here.
        // Call may succeed or fail; we return the status to the caller.
        (success, ) = request.to.call{gas: request.gas, value: request.value}(request.data);

        // Protect against insufficient gas griefing by ensuring enough gas remained after subcall.
        _checkForwardedGas(gasleft(), request);

        emit ForwardRequestExecuted(request.from, request.to, request.value, success);
    }

    /**
     * @notice Checks whether target contract recognizes this forwarder as trusted.
     * @dev Calls target.isTrustedForwarder(address) via staticcall and expects a boolean return.
     */
    function _isTrustedByTarget(address target) private view returns (bool) {
        // selector for: isTrustedForwarder(address)
        bytes4 selector = bytes4(keccak256("isTrustedForwarder(address)"));
        (bool ok, bytes memory returndata) = target.staticcall(abi.encodeWithSelector(selector, address(this)));

        if (!ok || returndata.length < 32) return false;
        return abi.decode(returndata, (bool));
    }

    /**
     * @notice Prevents insufficient gas griefing by inspecting remaining gas after the subcall.
     * @dev Reverts via invalid opcode if gasLeft is suspiciously small (gasLeft < request.gas / 63).
     *      This mirrors checks used to ensure sufficient gas was forwarded.
     */
    function _checkForwardedGas(uint256 gasLeft, ForwardRequestData calldata request) private pure {
        // If the remaining gas is less than a small fraction of requested gas, trigger invalid opcode to consume gas and revert.
        // The fraction 1/63 is chosen to leave a small margin similar to historical checks.
        if (gasLeft < request.gas / 63) {
            // Use invalid opcode to consume remaining gas and revert.
            assembly {
                invalid()
            }
        }
    }

    // Allow contract to receive ETH (from forwarded calls)
    receive() external payable {}
}