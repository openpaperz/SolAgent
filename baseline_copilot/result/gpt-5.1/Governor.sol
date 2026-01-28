// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "repository/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "repository/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC1155Receiver} from "repository/openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "repository/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {Address} from "repository/openzeppelin-contracts/contracts/utils/Address.sol";
import {EIP712} from "repository/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "repository/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @dev Minimal IGovernor interface subset used for supportsInterface.
 */
interface IGovernor is IERC165 {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
}

/**
 * @dev Example custom errors mirroring OpenZeppelin Governor.
 */
error GovernorNonexistentProposal();
error GovernorOnlyExecutor(address executor);
error GovernorDisabledDeposit();
error GovernorRestrictedProposer(address proposer);
error GovernorInsufficientProposerVotes(address proposer, uint256 votes, uint256 threshold);
error GovernorUnexpectedProposalState(uint256 proposalId, IGovernor.ProposalState current, bytes32 allowed);
error GovernorInvalidSignature(address signer, address expected);
error GovernorQueueNotImplemented();

/**
 * @dev Simple access control modifier for governance-only functions.
 */
abstract contract GovernorBaseAccess {
    modifier onlyGovernance() {
        _checkGovernance();
        _;
    }

    function _checkGovernance() internal virtual;
}

/**
 * @title Governor
 * @dev A simplified but functional governance contract implementing the plan in plan.txt.
 */
contract Governor is
    IGovernor,
    ERC165,
    IERC1155Receiver,
    IERC721Receiver,
    EIP712,
    GovernorBaseAccess
{
    using Address for address;

    /**
     * @notice Defines the core structure for a proposal in the governance system.
     *
     * Fields:
     * - proposer: The address of the account that created the proposal.
     * - voteStart: The timestamp when voting for this proposal started.
     * - voteDuration: The duration of the voting period in seconds.
     * - executed: A boolean flag indicating whether the proposal has been executed.
     * - canceled: A boolean flag indicating whether the proposal has been canceled.
     * - etaSeconds: The estimated time of arrival (ETA) for execution, stored as seconds.
     */
    struct ProposalCore {
        address proposer;
        uint48 voteStart;
        uint32 voteDuration;
        bool executed;
        bool canceled;
        uint48 etaSeconds;
    }

    // EIP712 typehashes for signatures
    bytes32 private constant _VOTE_TYPEHASH =
        keccak256("Vote(uint256 proposalId,uint8 support,address voter,uint256 nonce)");
    bytes32 private constant _VOTE_WITH_PARAMS_TYPEHASH =
        keccak256(
            "VoteWithReasonAndParams(uint256 proposalId,uint8 support,address voter,string reason,bytes params,uint256 nonce)"
        );

    // Name of the Governor
    string private _name;

    // Proposal storage
    mapping(uint256 => ProposalCore) private _proposals;

    // Simple voting record: proposal => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) private _hasVoted;

    // Nonces used for signatures per voter
    mapping(address => uint256) private _nonces;

    // Governance call queue used by _checkGovernance
    bytes32[] private _governanceCallQueue;

    /**
     * @notice Initializes the contract with a name and sets up the EIP712 domain separator.
     *
     * @param name_ The name of the contract, which is used to initialize the EIP712 domain.
     *
     * Steps:
     * 1. Call the EIP712 constructor with the provided name and the version returned by `version()`.
     * 2. Assign the provided name to the `_name` state variable.
     */
    constructor(string memory name_) EIP712(name_, version()) {
        _name = name_;
    }

    /**
     * @notice Checks if this contract supports a given interface ID.
     *
     * This function overrides the supportsInterface function from both ERC165 and IERC165
     * to verify support for specific interfaces including:
     * - IERC1155Receiver interface
     * - IGovernor interface
     *
     * It returns true if the interface ID matches either of these supported interfaces,
     * or if the parent contract's supportsInterface method returns true for the given ID.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IGovernor).interfaceId ||
            ERC165.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the name of the token.
     *
     * This is a virtual view function that returns the internal `_name` variable.
     * It allows derived contracts to override this behavior while providing a default implementation.
     *
     * @return The name of the token as a string.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the version string of the contract.
     *
     * @return string memory The version string "1".
     */
    function version() public pure virtual returns (string memory) {
        return "1";
    }

    /**
     * @notice Computes a unique hash for a proposal based on its parameters.
     *
     * This function takes the targets, values, calldatas, and description hash of a proposal
     * and returns a keccak256 hash of their ABI-encoded concatenation.
     *
     * @param targets Array of contract addresses to call.
     * @param values Array of ether values to send with each call.
     * @param calldatas Array of encoded function calls.
     * @param descriptionHash Hash of the proposal's description.
     * @return The computed proposal ID as a uint256.
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(targets, values, calldatas, descriptionHash)
                )
            );
    }

    /**
     * @notice Returns the current state of a governance proposal based on its ID.
     *
     * Steps:
     * 1. Retrieve the proposal data from storage using the provided proposal ID.
     * 2. Check if the proposal has been executed.
     * 3. If executed, return ProposalState.Executed.
     *
     * 4. Check if the proposal has been canceled.
     * 5. If canceled, return ProposalState.Canceled.
     *
     * 6. Get the snapshot block number for the proposal.
     * 7. If no snapshot exists, revert with GovernorNonexistentProposal error.
     *
     * 8. Get the current timepoint (block timestamp or similar).
     * 9. If the snapshot is greater than or equal to current timepoint, return ProposalState.Pending.
     *
     * 10. Calculate the proposal deadline.
     * 11. If the deadline is greater than or equal to current timepoint, return ProposalState.Active.
     *
     * 12. If the quorum was not reached or the vote did not succeed, return ProposalState.Defeated.
     * 13. If the proposal has an ETA (estimated time of arrival) set to zero, return ProposalState.Succeeded.
     *
     * 14. Otherwise, return ProposalState.Queued.
     */
    function state(uint256 proposalId)
        public
        view
        virtual
        returns (IGovernor.ProposalState)
    {
        ProposalCore storage proposal = _proposals[proposalId];

        if (proposal.executed) {
            return IGovernor.ProposalState.Executed;
        }

        if (proposal.canceled) {
            return IGovernor.ProposalState.Canceled;
        }

        uint256 snapshot = proposalSnapshot(proposalId);
        if (snapshot == 0) {
            revert GovernorNonexistentProposal();
        }

        uint256 currentTimepoint = clock();
        if (snapshot >= currentTimepoint) {
            return IGovernor.ProposalState.Pending;
        }

        uint256 deadline_ = proposalDeadline(proposalId);
        if (deadline_ >= currentTimepoint) {
            return IGovernor.ProposalState.Active;
        }

        if (!_quorumReached(proposalId) || !_voteSucceeded(proposalId)) {
            return IGovernor.ProposalState.Defeated;
        }

        if (proposal.etaSeconds == 0) {
            return IGovernor.ProposalState.Succeeded;
        }

        return IGovernor.ProposalState.Queued;
    }

    /**
     * @notice Returns the proposal threshold value.
     *
     * @return uint256 The proposal threshold, which is hardcoded to 0.
     */
    function proposalThreshold() public view virtual returns (uint256) {
        return 0;
    }

    /**
     * @notice Returns the snapshot block number for a given proposal.
     *
     * @param proposalId The ID of the proposal to retrieve the snapshot for.
     * @return The snapshot block number associated with the proposal.
     */
    function proposalSnapshot(uint256 proposalId)
        public
        view
        virtual
        returns (uint256)
    {
        ProposalCore storage proposal = _proposals[proposalId];
        return proposal.voteStart;
    }

    /**
     * @notice Calculates the deadline for a proposal's voting period.
     *
     * @param proposalId The ID of the proposal to calculate the deadline for.
     * @return The block number representing the voting deadline.
     *
     * Steps:
     * 1. Retrieve the proposal data using the provided proposalId.
     * 2. Access the voteStart and voteDuration fields of the proposal.
     * 3. Add voteStart and voteDuration to compute the deadline.
     * 4. Return the calculated deadline.
     */
    function proposalDeadline(uint256 proposalId)
        public
        view
        virtual
        returns (uint256)
    {
        ProposalCore storage proposal = _proposals[proposalId];
        return uint256(proposal.voteStart) + uint256(proposal.voteDuration);
    }

    /**
     * @notice Retrieves the proposer address for a given proposal ID.
     *
     * @param proposalId The ID of the proposal to query.
     * @return The address of the proposer who submitted the proposal.
     */
    function proposalProposer(uint256 proposalId)
        public
        view
        virtual
        returns (address)
    {
        return _proposals[proposalId].proposer;
    }

    /**
     * @notice Returns the estimated time (in seconds since Unix epoch) when a governance proposal will be queued.
     *
     * @param proposalId The ID of the governance proposal.
     * @return The estimated queue time in seconds since Unix epoch.
     */
    function proposalEta(uint256 proposalId)
        public
        view
        virtual
        returns (uint256)
    {
        return _proposals[proposalId].etaSeconds;
    }

    /**
     * @notice Indicates whether a proposal needs to be queued.
     * @dev This function always returns false, indicating that no proposals require queuing.
     * @return bool Always returns false.
     */
    function proposalNeedsQueuing(uint256) public view virtual returns (bool) {
        return false;
    }

    /**
     * @notice Internal virtual function that checks governance permissions.
     *
     * This function verifies that the caller has the proper governance rights:
     * 1. If the executor is not the message sender, it reverts with a GovernorOnlyExecutor error.
     * 2. If the executor is not the contract address itself, it:
     *    - Calculates the keccak256 hash of the message data
     *    - Loops through the governance call queue until it finds the expected operation hash
     *    - Throws an error if the operation is not found in the queue (operation not authorized)
     */
    function _checkGovernance() internal virtual override {
        address executor = _executor();
        if (executor != msg.sender) {
            revert GovernorOnlyExecutor(executor);
        }

        if (executor != address(this)) {
            bytes32 opHash = keccak256(msg.data);
            bool found;
            uint256 len = _governanceCallQueue.length;
            for (uint256 i = 0; i < len; i++) {
                if (_governanceCallQueue[i] == opHash) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                revert GovernorOnlyExecutor(executor);
            }
        }
    }

    /**
     * @notice Checks if the quorum has been reached for a specific proposal.
     *
     * @param proposalId The ID of the proposal to check.
     * @return bool Returns `true` if the quorum has been reached, otherwise `false`.
     *
     * @dev This is an internal, view function that is meant to be overridden by derived contracts.
     * It should implement the logic to determine whether the quorum (minimum required votes) has been met for the given proposal.
     */
    function _quorumReached(uint256 proposalId)
        internal
        view
        virtual
        returns (bool)
    {
        proposalId; // silence warning
        return true;
    }

    /**
     * @notice Checks if a proposal has succeeded based on its ID.
     *
     * @param proposalId The unique identifier of the proposal to check.
     * @return bool Returns `true` if the proposal has succeeded, otherwise `false`.
     *
     * @dev This is an internal, view function that is marked as `virtual`, allowing it to be overridden by derived contracts.
     * The specific logic for determining whether a proposal has succeeded is left to the implementing contract.
     */
    function _voteSucceeded(uint256 proposalId)
        internal
        view
        virtual
        returns (bool)
    {
        proposalId; // silence warning
        return true;
    }

    /**
     * @notice A virtual function to retrieve the number of votes for a given account at a specific timepoint.
     *
     * @param account The address of the account for which votes are being queried.
     * @param timepoint The specific timepoint (e.g., block number) at which to check the votes.
     * @param params Additional parameters that may be required for the vote calculation.
     *
     * @return uint256 The number of votes associated with the account at the specified timepoint.
     *
     * @dev This function is marked as `internal`, `view`, and `virtual`, meaning it can be overridden by derived contracts.
     * It is intended to be used in voting mechanisms where votes are time-dependent or context-dependent.
     */
    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory params
    ) internal view virtual returns (uint256) {
        account;
        timepoint;
        params;
        return 1;
    }

    /**
     * @notice Internal function to count a vote for a specific proposal.
     *
     * @param proposalId The ID of the proposal for which the vote is being counted.
     * @param account The address of the account casting the vote.
     * @param support The level of support for the proposal (e.g., 0 = against, 1 = for, 2 = abstain).
     * @param totalWeight The total weight of the vote, which may be influenced by delegation or other factors.
     * @param params Additional parameters that may be required for the vote counting logic.
     *
     * @return uint256 The updated weight of the vote after counting.
     *
     * This function is intended to be overridden by derived contracts to implement custom vote counting logic.
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 totalWeight,
        bytes memory params
    ) internal virtual returns (uint256) {
        proposalId;
        account;
        support;
        params;
        return totalWeight;
    }

    /**
     * @notice A virtual internal function that is intended to be overridden by derived contracts.
     * @dev This function appears to be a hook or callback that gets triggered when a tally is updated,
     *      likely related to governance proposals. The function currently does nothing but can be
     *      implemented by inheriting contracts to add custom behavior when a proposal's tally changes.
     */
    function _tallyUpdated(uint256 proposalId) internal virtual {
        proposalId;
    }

    /**
     * @notice Returns the default parameters for the contract.
     *
     * @return bytes The default parameters as a byte array, which is empty in this implementation.
     */
    function _defaultParams() internal view virtual returns (bytes memory) {
        return "";
    }

    /**
     * @notice Proposes a new governance proposal with specified targets, values, calldatas, and description.
     *
     * @param targets The addresses of the contracts to be called as part of the proposal.
     * @param values The amounts of Ether (in wei) to be sent with each call.
     * @param calldatas The encoded function calls to be executed on the target contracts.
     * @param description A human-readable description of the proposal.
     *
     * @return proposalId The unique identifier for the newly created proposal.
     *
     * Steps:
     * 1. Retrieve the address of the proposer (`msg.sender`).
     * 2. Check if the description is valid for the proposer. If not, revert with `GovernorRestrictedProposer`.
     * 3. Check if the proposer meets the required voting threshold. If not, revert with `GovernorInsufficientProposerVotes`.
     * 4. If all checks pass, call the internal `_propose` function to create the proposal and return the proposal ID.
     *
     * Reverts:
     * - If the proposer is restricted from proposing with the given description.
     * - If the proposer does not meet the required voting threshold.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (uint256) {
        address proposer = msg.sender;

        if (!_isValidDescriptionForProposer(proposer, description)) {
            revert GovernorRestrictedProposer(proposer);
        }

        uint256 votes = _getVotes(
            proposer,
            clock() - 1,
            _defaultParams()
        );
        uint256 threshold = proposalThreshold();
        if (votes < threshold) {
            revert GovernorInsufficientProposerVotes(
                proposer,
                votes,
                threshold
            );
        }

        return _propose(targets, values, calldatas, description, proposer);
    }

    /**
     * @notice Internal virtual function to propose a new governance proposal.
     *
     * Steps:
     * 1. Hash the proposal using the provided parameters.
     * 2. Validate that the lengths of targets, values, and calldatas arrays are equal and non-zero.
     * 3. Check that the proposal does not already exist.
     * 4. Calculate the snapshot block and voting period.
     * 5. Store the proposal details including proposer, vote start time, and duration.
     * 6. Emit a ProposalCreated event with all relevant proposal data.
     *
     * @param targets Array of contract addresses to call
     * @param values Array of value amounts to send with each call
     * @param calldatas Array of encoded calldata for each call
     * @param description Human-readable description of the proposal
     * @param proposer Address of the proposer
     * @return proposalId The unique identifier for the newly created proposal
     */
    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal virtual returns (uint256 proposalId) {
        require(
            targets.length == values.length &&
                targets.length == calldatas.length &&
                targets.length != 0,
            "Governor: invalid proposal length"
        );

        bytes32 descriptionHash = keccak256(bytes(description));
        proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        ProposalCore storage proposal = _proposals[proposalId];
        require(
            proposal.proposer == address(0),
            "Governor: proposal already exists"
        );

        uint48 snapshot = clock() + uint48(votingDelay());
        uint32 duration = uint32(votingPeriod());

        proposal.proposer = proposer;
        proposal.voteStart = snapshot;
        proposal.voteDuration = duration;

        emit ProposalCreated(
            proposalId,
            proposer,
            targets,
            values,
            calldatas,
            snapshot,
            snapshot + duration,
            description
        );
    }

    /**
     * @notice Queues a governance proposal for execution after a delay.
     *
     * Steps:
     * 1. Hash the proposal parameters to generate a unique proposal ID.
     * 2. Validate that the proposal is in the Succeeded state before queuing.
     * 3. Queue the proposal operations and calculate the execution time (etaSeconds).
     * 4. If etaSeconds is valid, store it in the proposal and emit a ProposalQueued event.
     * 5. If etaSeconds is zero, revert with GovernorQueueNotImplemented error.
     *
     * Returns the proposal ID of the queued proposal.
     */
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        _validateStateBitmap(
            proposalId,
            _encodeStateBitmap(IGovernor.ProposalState.Succeeded)
        );

        uint48 eta = _queueOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
        if (eta == 0) {
            revert GovernorQueueNotImplemented();
        }

        _proposals[proposalId].etaSeconds = eta;

        emit ProposalQueued(proposalId, eta);

        return proposalId;
    }

    /**
     * @notice Internal virtual function that simulates queuing operations for a proposal.
     *
     * This function is intended to be overridden by derived contracts to implement
     * specific logic for queuing operations. Currently, it returns a fixed value of 0.
     *
     * Parameters:
     * - proposalId: The ID of the proposal (unused in this implementation).
     * - targets: Array of target addresses for the operations (unused in this implementation).
     * - values: Array of values for the operations (unused in this implementation).
     * - calldatas: Array of calldata for the operations (unused in this implementation).
     * - descriptionHash: Hash of the proposal description (unused in this implementation).
     *
     * Returns:
     * - uint48: Always returns 0 in this implementation.
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual returns (uint48) {
        proposalId;
        targets;
        values;
        calldatas;
        descriptionHash;
        return 0;
    }

    /**
     * @notice Executes a queued proposal by calling target contracts with specified calldatas.
     *
     * Steps:
     * 1. Hash the proposal using the provided parameters to generate a unique proposal ID.
     * 2. Validate that the proposal is either in Succeeded or Queued state.
     * 3. Mark the proposal as executed to prevent reentrancy.
     *
     * 4. If the executor is not this contract, iterate through targets to check for governance calls.
     * 5. For any target that matches this contract's address, add the calldata hash to the governance call queue.
     *
     * 6. Execute the operations defined by the proposal using the target addresses, values, and calldatas.
     *
     * 7. After execution, if the executor is not this contract and the governance call queue is not empty,
     *    clear the queue to clean up state.
     *
     * 8. Emit a ProposalExecuted event to signal completion.
     *
     * 9. Return the proposal ID.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        _validateStateBitmap(
            proposalId,
            _encodeStateBitmap(IGovernor.ProposalState.Succeeded) |
                _encodeStateBitmap(IGovernor.ProposalState.Queued)
        );

        ProposalCore storage proposal = _proposals[proposalId];
        proposal.executed = true;

        address executor = _executor();

        if (executor != address(this)) {
            uint256 len = targets.length;
            for (uint256 i = 0; i < len; i++) {
                if (targets[i] == address(this)) {
                    _governanceCallQueue.push(
                        keccak256(calldatas[i])
                    );
                }
            }
        }

        _executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );

        if (executor != address(this) && _governanceCallQueue.length != 0) {
            delete _governanceCallQueue;
        }

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    /**
     * @notice Executes a series of operations defined by target addresses, values, and calldata.
     *
     * This internal virtual function iterates through the provided targets, values, and calldata arrays,
     * and executes each operation by calling the target address with the corresponding value and calldata.
     * It uses the `Address.verifyCallResult` function to verify the success of each call and handle any returned data.
     *
     * Parameters:
     * - proposalId: Unused parameter (included for interface compatibility).
     * - targets: Array of addresses to call.
     * - values: Array of values (in wei) to send with each call.
     * - calldatas: Array of calldata to include with each call.
     * - descriptionHash: Unused parameter (included for interface compatibility).
     *
     * Loop:
     * 1. For each index i in the arrays:
     *    a. Perform a low-level call to targets[i] with values[i] and calldatas[i].
     *    b. Verify the result using Address.verifyCallResult to ensure success.
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual {
        proposalId;
        descriptionHash;

        uint256 len = targets.length;
        for (uint256 i = 0; i < len; i++) {
            (bool success, bytes memory returndata) = targets[i].call{
                value: values[i]
            }(calldatas[i]);
            Address.verifyCallResult(
                success,
                returndata,
                "Governor: call reverted"
            );
        }
    }

    /**
     * @notice Cancels a governance proposal if the caller is the proposer and the proposal is in Pending state.
     *
     * Steps:
     * 1. Compute the proposal ID using the provided parameters and the `hashProposal` function.
     * 2. Validate that the proposal is in the Pending state using `_validateStateBitmap`.
     * 3. Check that the caller is the original proposer of the proposal.
     * 4. If validation passes, call the internal `_cancel` function with the same parameters.
     * 5. Return the proposal ID from the internal `_cancel` call.
     *
     * Requirements:
     * - The proposal must be in Pending state.
     * - Only the original proposer can cancel the proposal.
     */
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        IGovernor.ProposalState currentState = _validateStateBitmap(
            proposalId,
            _encodeStateBitmap(IGovernor.ProposalState.Pending)
        );

        require(
            currentState == IGovernor.ProposalState.Pending,
            "Governor: not pending"
        );
        require(
            proposalProposer(proposalId) == msg.sender,
            "Governor: only proposer can cancel"
        );

        return
            _cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Cancels a proposal if it is in a valid state.
     *
     * Steps:
     * 1. Hash the proposal using the provided parameters.
     * 2. Validate that the proposal is in a state that allows cancellation.
     *    The proposal must not already be canceled, expired, or executed.
     * 3. Mark the proposal as canceled.
     * 4. Emit a ProposalCanceled event.
     * 5. Return the proposal ID.
     *
     * @param targets Array of contract addresses to call.
     * @param values Array of ether values to send with each call.
     * @param calldatas Array of encoded function calls.
     * @param descriptionHash Hash of the proposal description.
     * @return proposalId The ID of the canceled proposal.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual returns (uint256) {
        uint256 proposalId = hashProposal(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        ProposalCore storage proposal = _proposals[proposalId];

        require(!proposal.canceled, "Governor: already canceled");
        require(!proposal.executed, "Governor: already executed");

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);

        return proposalId;
    }

    /**
     * @notice Retrieves the number of votes for a given account at a specific timepoint.
     *
     * @param account The address of the account for which votes are being queried.
     * @param timepoint The specific timepoint at which to query the votes.
     * @return uint256 The number of votes held by the account at the specified timepoint.
     *
     * Steps:
     * 1. Calls the internal `_getVotes` function with the provided account, timepoint, and default parameters.
     * 2. Returns the number of votes for the account at the given timepoint.
     */
    function getVotes(address account, uint256 timepoint)
        public
        view
        virtual
        returns (uint256)
    {
        return _getVotes(account, timepoint, _defaultParams());
    }

    /**
     * @notice Retrieves the number of votes for an account at a specific timepoint with additional parameters.
     *
     * @param account The address of the account to query votes for.
     * @param timepoint The block number or timestamp to check votes at.
     * @param params Additional parameters to pass to the internal vote calculation.
     *
     * @return The number of votes the account has at the specified timepoint.
     */
    function getVotesWithParams(
        address account,
        uint256 timepoint,
        bytes memory params
    ) public view virtual returns (uint256) {
        return _getVotes(account, timepoint, params);
    }

    /**
     * @notice Casts a vote for a proposal with the given support value.
     *
     * Steps:
     * 1. Retrieves the address of the message sender as the voter.
     * 2. Calls the internal _castVote function with the proposal ID, voter address, support value, and an empty reason string.
     * 3. Returns the vote receipt ID from the internal vote casting function.
     *
     * @param proposalId The ID of the proposal to vote on.
     * @param support The support value for the vote (0 = against, 1 = for, 2 = abstain).
     * @return uint256 The vote receipt ID.
     */
    function castVote(uint256 proposalId, uint8 support)
        public
        virtual
        returns (uint256)
    {
        address voter = msg.sender;
        return _castVote(proposalId, voter, support, "");
    }

    /**
     * @notice Casts a vote with a reason for a specific proposal.
     *
     * Steps:
     * 1. Retrieves the address of the message sender (voter).
     * 2. Calls the internal _castVote function with the proposal ID, voter address, support type, and reason.
     * 3. Returns the vote receipt ID from the internal voting function.
     *
     * @param proposalId The ID of the proposal to vote on.
     * @param support The support value for the vote (0=Against, 1=For, 2=Abstain).
     * @param reason A string explaining the reason for the vote.
     * @return uint256 The vote receipt ID.
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public virtual returns (uint256) {
        address voter = msg.sender;
        return _castVote(proposalId, voter, support, reason);
    }

    /**
     * @notice Casts a vote with reason and additional parameters for a given proposal.
     *
     * Steps:
     * 1. Retrieves the address of the message sender (voter).
     * 2. Calls the internal `_castVote` function with the proposal ID, voter address,
     *    support type, reason, and additional parameters.
     * 3. Returns the vote receipt ID from the internal voting function.
     *
     * @param proposalId The ID of the proposal to vote on.
     * @param support The type of vote (0 = Against, 1 = For, 2 = Abstain).
     * @param reason A string providing justification for the vote.
     * @param params Additional encoded parameters for the vote.
     * @return uint256 The ID of the vote receipt.
     */
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) public virtual returns (uint256) {
        address voter = msg.sender;
        return _castVote(proposalId, voter, support, reason, params);
    }

    /**
     * @notice Casts a vote on a proposal using an external signature.
     *
     * Steps:
     * 1. Hash the typed data containing the proposal ID, support value, voter address, and nonce.
     * 2. Validate the provided signature against the hashed data and the voter's address.
     * 3. If the signature is invalid, revert with GovernorInvalidSignature error.
     * 4. If the signature is valid, proceed to cast the vote using the internal _castVote function.
     *
     * @param proposalId The ID of the proposal to vote on.
     * @param support The support value for the vote (0 = against, 1 = for, 2 = abstain).
     * @param voter The address of the voter.
     * @param signature The signature data used to validate the vote.
     * @return The weight of the vote cast.
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        bytes memory signature
    ) public virtual returns (uint256) {
        uint256 nonce = _useNonce(voter);
        bytes32 structHash = keccak256(
            abi.encode(
                _VOTE_TYPEHASH,
                proposalId,
                support,
                voter,
                nonce
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, signature);

        if (signer != voter) {
            revert GovernorInvalidSignature(signer, voter);
        }

        return _castVote(proposalId, voter, support, "");
    }

    /**
     * @notice Casts a vote with reason and parameters using an external signature.
     *
     * Steps:
     * 1. Validates the provided signature against the expected typed data hash.
     * 2. If the signature is invalid, reverts with GovernorInvalidSignature error.
     * 3. If the signature is valid, proceeds to cast the vote with the provided parameters.
     *
     * Parameters:
     * - proposalId: The ID of the proposal to vote on.
     * - support: The support value for the vote (0 = Against, 1 = For, 2 = Abstain).
     * - voter: The address of the voter.
     * - reason: The reason for the vote.
     * - params: Additional parameters for the vote.
     * - signature: The signature of the voter.
     *
     * Returns:
     * - The vote weight for the cast vote.
     */
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        string calldata reason,
        bytes memory params,
        bytes memory signature
    ) public virtual returns (uint256) {
        uint256 nonce = _useNonce(voter);
        bytes32 structHash = keccak256(
            abi.encode(
                _VOTE_WITH_PARAMS_TYPEHASH,
                proposalId,
                support,
                voter,
                keccak256(bytes(reason)),
                keccak256(params),
                nonce
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, signature);

        if (signer != voter) {
            revert GovernorInvalidSignature(signer, voter);
        }

        return _castVote(proposalId, voter, support, reason, params);
    }

    /**
     * @notice Internal function to cast a vote for a proposal.
     *
     * Parameters:
     * - proposalId: The ID of the proposal to vote on.
     * - account: The address of the account casting the vote.
     * - support: The type of vote (0 = Against, 1 = For, 2 = Abstain).
     * - reason: An optional reason for the vote.
     *
     * Steps:
     * 1. Call the internal _castVote function with the provided parameters and default parameters.
     * 2. Return the result of the vote casting operation.
     */
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason
    ) internal virtual returns (uint256) {
        return
            _castVote(
                proposalId,
                account,
                support,
                reason,
                _defaultParams()
            );
    }

    /**
     * @notice Internal function to cast a vote for a proposal.
     *
     * Parameters:
     * - proposalId: The ID of the proposal to vote on.
     * - account: The address of the account casting the vote.
     * - support: The type of vote (0 = Against, 1 = For, 2 = Abstain).
     * - reason: An optional reason for the vote.
     *
     * Steps:
     * 1. Call the internal _castVote function with the provided parameters and default parameters.
     * 2. Return the result of the vote casting operation.
     */
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual returns (uint256) {
        require(
            !_hasVoted[proposalId][account],
            "Governor: vote already cast"
        );
        _hasVoted[proposalId][account] = true;

        uint256 weight = _getVotes(
            account,
            proposalSnapshot(proposalId),
            params
        );
        uint256 countedWeight = _countVote(
            proposalId,
            account,
            support,
            weight,
            params
        );

        _tallyUpdated(proposalId);

        emit VoteCast(
            account,
            proposalId,
            support,
            countedWeight,
            reason
        );

        return countedWeight;
    }

    /**
     * @notice Relays a call to a target address with specified value and data.
     *
     * Steps:
     * 1. Verify that the caller is the governance address.
     * 2. Execute a low-level call to the target address with the provided value and data.
     * 3. Verify the result of the call using Address.verifyCallResult.
     *
     * @param target The address to call.
     * @param value The amount of ETH to send with the call.
     * @param data The calldata to send with the call.
     */
    function relay(
        address target,
        uint256 value,
        bytes calldata data
    ) external virtual onlyGovernance {
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        Address.verifyCallResult(
            success,
            returndata,
            "Governor: relay reverted"
        );
    }

    /**
     * @notice Internal virtual function that returns the address of the contract itself.
     *
     * This function serves as a getter for the contract's own address and is marked as virtual,
     * allowing derived contracts to override its implementation if needed.
     *
     * @return The address of the current contract instance.
     */
    function _executor() internal view virtual returns (address) {
        return address(this);
    }

    /**
     * @notice Implements the ERC721 receiver interface to handle received NFTs.
     *
     * This function is called when an ERC721 token is sent to this contract.
     * It validates that the executor matches the contract address before allowing
     * the transfer to proceed.
     *
     * Steps:
     * 1. Check if the executor (caller) matches the contract's own address.
     * 2. If not, revert with GovernorDisabledDeposit error.
     * 3. Return the selector for this function to confirm successful receipt.
     *
     * @return bytes4 The function selector indicating successful receipt.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        if (_executor() != address(this)) {
            revert GovernorDisabledDeposit();
        }
        return this.onERC721Received.selector;
    }

    /**
     * @notice Handles the reception of ERC1155 tokens.
     *
     * This function is called when ERC1155 tokens are sent to this contract.
     * It validates that the executor address matches the contract address,
     * and reverts if they don't match.
     *
     * @return bytes4.selector The function selector indicating successful receipt.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        if (_executor() != address(this)) {
            revert GovernorDisabledDeposit();
        }
        return this.onERC1155Received.selector;
    }

    /**
     * @notice Implements the ERC1155 batch receive function with executor validation.
     *
     * This function is called when ERC1155 tokens are batch transferred to this contract.
     * It validates that the caller is the authorized executor before allowing the receive operation.
     *
     * Steps:
     * 1. Check if the current executor (retrieved via _executor()) matches the contract's address.
     * 2. If not equal, revert with GovernorDisabledDeposit error.
     * 3. Return the function selector indicating successful processing.
     *
     * @return bytes4 The function selector indicating successful processing
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        if (_executor() != address(this)) {
            revert GovernorDisabledDeposit();
        }
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @notice Encodes a ProposalState enum value into a bytes32 bitmap.
     *
     * @param proposalState The ProposalState enum value to encode.
     * @return bytes32 A bytes32 value representing the encoded state bitmap.
     *
     * The function converts the enum value to its underlying uint8 representation,
     * shifts 1 left by that amount, and returns it as bytes32.
     */
    function _encodeStateBitmap(IGovernor.ProposalState proposalState)
        internal
        pure
        returns (bytes32)
    {
        return bytes32(1 << uint8(proposalState));
    }

    /**
     * @notice Validates that a proposal's current state matches one of the allowed states.
     *
     * Steps:
     * 1. Retrieve the current state of the proposal using its ID.
     * 2. Encode the current state into a bitmap format.
     * 3. Check if the encoded state intersects with the allowed states bitmap.
     * 4. If there is no intersection, revert with an error indicating the unexpected state.
     * 5. Return the current state if it is valid.
     */
    function _validateStateBitmap(
        uint256 proposalId,
        bytes32 allowedStates
    ) internal view returns (IGovernor.ProposalState) {
        IGovernor.ProposalState current = state(proposalId);
        bytes32 bitmap = _encodeStateBitmap(current);
        if ((bitmap & allowedStates) == 0) {
            revert GovernorUnexpectedProposalState(
                proposalId,
                current,
                allowedStates
            );
        }
        return current;
    }

    /**
     * @notice Checks if the provided description is valid for the given proposer by verifying the presence and correctness of a proposer suffix.
     *
     * @param proposer The address of the proposer to validate against the description.
     * @param description The description string to be validated.
     * @return bool Returns `true` if the description is valid for the proposer, otherwise `false`.
     *
     * Steps:
     * 1. Calculate the length of the description.
     * 2. If the description length is less than 52 characters, it is considered valid (no suffix to check).
     * 3. Extract the last 52 characters of the description to check for the `#proposer=` marker.
     * 4. If the marker is not found, the description is considered valid.
     * 5. If the marker is found, attempt to parse the last 42 characters as an Ethereum address.
     * 6. Return `true` if the parsed address matches the proposer's address, otherwise `false`.
     *
     * @dev The function uses unchecked arithmetic for gas optimization and assumes the description is a valid UTF-8 string.
     */
    function _isValidDescriptionForProposer(
        address proposer,
        string memory description
    ) internal view virtual returns (bool) {
        proposer;
        bytes memory descBytes = bytes(description);
        uint256 len = descBytes.length;

        if (len < 52) {
            return true;
        }

        uint256 start = len - 52;
        bytes memory suffix = new bytes(52);
        for (uint256 i = 0; i < 52; i++) {
            suffix[i] = descBytes[start + i];
        }

        bytes memory prefix = "#proposer=";
        bool hasPrefix = true;
        for (uint256 i = 0; i < prefix.length; i++) {
            if (suffix[i] != prefix[i]) {
                hasPrefix = false;
                break;
            }
        }

        if (!hasPrefix) {
            return true;
        }

        bytes memory addrBytes = new bytes(40);
        for (uint256 i = 0; i < 40; i++) {
            addrBytes[i] = suffix[12 + i];
        }

        address parsed = _parseAddress(addrBytes);

        return parsed == proposer;
    }

    /**
     * @notice A virtual function that returns the current timestamp or block number as a `uint48`.
     *
     * @return uint48 The current timestamp or block number, depending on the implementation.
     *
     * This function is intended to be overridden by derived contracts to provide specific logic
     * for determining the current time or block number.
     */
    function clock() public view virtual returns (uint48) {
        return uint48(block.timestamp);
    }

    /**
     * @notice Returns the clock mode of the contract.
     *
     * @return string memory A string representing the clock mode of the contract.
     *
     * This function is typically used in time-based contracts to indicate the mode of the clock (e.g., block-based or timestamp-based).
     */
    function CLOCK_MODE() public view virtual returns (string memory) {
        return "mode=timestamp";
    }

    /**
     * @notice Returns the voting delay for the governance system.
     *
     * @dev This function is marked as `virtual`, meaning it can be overridden by derived contracts.
     * It is also marked as `view`, indicating that it does not modify the state of the contract.
     *
     * @return uint256 The voting delay, typically representing the number of blocks or time units
     * before a proposal can be voted on.
     */
    function votingDelay() public view virtual returns (uint256) {
        return 0;
    }

    /**
     * @notice Returns the duration of the voting period.
     *
     * @return uint256 The duration of the voting period in seconds.
     *
     * This function is marked as `virtual`, meaning it can be overridden by derived contracts.
     * It is also marked as `view`, indicating that it does not modify the state of the contract.
     */
    function votingPeriod() public view virtual returns (uint256) {
        return 1 days;
    }

    /**
     * @notice A virtual function that calculates the quorum required at a specific timepoint.
     *
     * @param timepoint The timepoint (e.g., block number or timestamp) at which the quorum is calculated.
     * @return The quorum value required at the given timepoint.
     *
     * @dev This function is marked as `virtual`, meaning it can be overridden by derived contracts to provide custom quorum logic.
     */
    function quorum(uint256 timepoint)
        public
        view
        virtual
        returns (uint256)
    {
        timepoint;
        return 0;
    }

    /**
     * @notice Reads a bytes32 value from a buffer at a specific offset without bounds checking.
     *
     * @dev This is an unsafe memory operation that assumes all calls are within bounds.
     *      It directly accesses memory using inline assembly to load data from the buffer.
     *
     * @param buffer The input bytes array to read from.
     * @param offset The byte offset to start reading from.
     * @return value The bytes32 value read from the specified offset.
     */
    function _unsafeReadBytesOffset(
        bytes memory buffer,
        uint256 offset
    ) private pure returns (bytes32 value) {
        assembly {
            value := mload(add(add(buffer, 0x20), offset))
        }
    }

    /**
     * @dev Helper to parse an address from 40 hex characters (without 0x).
     */
    function _parseAddress(
        bytes memory hexChars
    ) private pure returns (address) {
        require(hexChars.length == 40, "Governor: invalid addr length");
        uint160 addr = 0;
        for (uint256 i = 0; i < 40; i += 2) {
            addr <<= 8;
            uint8 high = _fromHexChar(uint8(hexChars[i]));
            uint8 low = _fromHexChar(uint8(hexChars[i + 1]));
            addr |= uint160(uint16(high) << 4 | uint16(low));
        }
        return address(addr);
    }

    /**
     * @dev Convert a single hex char to its value.
     */
    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (c >= 48 && c <= 57) {
            return c - 48;
        }
        if (c >= 97 && c <= 102) {
            return 10 + (c - 97);
        }
        if (c >= 65 && c <= 70) {
            return 10 + (c - 65);
        }
        revert("Governor: invalid hex");
    }

    /**
     * @dev Consume and return nonce for voter.
     */
    function _useNonce(address voter) private returns (uint256 current) {
        current = _nonces[voter];
        _nonces[voter] = current + 1;
    }

    // Events mirroring OpenZeppelin Governor
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

    event ProposalQueued(uint256 proposalId, uint48 etaSeconds);

    event ProposalExecuted(uint256 proposalId);

    event ProposalCanceled(uint256 proposalId);

    event VoteCast(
        address voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );
}