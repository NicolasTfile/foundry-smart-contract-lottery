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

    // CHECK UPKEEP TESTS
}
