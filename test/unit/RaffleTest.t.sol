// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";

contract RaffleTest is CodeConstants, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public player = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        vm.deal(player, STARTING_PLAYER_BALANCE);
    }

    // ENTER RAFFLE TESTS

    function testRaffleInitializesInOpenState() public view {
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.OPEN)
        ); // or assert(uint256(raffle.getRaffleState()) == 0)
    }

    function testRaffleRevertsWhenNotEnoughEthSent() public {
        // Arrange
        uint256 insufficientFee = 0.001 ether;
        // Act / Assert
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: insufficientFee}();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange / Act
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == player);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(player);

        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        // warp time and perform upkeep to change state to calculating
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        address player2 = makeAddr("player2");
        vm.deal(player2, STARTING_PLAYER_BALANCE);

        vm.prank(player2);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testMultiplePlayersCanEnter() public {
        // Arrange
        address player2 = makeAddr("player2");
        address player3 = makeAddr("player3");

        vm.deal(player2, STARTING_PLAYER_BALANCE);
        vm.deal(player3, STARTING_PLAYER_BALANCE);

        // Act
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        vm.prank(player2);
        raffle.enterRaffle{value: entranceFee}();

        vm.prank(player3);
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        assertEq(raffle.getPlayer(0), player);
        assertEq(raffle.getPlayer(1), player2);
        assertEq(raffle.getPlayer(2), player3);
    }

    // Gas optimization checks
    function testEnterRaffleUsesReasonableGas() public {
        // Arrange
        uint256 gasStart = gasleft();

        // Act
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        uint256 gasUsed = gasStart - gasleft();

        // Assert
        assertLt(gasUsed, 500000);
    }

    // Fuzz testing for entrance fee
    function testFuzzEntranceFee(uint256 amount) public {
        // Arrange
        vm.assume(amount < entranceFee);

        // Act / Assert
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: amount}();
    }

    // CHECK UPKEEP TESTS

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded);
    }

    // PERFORM UPKEEP

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // CALCULATING
    }

    // FULFILLRANDOMWORDS

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return; // Should not run when doing a forked test
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered skipFork {
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        ); // My first Stateless Fuzz Test
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
        skipFork
    {
        // Arrange
        uint256 additionalEntrants = 3; // 4 total players
        uint256 startingIndex = 1;
        // address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            // forge-lint: disable-next-line(unsafe-typecast)
            address newPlayer = address(uint160(i)); // casting to 'uint160' is safe because it is a cheatcode for converting numbers to an address
            hoax(newPlayer, 1 ether); // Cheat that sets up a prank AND also gives ether
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        // uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner != address(0));
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.OPEN));
        console.log("Winner balance is ", winnerBalance);
        console.log(
            "Expected balance is ",
            STARTING_PLAYER_BALANCE + prize - entranceFee
        );
        assert(winnerBalance == STARTING_PLAYER_BALANCE + prize - entranceFee);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
