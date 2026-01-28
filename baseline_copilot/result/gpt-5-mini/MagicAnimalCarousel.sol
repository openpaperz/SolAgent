// [MagicAnimalCarousel.sol](MagicAnimalCarousel.sol)
// [`MagicAnimalCarousel`](MagicAnimalCarousel.sol)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MagicAnimalCarousel {
    // Errors
    error AnimalNameTooLong();
    error AnimalNameTooBig();
    error NotOwner();

    // Storage layout masks and constants
    uint256 private constant OWNER_BITS = 160;
    uint256 private constant NEXT_ID_BITS = 16;
    uint256 private constant ANIMAL_BITS = 80;

    uint256 private constant OWNER_MASK = (uint256(1) << OWNER_BITS) - 1; // lowest 160 bits
    uint256 private constant NEXT_ID_MASK = ((uint256(1) << NEXT_ID_BITS) - 1) << OWNER_BITS; // bits 160..175
    uint256 private constant ANIMAL_MASK = ((uint256(1) << ANIMAL_BITS) - 1) << (OWNER_BITS + NEXT_ID_BITS); // bits 176..255

    uint256 public constant MAX_CAPACITY = (uint256(1) << NEXT_ID_BITS);

    mapping(uint256 => uint256) public carousel;
    uint256 public currentCrateId;

    /**
     * @notice Initializes the contract by performing a bitwise XOR operation on the first element of the `carousel` array.
     *
     * Steps:
     * 1. Perform a bitwise XOR operation on `carousel[0]` with `1 << 160`.
     *    - This operation toggles the 160th bit of `carousel[0]`.
     */
    constructor () {
        // Toggle bit 160 of carousel[0] (this sets the initial nextId = 1 in slot 0)
        carousel[0] ^= (uint256(1) << OWNER_BITS);
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
        uint256 encoded = encodeAnimalName(animal);

        if (encoded > type(uint80).max) revert AnimalNameTooBig();

        uint256 currentSlot = carousel[currentCrateId];
        uint256 nextId = (currentSlot & NEXT_ID_MASK) >> OWNER_BITS;

        // If nextId is zero (not initialized), derive it as (currentCrateId + 1) % MAX_CAPACITY
        uint256 targetId = nextId;
        if (targetId == 0) {
            targetId = (currentCrateId + 1) % MAX_CAPACITY;
        }

        // Compute the next-next id for the slot we are about to update
        uint256 nextNextId = (targetId + 1) % MAX_CAPACITY;

        // Compose new slot value: animal in ANIMAL_BITS, nextId in NEXT_ID_BITS, owner in OWNER_BITS
        uint256 newSlot = (encoded << (OWNER_BITS + NEXT_ID_BITS)) | (nextNextId << OWNER_BITS) | uint256(uint160(msg.sender));

        carousel[targetId] = newSlot;
        currentCrateId = targetId;
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
        uint256 slot = carousel[crateId];
        uint256 owner = slot & OWNER_MASK;

        if (owner != 0 && owner != uint256(uint160(msg.sender))) revert NotOwner();

        uint256 encoded = encodeAnimalName(animal);

        uint256 nextPart = slot & NEXT_ID_MASK;
        uint256 animalPart = slot & ANIMAL_MASK;

        if (encoded != 0) {
            if (encoded > type(uint80).max) revert AnimalNameTooBig();
            // Set new animal and owner, preserve nextId
            carousel[crateId] = (encoded << (OWNER_BITS + NEXT_ID_BITS)) | nextPart | uint256(uint160(msg.sender));
        } else {
            // Clear owner, preserve animal and nextId
            carousel[crateId] = animalPart | nextPart;
        }
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
        bytes calldata b = bytes(animalName);
        if (b.length > 12) revert AnimalNameTooLong();

        bytes32 packed;
        // Load up to 32 bytes of the string into packed
        assembly {
            packed := calldataload(add(animalName.offset, 32))
        }
        // Shift right by 160 bits as specified
        uint256 val = uint256(packed) >> 160;
        return val;
    }

    // Helper view functions for convenience

    function ownerOf(uint256 crateId) external view returns (address) {
        return address(uint160(carousel[crateId] & OWNER_MASK));
    }

    function nextIdOf(uint256 crateId) external view returns (uint256) {
        return (carousel[crateId] & NEXT_ID_MASK) >> OWNER_BITS;
    }

    function animalOf(uint256 crateId) external view returns (uint256) {
        return (carousel[crateId] & ANIMAL_MASK) >> (OWNER_BITS + NEXT_ID_BITS);
    }
}