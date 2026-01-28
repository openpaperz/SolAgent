// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Contract for EIP-712 typed structured data hashing and signing.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/EIP712.sol)
/// @author Modified from Solbase (https://github.com/Sol-DAO/solbase/blob/main/src/utils/EIP712.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol)
///
/// @dev Note, this implementation:
/// - Uses `address(this)` for the `verifyingContract` field.
/// - Does NOT use the optional EIP-712 salt.
/// - Does NOT use any EIP-712 extensions.
/// This is for simplicity and to avoid unnecessary bytecode bloat.
contract EIP712 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`.
    bytes32 internal constant _DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    uint256 private immutable _cachedThis;
    uint256 private immutable _cachedChainId;
    bytes32 private immutable _cachedNameHash;
    bytes32 private immutable _cachedVersionHash;
    bytes32 private immutable _cachedDomainSeparator;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Initializes the contract by caching the contract's address, chain ID, and domain separator.
     *
     * Steps:
     * 1. Cache the contract's address (`this`) as a uint256.
     * 2. Cache the current chain ID.
     *
     * 3. Retrieve the domain name and version if they are not expected to change.
     * 4. Compute the keccak256 hash of the domain name and version if they are not expected to change.
     * 5. Cache the computed name and version hashes.
     *
     * 6. Compute the domain separator if the domain name and version are not expected to change.
     *    - The domain separator is computed using the EIP-712 domain type hash, name hash, version hash, chain ID, and contract address.
     * 7. Cache the computed domain separator.
     */
    constructor() {
        _cachedThis = uint256(uint160(address(this)));
        _cachedChainId = block.chainid;

        if (!_domainNameAndVersionMayChange()) {
            (string memory name, string memory version) = _domainNameAndVersion();
            _cachedNameHash = keccak256(bytes(name));
            _cachedVersionHash = keccak256(bytes(version));
            _cachedDomainSeparator = _buildDomainSeparator();
        } else {
            _cachedNameHash = bytes32(0);
            _cachedVersionHash = bytes32(0);
            _cachedDomainSeparator = bytes32(0);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     VIRTUAL FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Internal view function to retrieve the domain name and version.
     *
     * @return name The domain name.
     * @return version The domain version.
     */
    function _domainNameAndVersion()
        internal
        view
        virtual
        returns (string memory name, string memory version)
    {
        name = "Solady";
        version = "1";
    }

    /**
     * @notice A virtual internal function that indicates whether the domain name and version may change.
     * @dev This function is marked as pure and virtual, meaning it can be overridden by derived contracts.
     * @return result A boolean indicating if the domain name and version may change.
     */
    function _domainNameAndVersionMayChange() internal view virtual returns (bool result) {
        return false;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   HASHING OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns the domain separator used in EIP-712 typed data hashing.
     * 
     * The domain separator is a unique identifier for the contract and is used to prevent replay attacks.
     * 
     * Steps:
     * 1. Check if the domain name and version may change.
     * 2. If they may change, build a new domain separator.
     * 3. If they are not expected to change, use the cached domain separator.
     * 4. If the cached domain separator is invalidated, build a new domain separator.
     * 
     * @return separator The domain separator as a bytes32 value.
     */
    function _domainSeparator() internal view virtual returns (bytes32 separator) {
        if (_domainNameAndVersionMayChange()) {
            separator = _buildDomainSeparator();
        } else {
            separator = _cachedDomainSeparator;
            if (_cachedDomainSeparatorInvalidated()) separator = _buildDomainSeparator();
        }
    }

    /**
     * @notice Computes the EIP-712 typed data hash for a given struct hash.
     *
     * Steps:
     * 1. Check if the domain name and version may change.
     * 2. If true, build a new domain separator and store it in `digest`.
     * 3. If false, use the cached domain separator.
     * 4. If the cached domain separator is invalidated, build a new one.
     *
     * 5. Use inline assembly to compute the digest:
     *    a. Store the EIP-712 prefix (0x1901) in memory.
     *    b. Store the domain separator in memory.
     *    c. Store the struct hash in memory.
     *    d. Compute the keccak256 hash of the concatenated data.
     *    e. Restore the overwritten memory slot.
     *
     * @param structHash The hash of the struct to be signed.
     * @return digest The computed EIP-712 typed data hash.
     */
    function _hashTypedData(bytes32 structHash) internal view virtual returns (bytes32 digest) {
        if (_domainNameAndVersionMayChange()) {
            digest = _buildDomainSeparator();
        } else {
            digest = _cachedDomainSeparator;
            if (_cachedDomainSeparatorInvalidated()) digest = _buildDomainSeparator();
        }
        /// @solidity memory-safe-assembly
        assembly {
            // Store the EIP-712 prefix (0x1901) at the free memory pointer
            let m := mload(0x40)
            mstore(m, 0x1901000000000000000000000000000000000000000000000000000000000000)
            // Store the domain separator
            mstore(add(m, 0x02), digest)
            // Store the struct hash
            mstore(add(m, 0x22), structHash)
            // Compute the keccak256 hash
            digest := keccak256(m, 0x42)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      EIP-5267 LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns the EIP-712 domain separator fields for this contract.
     *
     * The EIP-712 domain separator is used for typed structured data hashing and signing.
     *
     * @return fields A bitmask representing the fields included in the domain separator.
     * @return name The name of the domain (e.g., the contract name).
     * @return version The version of the domain (e.g., the contract version).
     * @return chainId The chain ID of the current network.
     * @return verifyingContract The address of the current contract.
     * @return salt A salt value (default is `bytes32(0)`).
     * @return extensions An array of extension values (default is an empty array).
     *
     * Steps:
     * 1. Set the `fields` bitmask to `0x0f` (indicating the inclusion of name, version, chainId, verifyingContract, and salt).
     * 2. Retrieve the domain name and version using the internal `_domainNameAndVersion` function.
     * 3. Set the `chainId` to the current blockchain's chain ID.
     * 4. Set the `verifyingContract` to the address of this contract.
     * 5. Set the `salt` to the default value (`bytes32(0)`).
     * 6. Set the `extensions` to an empty array.
     */
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        fields = hex"0f"; // 0b01111
        (name, version) = _domainNameAndVersion();
        chainId = block.chainid;
        verifyingContract = address(this);
        salt = bytes32(0);
        extensions = new uint256[](0);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PRIVATE HELPERS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Builds and returns the EIP-712 domain separator for signing typed data.
     *
     * Steps:
     * 1. Determine if the domain name and version may change.
     * 2. If they may change, compute the name and version hashes dynamically.
     * 3. If they are static, use the cached name and version hashes.
     * 4. Use inline assembly to construct the domain separator in memory:
     *    - Load the free memory pointer.
     *    - Store the domain type hash.
     *    - Store the name hash.
     *    - Store the version hash.
     *    - Store the chain ID.
     *    - Store the contract address.
     *    - Compute the final domain separator hash.
     *
     * @return separator The computed EIP-712 domain separator.
     */
    function _buildDomainSeparator() private view returns (bytes32 separator) {
        bytes32 nameHash;
        bytes32 versionHash;
        if (_domainNameAndVersionMayChange()) {
            (string memory name, string memory version) = _domainNameAndVersion();
            nameHash = keccak256(bytes(name));
            versionHash = keccak256(bytes(version));
        } else {
            nameHash = _cachedNameHash;
            versionHash = _cachedVersionHash;
        }
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Load the free memory pointer
            mstore(m, _DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), nameHash)
            mstore(add(m, 0x40), versionHash)
            mstore(add(m, 0x60), chainid())
            mstore(add(m, 0x80), address())
            separator := keccak256(m, 0xa0)
        }
    }

    /**
     * @notice Checks if the cached domain separator is invalidated.
     *
     * The function compares the current chain ID and contract address with the cached values.
     * If either the chain ID or the contract address has changed, the domain separator is considered invalidated.
     *
     * @return result A boolean indicating whether the cached domain separator is invalidated.
     *                - `true` if the domain separator is invalidated.
     *                - `false` if the domain separator is still valid.
     */
    function _cachedDomainSeparatorInvalidated() private view returns (bool result) {
        uint256 cachedChainId = _cachedChainId;
        uint256 cachedThis = _cachedThis;
        /// @solidity memory-safe-assembly
        assembly {
            result := iszero(and(eq(chainid(), cachedChainId), eq(address(), cachedThis)))
        }
    }
}
