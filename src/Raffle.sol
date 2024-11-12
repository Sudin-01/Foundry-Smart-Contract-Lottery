// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title A simple Raffle contract
 * @author Sudin Shrestha
 * @notice The contract is for crating a sample raffle cpntract
 * @dev Implementation Chainlink Version VRFv2.5
 */
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferSucessFailed();
    error Raffle__NotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 playerlength, uint256 rafflestate);

    /**
     * Type Declarations
     */
    enum RaffleState {
        Open, //0
        Calculating //1

    }

    /**
     * State Varriabel
     */
    uint256 private immutable i_subscriptionID;
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint256 private immutable i_interval; //Duration of an interval time for the lottery(second)
    uint256 private immutable i_entrancefee;
    //An entrancefee to enter the lottery
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players; //Track the number of the player in lottery
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**
     * Creating an Events
     */
    event RaffleEntered(address indexed players);
    event WinnerReported(address indexed WinnerAddress);
    event RequestedRaffleWinner(uint256 indexed RaffleId);

    constructor(
        uint256 entrancefee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        uint256 subscriptionID
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_interval = interval;
        i_entrancefee = entrancefee;
        i_keyHash = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        i_subscriptionID = subscriptionID;

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.Open;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entrancefee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.Open) {
            revert Raffle__NotOpen();
        }

        //require(msg.value>=i_entrancefee,"Not more ether sent") uses more gas
        s_players.push(payable(msg.sender));
        //1.Make migration easrier
        emit RaffleEntered(msg.sender);
    }

    /**
     * The following should be true for the upkeepNEeded to be true
     * The time interval has passed between raffle runs
     * The lottery is open
     * The conract has ETH(has playees)
     * Imlicitly,uour subscription has linked
     * @param - ignored
     * @return upkeepNeeded - true if its time to restart the lottery
     */
    function checkUpkeep(bytes memory)
        public
        view
        returns (
            /**
             * checkData
             */
            bool upkeepNeeded,
            bytes memory
        )
    /**
     * performData
     */
    {
        bool timeHasPassed = (block.timestamp - s_lastTimestamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.Open;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // * 1.Get a random number
    //* 2.Pick the winner through the random number
    // * 3.Be automatically called
    function performUpkeep(bytes calldata /* performData */ ) external {
        //Checks
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.Calculating;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionID,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedRaffleWinner(requestId);
    }

    //We follow the CEI:Check,Emmit(internal COntract Check, Effect and Interactions Pattern)

    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    ) internal virtual override {
        //Internal Contract State
        uint256 indexofwinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexofwinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.Open; //Reset the array for lottery
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerReported(s_recentWinner);

        //External COntract Interactions
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferSucessFailed();
        }
    }

    /**
     * Getter function
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entrancefee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayerRecord(uint256 indexofplayer) external view returns (address) {
        return s_players[indexofplayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
