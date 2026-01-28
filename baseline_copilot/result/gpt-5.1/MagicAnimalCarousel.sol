// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

error AnimalNameTooLong();
error NotCrateOwner();

contract MagicAnimalCarousel {
    // Layout:
    // bits 0..79   : animal (uint80)
    // bits 80..159 : owner (lower 80 bits of address)
    // bits 160..167: next crate id (uint8, since MAX_CAPACITY = 256)
    //
    // We will toggle the 160th bit of carousel[0] in the constructor as required.

    uint256 public constant MAX_CAPACITY = 256;

    uint256 private constant ANIMAL_MASK = (uint256(type(uint80).max));
    uint256 private constant OWNER_MASK = (uint256(type(uint80).max) << 80);
    uint256 private constant NEXT_ID_MASK = (uint256(type(uint8).max) << 160);

    mapping(uint256 => uint256) public carousel;
    uint256 public currentCrateId;

    /**
     * @notice Initializes the contract by performing a bitwise XOR operation on the first element of the `carousel` array.
     *
     * Steps:
     * 1. Perform a bitwise XOR operation on `carousel[0]` with `1 << 160`.
     *    - This operation toggles the 160th bit of `carousel[0]`.
     */
    constructor() {
        carousel[0] ^= (1 << 160);
    }

    /**
     * @notice Sets an animal name and updates the carousel state.
     *
     * @param animal The animal name to be encoded and set in the carousel.
     *
     * Steps:
     * 1. Encode the provided animal name and shift it right by 16 bits.
     * 2. Retrieve the next crate ID from the current carousel state.
     *
     * 3. Ensure the encoded animal name does not exceed the maximum allowed size (uint80).
     * 4. Update the carousel state for the next crate ID:
     *    - Clear the existing animal name and set the new encoded animal name.
     *    - Update the next crate ID to the next slot in the carousel (modulo MAX_CAPACITY).
     *    - Set the caller's address (`msg.sender`) in the carousel state.
     *
     * 5. Update the `currentCrateId` to the next crate ID.
     *
     * Reverts:
     * - If the encoded animal name exceeds the maximum allowed size (uint80).
     */
    function setAnimalAndSpin(string calldata animal) external {
        // 1. Encode and shift right by 16 bits
        uint256 encoded = encodeAnimalName(animal) >> 16;

        // 3. Ensure it fits in uint80
        if (encoded > type(uint80).max) {
            revert AnimalNameTooLong();
        }

        uint256 crateId = currentCrateId;
        uint256 state = carousel[crateId];

        // 2. Retrieve next crate id from state (bits 160..167)
        uint256 nextId = (state & NEXT_ID_MASK) >> 160;

        // If nextId is zero and crateId is zero (initial condition), we treat nextId as 0,
        // so we advance it manually to 1 the first time.
        if (crateId == 0 && nextId == 0) {
            nextId = 1;
        }

        // If nextId is still zero (for some reason), set it to (crateId + 1) % MAX_CAPACITY
        if (nextId == 0) {
            nextId = (crateId + 1) % MAX_CAPACITY;
        }

        // 4. Update carousel state for the next crate id
        uint256 nextState = carousel[nextId];

        // clear animal + owner + next id fields
        nextState &= ~(ANIMAL_MASK | OWNER_MASK | NEXT_ID_MASK);

        // set new animal
        nextState |= encoded;

        // set owner (lower 80 bits of msg.sender)
        uint256 owner80 = uint256(uint160(msg.sender)) & uint256(type(uint80).max);
        nextState |= (owner80 << 80);

        // compute and set new nextId for this crate
        uint256 newNextId = (nextId + 1) % MAX_CAPACITY;
        nextState |= (newNextId << 160);

        carousel[nextId] = nextState;

        // 5. update currentCrateId
        currentCrateId = nextId;
    }

    /**
     * @notice Allows the owner of a crate to change the animal associated with it or clear the owner slot if no animal is specified.
     *
     * @param animal The name of the new animal to associate with the crate.
     * @param crateId The ID of the crate whose animal is being changed.
     *
     * Steps:
     * 1. Retrieve the owner of the crate using the `crateId` and the `OWNER_MASK`.
     * 2. If the crate has an owner, ensure that the caller (`msg.sender`) is the owner.
     * 3. Encode the provided animal name into a uint256 value using `encodeAnimalName`.
     * 4. If the encoded animal is valid (non-zero):
     *    - Replace the animal in the crate by updating the `carousel` mapping with the new encoded animal, preserving the `NEXT_ID_MASK` and setting the owner to the caller.
     * 5. If no animal is specified (encoded animal is zero):
     *    - Clear the owner slot while preserving the existing animal and `NEXT_ID_MASK`.
     */
    function changeAnimal(string calldata animal, uint256 crateId) external {
        uint256 state = carousel[crateId];

        // 1. Retrieve owner (lower 80 bits from OWNER_MASK)
        uint256 owner80 = (state & OWNER_MASK) >> 80;

        if (owner80 != 0) {
            // 2. ensure msg.sender is owner
            uint256 sender80 = uint256(uint160(msg.sender)) & uint256(type(uint80).max);
            if (sender80 != owner80) {
                revert NotCrateOwner();
            }
        }

        // 3. Encode animal
        uint256 encoded = encodeAnimalName(animal);

        // masking to uint80-sized field
        if (encoded != 0 && encoded > type(uint80).max) {
            revert AnimalNameTooLong();
        }

        if (encoded != 0) {
            // 4. Replace animal, preserve NEXT_ID_MASK and set owner to caller

            // clear animal + owner
            state &= ~(ANIMAL_MASK | OWNER_MASK);

            // set new animal
            state |= (encoded & ANIMAL_MASK);

            // set owner to caller (lower 80 bits)
            uint256 sender80 = uint256(uint160(msg.sender)) & uint256(type(uint80).max);
            state |= (sender80 << 80);
        } else {
            // 5. No animal specified: clear owner slot, preserve existing animal and NEXT_ID_MASK
            state &= ~OWNER_MASK;
        }

        carousel[crateId] = state;
    }

    /**
     * @notice Encodes a given animal name into a uint256 value.
     *
     * Steps:
     * 1. Checks if the length of the animal name is 12 characters or less.
     *    - Reverts with `AnimalNameTooLong` error if the name exceeds 12 characters.
     * 2. Packs the animal name into bytes32 using `abi.encodePacked`.
     * 3. Shifts the packed bytes32 value right by 160 bits.
     * 4. Converts the result to a uint256 and returns it.
     */
    function encodeAnimalName(string calldata animalName) public pure returns (uint256) {
        bytes memory b = bytes(animalName);
        if (b.length > 12) {
            revert AnimalNameTooLong();
        }

        bytes32 packed = abi.encodePacked(animalName)[0:32];
        return uint256(packed >> 160);
    }
}