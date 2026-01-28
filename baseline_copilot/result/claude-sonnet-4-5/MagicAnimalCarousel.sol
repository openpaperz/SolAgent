// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MagicAnimalCarousel {
    // State variables
    mapping(uint256 => uint256) public carousel;
    uint256 public currentCrateId;
    
    // Constants
    uint256 private constant MAX_CAPACITY = 256;
    uint256 private constant ANIMAL_MASK = 0xFFFFFFFFFFFFFFFFFFFF << 176; // 80 bits for animal name
    uint256 private constant NEXT_ID_MASK = 0xFF << 168; // 8 bits for next ID
    uint256 private constant OWNER_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // 160 bits for owner address
    
    // Custom errors
    error AnimalNameTooLong();
    error AnimalNameTooLarge();
    error NotCrateOwner();
    
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
        // Step 1: Encode the animal name and shift right by 16 bits
        uint256 encodedAnimal = encodeAnimalName(animal);
        
        // Step 2: Retrieve the next crate ID from the current carousel state
        uint256 nextCrateId = (carousel[currentCrateId] >> 168) & 0xFF;
        
        // Step 3: Ensure the encoded animal name does not exceed uint80
        if (encodedAnimal > type(uint80).max) {
            revert AnimalNameTooLarge();
        }
        
        // Step 4: Update the carousel state for the next crate ID
        // Clear existing animal name and set new encoded animal name
        // Update next crate ID to the next slot (modulo MAX_CAPACITY)
        // Set caller's address in the carousel state
        uint256 newNextCrateId = (nextCrateId + 1) % MAX_CAPACITY;
        carousel[nextCrateId] = (encodedAnimal << 176) | (newNextCrateId << 168) | uint256(uint160(msg.sender));
        
        // Step 5: Update currentCrateId to the next crate ID
        currentCrateId = nextCrateId;
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
        // Step 1: Retrieve the owner of the crate
        address owner = address(uint160(carousel[crateId] & OWNER_MASK));
        
        // Step 2: Ensure caller is the owner if crate has an owner
        if (owner != address(0)) {
            if (owner != msg.sender) {
                revert NotCrateOwner();
            }
        }
        
        // Step 3: Encode the animal name
        uint256 encodedAnimal = encodeAnimalName(animal);
        
        // Step 4 & 5: Update carousel based on whether animal is specified
        if (encodedAnimal != 0) {
            // Replace animal, preserve NEXT_ID_MASK, set owner to caller
            uint256 nextIdPart = carousel[crateId] & NEXT_ID_MASK;
            carousel[crateId] = (encodedAnimal << 176) | nextIdPart | uint256(uint160(msg.sender));
        } else {
            // Clear owner slot, preserve animal and NEXT_ID_MASK
            carousel[crateId] = carousel[crateId] & ~OWNER_MASK;
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
        // Step 1: Check if length is 12 characters or less
        if (bytes(animalName).length > 12) {
            revert AnimalNameTooLong();
        }
        
        // Step 2: Pack the animal name into bytes32
        bytes32 packed = bytes32(abi.encodePacked(animalName));
        
        // Step 3: Shift right by 160 bits
        uint256 shifted = uint256(packed) >> 160;
        
        // Step 4: Return the result
        return shifted;
    }
}
