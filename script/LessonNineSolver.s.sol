// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Solver} from "../src/foundrycoursechallenge/Solver.sol";

contract LessonNineSolver is Script {
    function run() external {
        vm.startBroadcast();

        address challengeAddress = vm.envAddress("CHALLENGE_ADDRESS");
        string memory twitterHandle = "@Olaniyi_dev";

        Solver solver = new Solver(challengeAddress);
        solver.solve(twitterHandle);

        vm.stopBroadcast();
    }
}
