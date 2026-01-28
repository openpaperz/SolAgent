// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Statistics {

    /**
     * @notice Defines a structure to store information about a level instance.
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
     */
    struct Level {
        uint256 noOfInstancesCreated;
        uint256 noOfInstancesSubmitted_Success;
        uint256 noOfSubmissions_Failed;
    }

    address public ethernaut;
    bool private initialized;

    // Players
    address[] public players;
    mapping(address => bool) public playerExists;

    // Levels
    address[] public levels;
    mapping(address => bool) public levelExists;

    // Player => Level => instance info
    mapping(address => mapping(address => LevelInstance)) private playerLevelInstance;

    // Level specific stats
    mapping(address => Level) private levelStats;

    // Global counters
    uint256 private totalNoOfLevelInstancesCreated;
    uint256 private totalNoOfLevelInstancesCompleted;
    uint256 private globalNoOfFailedSubmissions;

    // Player specific counters
    mapping(address => uint256) private playerNoOfInstancesCreated;
    mapping(address => uint256) private playerNoOfInstancesCompleted;
    mapping(address => uint256) private playerNoOfFailedSubmissions;
    mapping(address => uint256) private playerNoOfLevelsCompleted;

    // First creation/completion times per player per level
    mapping(address => mapping(address => uint256)) private levelFirstInstanceCreationTime;
    mapping(address => mapping(address => uint256)) private levelFirstCompletionTime;

    // Failures per level per player
    mapping(address => mapping(address => uint256)) private failedSubmissionsForLevelAndPlayer;

    // Average time taken per player
    mapping(address => uint256) private averageTimeTakenToCompleteLevels;

    // Events
    event playerScoreProfile(address indexed player, uint256 totalLevelsCompleted, uint256 averageTimeTaken);

    // Modifiers
    modifier onlyEthernaut() {
        require(msg.sender == ethernaut, "Only Ethernaut");
        _;
    }

    modifier initializer() {
        require(!initialized, "Already initialized");
        initialized = true;
        _;
    }

    modifier playerExistsCheck(address player) {
        require(playerExists[player], "Player doesn't exist");
        _;
    }

    modifier levelExistsCheck(address level) {
        require(levelExists[level], "Level doesn't exist");
        _;
    }

    modifier levelDoesntExistCheck(address level) {
        require(!levelExists[level], "Level already exists");
        _;
    }

    /**
     * @notice Initializes the contract by setting the Ethernaut address.
     */
    function initialize(address _ethernautAddress) public initializer {
        require(_ethernautAddress != address(0), "Invalid address");
        ethernaut = _ethernautAddress;
    }

    /**
     * @notice Creates a new instance of a level for a player.
     */
    function createNewInstance(address instance, address level, address player) external levelExistsCheck(level) {
        require(msg.sender == ethernaut, "Only Ethernaut");

        if (!playerExists[player]) {
            players.push(player);
            playerExists[player] = true;
        }

        LevelInstance storage li = playerLevelInstance[player][level];

        // If first instance for this level for player, record creation time
        if (levelFirstInstanceCreationTime[player][level] == 0) {
            levelFirstInstanceCreationTime[player][level] = block.timestamp;
        }

        // Reset/initialize instance data
        li.instance = instance;
        li.isCompleted = false;
        li.timeCreated = block.timestamp;
        li.timeCompleted = 0;
        delete li.timeSubmitted;

        // Update counters
        totalNoOfLevelInstancesCreated += 1;
        levelStats[level].noOfInstancesCreated += 1;
        playerNoOfInstancesCreated[player] += 1;
    }

    /**
     * @notice Submits a successful level completion for a player.
     */
    function submitSuccess(address instance, address level, address player) external playerExistsCheck(player) {
        require(msg.sender == ethernaut, "Only Ethernaut");
        require(levelExists[level], "Level doesn't exist");

        LevelInstance storage li = playerLevelInstance[player][level];
        require(li.instance != address(0), "Instance not created");
        require(li.instance == instance, "Submitted instance mismatch");
        require(!li.isCompleted, "Level already completed");

        // If first completion for this level by player
        if (levelFirstCompletionTime[player][level] == 0) {
            playerNoOfLevelsCompleted[player] += 1;
            levelFirstCompletionTime[player][level] = block.timestamp;

            // Update average time taken
            uint256 newAverage = updateAverageTimeTakenToCompleteLevelsByPlayer(player, level, playerNoOfLevelsCompleted[player]);
            emit playerScoreProfile(player, playerNoOfLevelsCompleted[player], newAverage);
        }

        // Record submission and completion
        li.timeSubmitted.push(block.timestamp);
        li.timeCompleted = block.timestamp;
        li.isCompleted = true;

        // Update stats
        levelStats[level].noOfInstancesSubmitted_Success += 1;
        totalNoOfLevelInstancesCompleted += 1;
        playerNoOfInstancesCompleted[player] += 1;
    }

    /**
     * @notice Submits a failure for a level instance.
     */
    function submitFailure(address instance, address level, address player) external playerExistsCheck(player) {
        require(msg.sender == ethernaut, "Only Ethernaut");
        require(levelExists[level], "Level doesn't exist");

        LevelInstance storage li = playerLevelInstance[player][level];
        require(li.instance != address(0), "Instance not created");
        require(li.instance == instance, "Submitted instance mismatch");
        require(!li.isCompleted, "Level already completed");

        // Record submission timestamp
        li.timeSubmitted.push(block.timestamp);

        // Update failure counters
        levelStats[level].noOfSubmissions_Failed += 1;
        globalNoOfFailedSubmissions += 1;
        playerNoOfFailedSubmissions[player] += 1;
        failedSubmissionsForLevelAndPlayer[level][player] += 1;
    }

    /**
     * @notice Saves a new level address to the list of registered levels.
     */
    function saveNewLevel(address level) external onlyEthernaut {
        require(level != address(0), "Invalid level address");
        require(!levelExists[level], "Level already exists");
        levelExists[level] = true;
        levels.push(level);
    }

    /**
     * @notice Retrieves the total number of level instances created by a specific player.
     */
    function getTotalNoOfLevelInstancesCreatedByPlayer(address player) public playerExistsCheck(player) returns (uint256) {
        return playerNoOfInstancesCreated[player];
    }

    /**
     * @notice Retrieves the total number of level instances completed by a specific player.
     */
    function getTotalNoOfLevelInstancesCompletedByPlayer(address player) public playerExistsCheck(player) returns (uint256) {
        return playerNoOfInstancesCompleted[player];
    }

    /**
     * @notice Retrieves the total number of failed submissions by a specific player.
     */
    function getTotalNoOfFailedSubmissionsByPlayer(address player) public playerExistsCheck(player) returns (uint256) {
        return playerNoOfFailedSubmissions[player];
    }

    /**
     * @notice Retrieves the total number of levels completed by a specific player.
     */
    function getTotalNoOfLevelsCompletedByPlayer(address player) public playerExistsCheck(player) returns (uint256) {
        return playerNoOfLevelsCompleted[player];
    }

    /**
     * @notice Retrieves the total number of failures for a specific level and player.
     */
    function getTotalNoOfFailuresForLevelAndPlayer(address level, address player) public levelExistsCheck(level) returns (uint256) {
        if (!playerExists[player]) {
            return 0;
        }
        return failedSubmissionsForLevelAndPlayer[level][player];
    }

    /**
     * @notice Checks if a specific level has been completed by a player.
     */
    function isLevelCompleted(address player, address level) public levelExistsCheck(level) returns (bool) {
        if (!playerExists[player]) {
            return false;
        }
        return playerLevelInstance[player][level].isCompleted;
    }

    /**
     * @notice Retrieves the time elapsed between the creation and completion of a level instance for a specific player.
     */
    function getTimeElapsedForCompletionOfLevel(address player, address level) public levelExistsCheck(level) returns (uint256) {
        require(playerExists[player], "Player doesn't exist");
        uint256 completion = levelFirstCompletionTime[player][level];
        require(completion != 0, "Level not completed");
        uint256 creation = levelFirstInstanceCreationTime[player][level];
        return completion - creation;
    }

    /**
     * @notice Retrieves the submission time for a specific level by a player at a given index.
     */
    function getSubmissionsForLevelByPlayer(address player, address level, uint256 index) public levelExistsCheck(level) returns (uint256) {
        require(playerExists[player], "Player doesn't exist");
        LevelInstance storage li = playerLevelInstance[player][level];
        require(index < li.timeSubmitted.length, "Index outbounded");
        return li.timeSubmitted[index];
    }

    /**
     * @notice Calculates the percentage of levels completed by a player.
     */
    function getPercentageOfLevelsCompleted(address player) public playerExistsCheck(player) returns (uint256) {
        uint256 totalLevels = levels.length;
        if (totalLevels == 0) {
            return 0;
        }
        return (playerNoOfLevelsCompleted[player] * 1e18) / totalLevels;
    }

    /**
     * @notice Updates the average time taken by a player to complete levels.
     */
    function updateAverageTimeTakenToCompleteLevelsByPlayer(address player, address level, uint256 totalNoOfLevelsCompletedByPlayer) private returns (uint256) {
        uint256 lastAverage = averageTimeTakenToCompleteLevels[player];
        uint256 timeTaken = levelFirstCompletionTime[player][level] - levelFirstInstanceCreationTime[player][level];
        uint256 newAverage;
        if (totalNoOfLevelsCompletedByPlayer == 0) {
            newAverage = 0;
        } else if (totalNoOfLevelsCompletedByPlayer == 1) {
            newAverage = timeTaken;
        } else {
            // Weighted average: ((prevAvg * (n-1)) + timeTaken) / n
            newAverage = ((lastAverage * (totalNoOfLevelsCompletedByPlayer - 1)) + timeTaken) / totalNoOfLevelsCompletedByPlayer;
        }
        averageTimeTakenToCompleteLevels[player] = newAverage;
        return newAverage;
    }

    /**
     * @notice Returns the total number of level instances created.
     */
    function getTotalNoOfLevelInstancesCreated() public view returns (uint256) {
        return totalNoOfLevelInstancesCreated;
    }

    /**
     * @notice Returns the total number of level instances that have been completed globally.
     */
    function getTotalNoOfLevelInstancesCompleted() public view returns (uint256) {
        return totalNoOfLevelInstancesCompleted;
    }

    /**
     * @notice Returns the total number of failed submissions.
     */
    function getTotalNoOfFailedSubmissions() public view returns (uint256) {
        return globalNoOfFailedSubmissions;
    }

    /**
     * @notice Returns the total number of players currently registered in the system.
     */
    function getTotalNoOfPlayers() public view returns (uint256) {
        return players.length;
    }

    /**
     * @notice Retrieves the number of failed submissions for a specific level.
     */
    function getNoOfFailedSubmissionsForLevel(address level) public levelExistsCheck(level) returns (uint256) {
        return levelStats[level].noOfSubmissions_Failed;
    }

    /**
     * @notice Retrieves the number of instances created for a specific level.
     */
    function getNoOfInstancesForLevel(address level) public levelExistsCheck(level) returns (uint256) {
        return levelStats[level].noOfInstancesCreated;
    }

    /**
     * @notice Retrieves the number of successful submissions for a specific level.
     */
    function getNoOfCompletedSubmissionsForLevel(address level) public levelExistsCheck(level) returns (uint256) {
        return levelStats[level].noOfInstancesSubmitted_Success;
    }

    /**
     * @notice Checks if a specific level exists in the system.
     */
    function doesLevelExist(address level) public view returns (bool) {
        return levelExists[level];
    }

    /**
     * @notice Checks if a player exists in the system.
     */
    function doesPlayerExist(address player) public view returns (bool) {
        return playerExists[player];
    }

    /**
     * @notice Returns the total number of Ethernaut levels available.
     */
    function getTotalNoOfEthernautLevels() public view returns (uint256) {
        return levels.length;
    }

    /**
     * @notice Retrieves the average time taken by a specific player to complete levels.
     */
    function getAverageTimeTakenToCompleteLevels(address player) public view returns (uint256) {
        return averageTimeTakenToCompleteLevels[player];
    }
}
