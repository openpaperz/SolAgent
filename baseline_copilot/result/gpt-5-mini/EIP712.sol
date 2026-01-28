// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract EIP712 {
    bytes32 private constant _EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
    );

    // Cached values for immutable domain fields optimization
    bytes32 private _CACHED_NAME_HASH;
    bytes32 private _CACHED_VERSION_HASH;
    bytes32 private _CACHED_DOMAIN_SEPARATOR;
    uint256 private _CACHED_CHAIN_ID;
    uint256 private _CACHED_THIS;

    /**
     * @notice Initializes the contract by caching the contract's address, chain ID, and domain separator.
     */
    constructor () {
        _CACHED_THIS = uint256(uint160(address(this)));
        _CACHED_CHAIN_ID = block.chainid;

        if (!_domainNameAndVersionMayChange()) {
            (string memory name, string memory version) = _domainNameAndVersion();
            _CACHED_NAME_HASH = keccak256(bytes(name));
            _CACHED_VERSION_HASH = keccak256(bytes(version));
            _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator();
        } else {
            _CACHED_NAME_HASH = bytes32(0);
            _CACHED_VERSION_HASH = bytes32(0);
            _CACHED_DOMAIN_SEPARATOR = bytes32(0);
        }
    }

    /**
     * @notice Internal view function to retrieve the domain name and version.
     * @dev Override this in derived contracts to provide name and version.
     */
    function _domainNameAndVersion() internal virtual view returns (string memory name, string memory version) {
        name = "";
        version = "";
    }

    /**
     * @notice A virtual internal function that indicates whether the domain name and version may change.
     * @dev Override to return true if name or version can change after construction.
     */
    function _domainNameAndVersionMayChange() internal virtual pure returns (bool result) {
        return false;
    }

    /**
     * @notice Returns the domain separator used in EIP-712 typed data hashing.
     */
    function _domainSeparator() internal virtual view returns (bytes32 separator) {
        if (_domainNameAndVersionMayChange()) {
            return _buildDomainSeparator();
        }
        if (_cachedDomainSeparatorInvalidated()) {
            return _buildDomainSeparator();
        }
        return _CACHED_DOMAIN_SEPARATOR;
    }

    /**
     * @notice Computes the EIP-712 typed data hash for a given struct hash.
     */
    function _hashTypedData(bytes32 structHash) internal virtual view returns (bytes32 digest) {
        bytes32 domainSeparator = _domainSeparator();

        assembly {
            // get free memory pointer
            let ptr := mload(0x40)
            // save original memory words to restore later
            let old0 := mload(ptr)
            let old1 := mload(add(ptr, 0x20))

            // store 0x19 and 0x01 as the first two bytes
            mstore8(ptr, 0x19)
            mstore8(add(ptr, 1), 0x01)

            // store domainSeparator at ptr + 2
            mstore(add(ptr, 2), domainSeparator)

            // store structHash at ptr + 34
            mstore(add(ptr, 34), structHash)

            // compute keccak256 over 66 bytes (0x42)
            digest := keccak256(ptr, 0x42)

            // restore memory
            mstore(ptr, old0)
            mstore(add(ptr, 0x20), old1)
        }
    }

    /**
     * @notice Returns the EIP-712 domain separator fields for this contract.
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
        fields = 0x0f; // name, version, chainId, verifyingContract, salt
        (name, version) = _domainNameAndVersion();
        chainId = block.chainid;
        verifyingContract = address(this);
        salt = bytes32(0);
        extensions = new uint256[](0);
    }

    /**
     * @notice Builds and returns the EIP-712 domain separator for signing typed data.
     */
    function _buildDomainSeparator() private view returns (bytes32 separator) {
        bytes32 nameHash;
        bytes32 versionHash;
        uint256 chainId = block.chainid;
        address verifyingContract = address(this);

        if (_domainNameAndVersionMayChange()) {
            (string memory name, string memory version) = _domainNameAndVersion();
            nameHash = keccak256(bytes(name));
            versionHash = keccak256(bytes(version));
        } else {
            nameHash = _CACHED_NAME_HASH;
            versionHash = _CACHED_VERSION_HASH;
        }

        // keccak256(abi.encode(...))
        separator = keccak256(
            abi.encode(
                _EIP712_DOMAIN_TYPEHASH,
                nameHash,
                versionHash,
                chainId,
                verifyingContract,
                bytes32(0)
            )
        );
    }

    /**
     * @notice Checks if the cached domain separator is invalidated.
     */
    function _cachedDomainSeparatorInvalidated() private view returns (bool result) {
        return (block.chainid != _CACHED_CHAIN_ID || _CACHED_THIS != uint256(uint160(address(this))));
    }
}