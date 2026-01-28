// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title EIP712
/// @notice Minimal, efficient EIP-712 domain separator and typed data hashing helper.
contract EIP712 {
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant _EIP712_DOMAIN_TYPEHASH =
        0xd87cd6a6c5d1c1b2a7f6e6b7965a7ab6b5234f6b31dadd4ef95b0d7db114d0e;

    // Cached values to avoid recomputation when the domain is static.
    uint256 internal immutable _CACHED_CHAIN_ID;
    uint256 internal immutable _CACHED_THIS;
    bytes32 internal immutable _CACHED_DOMAIN_SEPARATOR;
    bytes32 internal immutable _CACHED_NAME_HASH;
    bytes32 internal immutable _CACHED_VERSION_HASH;

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
        _CACHED_THIS = uint256(uint160(address(this)));
        uint256 cid;
        assembly {
            cid := chainid()
        }
        _CACHED_CHAIN_ID = cid;

        bytes32 nameHash;
        bytes32 versionHash;
        bytes32 separator;

        if (!_domainNameAndVersionMayChange()) {
            (string memory name, string memory version) = _domainNameAndVersion();
            nameHash = keccak256(bytes(name));
            versionHash = keccak256(bytes(version));
            separator = _buildDomainSeparatorWith(nameHash, versionHash, cid, address(this));
        }

        _CACHED_NAME_HASH = nameHash;
        _CACHED_VERSION_HASH = versionHash;
        _CACHED_DOMAIN_SEPARATOR = separator;
    }

    /**
     * @notice Internal view function to retrieve the domain name and version.
     *
     * @return name The domain name.
     * @return version The domain version.
     */
    function _domainNameAndVersion()
        internal
        virtual
        view
        returns (string memory name, string memory version)
    {
        // Default implementation: empty name and version.
        // Override in child contracts for custom values.
        name = "";
        version = "";
    }

    /**
     * @notice A virtual internal function that indicates whether the domain name and version may change.
     * @dev This function is marked as pure and virtual, meaning it can be overridden by derived contracts.
     * @return result A boolean indicating if the domain name and version may change.
     */
    function _domainNameAndVersionMayChange()
        internal
        virtual
        pure
        returns (bool result)
    {
        // Default: domain is static.
        return false;
    }

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
    function _domainSeparator() internal virtual view returns (bytes32 separator) {
        if (_domainNameAndVersionMayChange()) {
            return _buildDomainSeparator();
        }

        separator = _CACHED_DOMAIN_SEPARATOR;
        if (separator == bytes32(0) || _cachedDomainSeparatorInvalidated()) {
            separator = _buildDomainSeparator();
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
    function _hashTypedData(bytes32 structHash)
        internal
        virtual
        view
        returns (bytes32 digest)
    {
        bytes32 separator = _domainSeparator();

        assembly {
            // Load free memory pointer
            let ptr := mload(0x40)
            // Store 0x1901 prefix
            mstore(ptr, 0x1901000000000000000000000000000000000000000000000000000000000000)
            // Store domain separator and struct hash
            mstore(add(ptr, 0x02), separator)
            mstore(add(ptr, 0x22), structHash)
            // Compute keccak256 over 0x42 bytes
            digest := keccak256(ptr, 0x42)
        }
    }

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
        virtual
        view
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
        fields = 0x0f;
        (name, version) = _domainNameAndVersion();

        uint256 cid;
        assembly {
            cid := chainid()
        }
        chainId = cid;

        verifyingContract = address(this);
        salt = bytes32(0);
        extensions = new uint256[](0);
    }

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
            nameHash = _CACHED_NAME_HASH;
            versionHash = _CACHED_VERSION_HASH;
        }

        uint256 cid;
        assembly {
            cid := chainid()
        }

        separator = _buildDomainSeparatorWith(nameHash, versionHash, cid, address(this));
    }

    /// @dev Helper to actually build the domain separator from components.
    function _buildDomainSeparatorWith(
        bytes32 nameHash,
        bytes32 versionHash,
        uint256 chainId,
        address verifyingContract
    ) private pure returns (bytes32 separator) {
        assembly {
            let ptr := mload(0x40)
            // Store typehash, nameHash, versionHash, chainId, verifyingContract
            mstore(ptr, _EIP712_DOMAIN_TYPEHASH)
            mstore(add(ptr, 0x20), nameHash)
            mstore(add(ptr, 0x40), versionHash)
            mstore(add(ptr, 0x60), chainId)
            mstore(add(ptr, 0x80), verifyingContract)
            separator := keccak256(ptr, 0xa0)
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
    function _cachedDomainSeparatorInvalidated()
        private
        view
        returns (bool result)
    {
        uint256 currentChainId;
        assembly {
            currentChainId := chainid()
        }
        if (currentChainId != _CACHED_CHAIN_ID) return true;
        if (uint256(uint160(address(this))) != _CACHED_THIS) return true;
        return false;
    }
}