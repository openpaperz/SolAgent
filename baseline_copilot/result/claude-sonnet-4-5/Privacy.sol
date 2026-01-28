// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Privacy {
    bool public locked = true;
    uint256 public ID = block.timestamp;
    uint8 private flattening = 10;
    uint8 private denomination = 255;
    uint16 private awkwardness = uint16(block.timestamp);
    bytes32[3] private data;

    /**
     * @notice Initializes the contract with an array of 3 bytes32 values.
     *
     * @param _data An array of 3 bytes32 values to be stored in the contract's state.
     *
     * Steps:
     * 1. Assign the provided `_data` array to the contract's `data` state variable.
     */
    constructor(bytes32[3] memory _data) {
        data = _data;
    }

    /**
     * @notice Unlocks the contract if the provided key matches the stored key.
     *
     * @param _key The key to be checked against the stored key.
     *
     * Steps:
     * 1. Require that the provided `_key` matches the key stored in `data[2]`.
     * 2. If the keys match, set the `locked` state variable to `false`, unlocking the contract.
     */
    function unlock(bytes16 _key) public {
        require(_key == bytes16(data[2]), "Invalid key");
        locked = false;
    }
}
