// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Statistics {
    /**
     * @notice Defines a structure to store information about a level instance.
     * 
     * Fields:
     * - instance: The address of the level instance.
     * - isCompleted: A boolean indicating whether the level instance has been completed.
     * - timeCreated: The timestamp when the level instance was created.
     * - timeCompleted: The timestamp when the level instance was marked as completed.
     * - timeSubmitted: An array of timestamps representing each submission attempt of the level instance.
     */
    struct LevelInstance {
        address instance;
        bool isCompleted;
        uint256 timeCreated;
        uint256 timeCompleted;
        uint256[] timeSubmitted;
    }

    /**
     * @notice Defines a struct to store statistics related to a level in the Ethernaut game.
     *
     * Fields:
     * - `noOfInstancesCreated`: The total number of instances created for this level.
     * - `noOfInstancesSubmitted_Success`: The total number of instances successfully submitted for this level.
     * - `noOfSubmissions_Failed`: The total number of failed submissions for this level.
     */
    struct Level {
        uint256 noOfInstancesCreated;
        uint256 noOfInstancesSubmitted_Success;
        uint256 noOfSubmissions_Failed;
    }

    address public ethernaut;
    
    // Global statistics
    uint256 public globalNoOfLevelInstancesCreated;
    uint256 public globalNoOfLevelInstancesCompleted;
    uint256 public globalNoOfFailedSubmissions;
    
    // Level tracking
    address[] public levels;
    mapping(address => bool) public levelExists;
    mapping(address => Level) public levelStats;
    
    // Player tracking
    address[] public players;
    mapping(address => bool) public playerExists;
    
    // Player statistics
    mapping(address => uint256) public playerNoOfLevelInstancesCreated;
    mapping(address => uint256) public playerNoOfLevelInstancesCompleted;
    mapping(address => uint256) public playerNoOfFailedSubmissions;
    mapping(address => uint256) public playerNoOfLevelsCompleted;
    
    // Player level instance tracking
    mapping(address => mapping(address => LevelInstance)) public playerLevelInstances;
    mapping(address => mapping(address => uint256)) public levelFirstInstanceCreationTime;
    mapping(address => mapping(address => uint256)) public levelFirstCompletionTime;
    
    // Average time tracking
    mapping(address => uint256) public averageTimeTakenToCompleteLevels;
    
    // Events
    event playerScoreProfile(
        address indexed player,
        uint256 totalLevelsCompleted,
        uint256 averageTimeTaken
    );
    
    // Modifiers
    modifier onlyEthernaut() {
        require(msg.sender == ethernaut, "Only Ethernaut can call this function");
        _;
    }
    
    modifier levelExistsCheck(address level) {
        require(levelExists[level], "Level does not exist");
        _;
    }
    
    modifier levelDoesntExistCheck(address level) {
        require(!levelExists[level], "Level already exists");
        _;
    }
    
    modifier playerExistsCheck(address player) {
        require(playerExists[player], "Player does not exist");
        _;
    }
    
    bool private initialized;
    
    modifier initializer() {
        require(!initialized, "Already initialized");
        _;
        initialized = true;
    }

    /**
     * @notice Initializes the contract by setting the Ethernaut address.
     *
     * @param _ethernautAddress The address of the Ethernaut contract to be associated with this contract.
     *
     * Steps:
     * 1. Assign the provided Ethernaut address to the `ethernaut` state variable.
     *
     * @dev This function is marked with the `initializer` modifier, ensuring it can only be called once during the contract's initialization phase.
     */
    function initialize(address _ethernautAddress) public initializer {
        ethernaut = _ethernautAddress;
    }

    /**
     * @notice Creates a new instance of a level for a player. This function is restricted to the Ethernaut contract and ensures the level exists.
     *
     * @param instance The address of the new level instance being created.
     * @param level The address of the level contract.
     * @param player The address of the player for whom the instance is being created.
     *
     * Steps:
     * 1. Check if the player exists in the system. If not, add the player to the `players` array and mark them as existing.
     * 2. If this is the first instance of the level for the player, record the creation timestamp.
     * 3. Update the player's stats for the level, including the instance address, completion status, creation timestamp, and submission history.
     * 4. Increment the global and level-specific counters for the number of instances created.
     * 5. Increment the player-specific counter for the number of instances created.
     *
     * Requirements:
     * - The function can only be called by the Ethernaut contract (`onlyEthernaut` modifier).
     * - The level must exist (`levelExistsCheck` modifier).
     */
    function createNewInstance(address instance, address level, address player) external onlyEthernaut levelExistsCheck(level) {
        // Step 1: Check if player exists, if not add them
        if (!playerExists[player]) {
            players.push(player);
            playerExists[player] = true;
        }
        
        // Step 2: If this is the first instance of the level for the player, record creation timestamp
        if (levelFirstInstanceCreationTime[player][level] == 0) {
            levelFirstInstanceCreationTime[player][level] = block.timestamp;
        }
        
        // Step 3: Update player's stats for the level
        playerLevelInstances[player][level].instance = instance;
        playerLevelInstances[player][level].isCompleted = false;
        playerLevelInstances[player][level].timeCreated = block.timestamp;
        playerLevelInstances[player][level].timeCompleted = 0;
        
        // Step 4: Increment global and level-specific counters
        globalNoOfLevelInstancesCreated++;
        levelStats[level].noOfInstancesCreated++;
        
        // Step 5: Increment player-specific counter
        playerNoOfLevelInstancesCreated[player]++;
    }

    /**
     * @notice Submits a successful level completion for a player.
     *
     * @dev This function is restricted to be called only by the Ethernaut contract and performs several checks:
     * 1. Ensures the instance for the level has been created.
     * 2. Verifies that the submitted instance matches the created one.
     * 3. Checks that the level has not already been completed.
     *
     * If it is the first submission for the level:
     * 1. Increments the global count of levels completed by the player.
     * 2. Records the first completion time for the level.
     * 3. Updates the average time taken to complete levels by the player.
     * 4. Emits a `playerScoreProfile` event with the updated player's score profile.
     *
     * Additionally, it:
     * 1. Records the submission and completion timestamps.
     * 2. Marks the level as completed.
     * 3. Updates the number of successful submissions for the level and globally.
     * 4. Increments the global count of instances completed by the player.
     *
     * @param instance The address of the level instance being submitted.
     * @param level The address of the level contract.
     * @param player The address of the player submitting the level.
     *
     * Requirements:
     * - The instance must have been created for the level.
     * - The submitted instance must match the created one.
     * - The level must not have been completed already.
     */
    function submitSuccess(address instance, address level, address player) external onlyEthernaut playerExistsCheck(player) levelExistsCheck(level) {
        // Perform checks
        require(playerLevelInstances[player][level].instance != address(0), "Instance not created");
        require(playerLevelInstances[player][level].instance == instance, "Instance mismatch");
        require(!playerLevelInstances[player][level].isCompleted, "Level already completed");
        
        // Check if this is the first completion of this level
        bool isFirstCompletion = (levelFirstCompletionTime[player][level] == 0);
        
        if (isFirstCompletion) {
            // Increment global count of levels completed
            playerNoOfLevelsCompleted[player]++;
            
            // Record first completion time
            levelFirstCompletionTime[player][level] = block.timestamp;
            
            // Update average time taken
            uint256 newAverage = updateAverageTimeTakenToCompleteLevelsByPlayer(player, level, playerNoOfLevelsCompleted[player]);
            
            // Emit event
            emit playerScoreProfile(player, playerNoOfLevelsCompleted[player], newAverage);
        }
        
        // Record submission and completion timestamps
        playerLevelInstances[player][level].timeSubmitted.push(block.timestamp);
        playerLevelInstances[player][level].timeCompleted = block.timestamp;
        
        // Mark level as completed
        playerLevelInstances[player][level].isCompleted = true;
        
        // Update successful submissions
        levelStats[level].noOfInstancesSubmitted_Success++;
        globalNoOfLevelInstancesCompleted++;
        
        // Increment instances completed by player
        playerNoOfLevelInstancesCompleted[player]++;
    }

    /**
     * @notice Submits a failure for a level instance.
     *
     * Requirements:
     * 1. Only the Ethernaut contract can call this function.
     * 2. The level must exist.
     * 3. The player must exist.
     *
     * Steps:
     * 1. Ensure that an instance for the level has been created for the player.
     * 2. Ensure that the submitted instance matches the created instance.
     * 3. Ensure that the level has not already been completed.
     *
     * 4. Record the submission timestamp for the player's level instance.
     * 5. Increment the number of failed submissions for the level.
     * 6. Increment the global number of failed submissions.
     * 7. Increment the global number of failed submissions for the player.
     */
    function submitFailure(address instance, address level, address player) external onlyEthernaut playerExistsCheck(player) levelExistsCheck(level) {
        // Steps 1-3: Perform checks
        require(playerLevelInstances[player][level].instance != address(0), "Instance not created");
        require(playerLevelInstances[player][level].instance == instance, "Instance mismatch");
        require(!playerLevelInstances[player][level].isCompleted, "Level already completed");
        
        // Step 4: Record submission timestamp
        playerLevelInstances[player][level].timeSubmitted.push(block.timestamp);
        
        // Step 5: Increment failed submissions for level
        levelStats[level].noOfSubmissions_Failed++;
        
        // Step 6: Increment global failed submissions
        globalNoOfFailedSubmissions++;
        
        // Step 7: Increment player failed submissions
        playerNoOfFailedSubmissions[player]++;
    }

    /**
     * @notice Saves a new level address to the list of registered levels.
     * 
     * @param level The address of the level to be registered.
     *
     * Requirements:
     * - The level must not already exist in the registry (enforced by `levelDoesntExistCheck` modifier).
     * - Only the Ethernaut contract can call this function (enforced by `onlyEthernaut` modifier).
     *
     * Steps:
     * 1. Mark the level as existing by setting `levelExists[level]` to `true`.
     * 2. Add the level address to the `levels` array.
     */
    function saveNewLevel(address level) external onlyEthernaut levelDoesntExistCheck(level) {
        // Step 1: Mark level as existing
        levelExists[level] = true;
        
        // Step 2: Add to levels array
        levels.push(level);
    }

    /**
     * @notice Retrieves the total number of level instances created by a specific player.
     *
     * @param player The address of the player whose level instances are being queried.
     * @return uint256 The total number of level instances created by the player.
     *
     * Requirements:
     * - The player must exist (checked by the `playerExistsCheck` modifier).
     */
    function getTotalNoOfLevelInstancesCreatedByPlayer(address player) public view playerExistsCheck(player) returns (uint256) {
        return playerNoOfLevelInstancesCreated[player];
    }

    /**
     * @notice Retrieves the total number of level instances completed by a specific player.
     *
     * @param player The address of the player whose completed instances are being queried.
     * @return uint256 The total number of level instances completed by the player.
     *
     * Requirements:
     * - The player must exist (enforced by the `playerExistsCheck` modifier).
     */
    function getTotalNoOfLevelInstancesCompletedByPlayer(address player) public view playerExistsCheck(player) returns (uint256) {
        return playerNoOfLevelInstancesCompleted[player];
    }

    /**
     * @notice Retrieves the total number of failed submissions by a specific player.
     * 
     * @param player The address of the player whose failed submissions are to be queried.
     * @return uint256 The total number of failed submissions by the player.
     * 
     * Requirements:
     * - The player must exist (enforced by the `playerExistsCheck` modifier).
     */
    function getTotalNoOfFailedSubmissionsByPlayer(address player) public view playerExistsCheck(player) returns (uint256) {
        return playerNoOfFailedSubmissions[player];
    }

    /**
     * @notice Retrieves the total number of levels completed by a specific player.
     *
     * @param player The address of the player whose completed levels are to be queried.
     * @return uint256 The total number of levels completed by the player.
     *
     * Requirements:
     * - The player must exist (checked by the `playerExistsCheck` modifier).
     */
    function getTotalNoOfLevelsCompletedByPlayer(address player) public view playerExistsCheck(player) returns (uint256) {
        return playerNoOfLevelsCompleted[player];
    }

    /**
     * @notice Retrieves the total number of failures for a specific level and player.
     *
     * Requirements:
     * - The player must exist (checked by `playerExistsCheck` modifier).
     * - The level must exist (checked by `levelExistsCheck` modifier).
     *
     * @param level The address of the level to check.
     * @param player The address of the player to check.
     * @return The total number of failures for the specified level and player. 
     *         If the player has not attempted the level, returns 0.
     */
    function getTotalNoOfFailuresForLevelAndPlayer(address level, address player) public view playerExistsCheck(player) levelExistsCheck(level) returns (uint256) {
        LevelInstance memory levelInstance = playerLevelInstances[player][level];
        if (levelInstance.instance == address(0)) {
            return 0;
        }
        
        uint256 totalSubmissions = levelInstance.timeSubmitted.length;
        
        if (levelInstance.isCompleted) {
            // Subtract 1 for the successful submission
            return totalSubmissions > 0 ? totalSubmissions - 1 : 0;
        } else {
            return totalSubmissions;
        }
    }

    /**
     * @notice Checks if a specific level has been completed by a player.
     *
     * @param player The address of the player to check.
     * @param level The address of the level to check.
     *
     * @return bool Returns true if the level has been completed by the player, otherwise false.
     *
     * Modifiers:
     * - `playerExistsCheck`: Ensures the player exists.
     * - `levelExistsCheck`: Ensures the level exists.
     */
    function isLevelCompleted(address player, address level) public view playerExistsCheck(player) levelExistsCheck(level) returns (bool) {
        return playerLevelInstances[player][level].isCompleted;
    }

    /**
     * @notice Retrieves the time elapsed between the creation and completion of a level instance for a specific player.
     *
     * @param player The address of the player whose level completion time is being queried.
     * @param level The address of the level contract for which the completion time is being queried.
     *
     * @return uint256 The time elapsed (in seconds) between the creation and completion of the level instance.
     *
     * Requirements:
     * - The player must exist (checked via `playerExistsCheck` modifier).
     * - The level must exist (checked via `levelExistsCheck` modifier).
     * - The level must have been completed by the player, otherwise the function reverts with the message "Level not completed".
     *
     * Steps:
     * 1. Check if the player and level exist using the respective modifiers.
     * 2. Ensure the level has been completed by the player by checking if `levelFirstCompletionTime[player][level]` is not zero.
     * 3. Calculate the time elapsed by subtracting the level creation time (`levelFirstInstanceCreationTime[player][level]`) from the level completion time (`levelFirstCompletionTime[player][level]`).
     * 4. Return the calculated time elapsed.
     */
    function getTimeElapsedForCompletionOfLevel(address player, address level) public view playerExistsCheck(player) levelExistsCheck(level) returns (uint256) {
        // Step 2: Ensure level has been completed
        require(levelFirstCompletionTime[player][level] != 0, "Level not completed");
        
        // Step 3: Calculate time elapsed
        uint256 timeElapsed = levelFirstCompletionTime[player][level] - levelFirstInstanceCreationTime[player][level];
        
        // Step 4: Return time elapsed
        return timeElapsed;
    }

    /**
     * @notice Retrieves the submission time for a specific level by a player at a given index.
     *
     * @param player The address of the player.
     * @param level The address of the level.
     * @param index The index of the submission time to retrieve.
     *
     * @return The submission time at the specified index.
     *
     * Requirements:
     * - The player must exist (checked by `playerExistsCheck` modifier).
     * - The level must exist (checked by `levelExistsCheck` modifier).
     * - The index must be within the bounds of the submission times array.
     *
     * Reverts:
     * - If the index is out of bounds, reverts with "Index outbounded".
     */
    function getSubmissionsForLevelByPlayer(address player, address level, uint256 index) public view playerExistsCheck(player) levelExistsCheck(level) returns (uint256) {
        require(index < playerLevelInstances[player][level].timeSubmitted.length, "Index outbounded");
        return playerLevelInstances[player][level].timeSubmitted[index];
    }

    /**
     * @notice Calculates the percentage of levels completed by a player.
     * 
     * Steps:
     * 1. Checks if the player exists using the `playerExistsCheck` modifier.
     * 2. Multiplies the total number of levels completed by the player by 1e18 to avoid rounding errors.
     * 3. Divides the result by the total number of levels to get the percentage.
     * 4. Returns the calculated percentage.
     */
    function getPercentageOfLevelsCompleted(address player) public view playerExistsCheck(player) returns (uint256) {
        uint256 totalLevels = levels.length;
        if (totalLevels == 0) {
            return 0;
        }
        
        // Step 2: Multiply by 1e18 to avoid rounding errors
        uint256 percentage = (playerNoOfLevelsCompleted[player] * 1e18) / totalLevels;
        
        // Step 4: Return percentage
        return percentage;
    }

    /**
     * @notice Updates the average time taken by a player to complete levels.
     *
     * Steps:
     * 1. Retrieve the last average time taken by the player to complete levels.
     * 2. Calculate the time taken for the current successful submission by subtracting the level's first instance creation time from the level's first completion time.
     * 3. If the player has no previous average time recorded, set the current time taken as the average.
     * 4. Otherwise, calculate the new average time by taking into account the previous average and the current time taken.
     * 5. Update the average time taken by the player in the mapping.
     * 6. Return the new average time taken to complete levels.
     */
    function updateAverageTimeTakenToCompleteLevelsByPlayer(address player, address level, uint256 totalNoOfLevelsCompletedByPlayer) private returns (uint256) {
        // Step 1: Retrieve last average time
        uint256 lastAverage = averageTimeTakenToCompleteLevels[player];
        
        // Step 2: Calculate time taken for current level
        uint256 currentTimeTaken = levelFirstCompletionTime[player][level] - levelFirstInstanceCreationTime[player][level];
        
        uint256 newAverage;
        
        // Step 3: If no previous average, set current time as average
        if (totalNoOfLevelsCompletedByPlayer == 1) {
            newAverage = currentTimeTaken;
        } else {
            // Step 4: Calculate new average
            newAverage = ((lastAverage * (totalNoOfLevelsCompletedByPlayer - 1)) + currentTimeTaken) / totalNoOfLevelsCompletedByPlayer;
        }
        
        // Step 5: Update the average time in mapping
        averageTimeTakenToCompleteLevels[player] = newAverage;
        
        // Step 6: Return new average
        return newAverage;
    }

    /**
     * @notice Returns the total number of level instances created.
     *
     * @return uint256 The total number of level instances created.
     */
    function getTotalNoOfLevelInstancesCreated() public view returns (uint256) {
        return globalNoOfLevelInstancesCreated;
    }

    /**
     * @notice Returns the total number of level instances that have been completed globally.
     *
     * @return uint256 The total number of completed level instances.
     */
    function getTotalNoOfLevelInstancesCompleted() public view returns (uint256) {
        return globalNoOfLevelInstancesCompleted;
    }

    /**
     * @notice Returns the total number of failed submissions.
     * @return uint256 The total number of failed submissions stored in `globalNoOfFailedSubmissions`.
     */
    function getTotalNoOfFailedSubmissions() public view returns (uint256) {
        return globalNoOfFailedSubmissions;
    }

    /**
     * @notice Returns the total number of players currently registered in the system.
     *
     * @return uint256 The total number of players.
     */
    function getTotalNoOfPlayers() public view returns (uint256) {
        return players.length;
    }

    /**
     * @notice Retrieves the number of failed submissions for a specific level.
     * @param level The address of the level to query.
     * @return uint256 The number of failed submissions for the specified level.
     * @dev This function includes a modifier `levelExistsCheck` to ensure the level exists before querying.
     */
    function getNoOfFailedSubmissionsForLevel(address level) public view levelExistsCheck(level) returns (uint256) {
        return levelStats[level].noOfSubmissions_Failed;
    }

    /**
     * @notice Retrieves the number of instances created for a specific level.
     * @param level The address of the level to query.
     * @return uint256 The number of instances created for the specified level.
     * @dev This function includes a modifier `levelExistsCheck` to ensure the level exists before querying.
     */
    function getNoOfInstancesForLevel(address level) public view levelExistsCheck(level) returns (uint256) {
        return levelStats[level].noOfInstancesCreated;
    }

    /**
     * @notice Retrieves the number of successful submissions for a specific level.
     * @param level The address of the level to query.
     * @return uint256 The number of successful submissions for the specified level.
     * @dev This function includes a modifier `levelExistsCheck` to ensure the level exists before querying.
     */
    function getNoOfCompletedSubmissionsForLevel(address level) public view levelExistsCheck(level) returns (uint256) {
        return levelStats[level].noOfInstancesSubmitted_Success;
    }

    /**
     * @notice Checks if a specific level exists in the system.
     * @param level The address of the level to check.
     * @return bool Returns true if the level exists, otherwise false.
     */
    function doesLevelExist(address level) public view returns (bool) {
        return levelExists[level];
    }

    /**
     * @notice Checks if a player exists in the system.
     *
     * @param player The address of the player to check.
     * @return bool Returns true if the player exists, otherwise false.
     */
    function doesPlayerExist(address player) public view returns (bool) {
        return playerExists[player];
    }

    /**
     * @notice Returns the total number of Ethernaut levels available.
     *
     * @return uint256 The total number of levels stored in the `levels` array.
     */
    function getTotalNoOfEthernautLevels() public view returns (uint256) {
        return levels.length;
    }

    /**
     * @notice Retrieves the average time taken by a specific player to complete levels.
     *
     * @param player The address of the player whose average completion time is being queried.
     * @return uint256 The average time taken by the player to complete levels.
     *
     * Steps:
     * 1. Return the value stored in the `averageTimeTakenToCompleteLevels` mapping for the given player address.
     */
    function getAverageTimeTakenToCompleteLevels(address player) public view returns (uint256) {
        return averageTimeTakenToCompleteLevels[player];
    }
}
