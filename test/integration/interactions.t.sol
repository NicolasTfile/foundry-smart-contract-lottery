// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// unit
// integrations
// forked
// staging <- run tests on a mainnet or testnet

// fuzzing
// stateful fuzz
// stateless fuzz
// formal verification

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract Interactions is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    // ENTER RAFFLE TESTS

    function testPlayerCanEnterRaffle() public {
        // Arrange
        uint256 entranceFee = raffle.getEntranceFee();
        // Act
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assertEq(playerRecorded, PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        uint256 entranceFee = raffle.getEntranceFee();
        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRevertsWhenNotEnoughEthSent() public {
        // Arrange
        uint256 insufficientFee = 0.001 ether;
        // Act / Assert
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: insufficientFee}();
    }

    function testMultiplePlayersCanEnter() public {
        // Arrange
        uint256 entranceFee = raffle.getEntranceFee();
        address player2 = makeAddr("player2");
        address player3 = makeAddr("player3");

        vm.deal(player2, STARTING_PLAYER_BALANCE);
        vm.deal(player3, STARTING_PLAYER_BALANCE);

        // Act
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.prank(player2);
        raffle.enterRaffle{value: entranceFee}();

        vm.prank(player3);
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        assertEq(raffle.getPlayer(0), PLAYER);
        assertEq(raffle.getPlayer(1), player2);
        assertEq(raffle.getPlayer(2), player3);
    }

    function testCannotEnterWhenRaffleIsCalculating() public {
        // Arrange
        uint256 interval = raffle.getInterval();
        uint256 entranceFee = raffle.getEntranceFee();

        vm.prank(PLAYER);
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

    // CHECK UPKEEP TESTS

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        uint256 entranceFee = raffle.getEntranceFee();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + raffle.getInterval() + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimePassed() public {
        // Arrange
        uint256 entranceFee = raffle.getEntranceFee();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        uint256 entranceFee = raffle.getEntranceFee();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + raffle.getInterval() + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded);
    }
}
