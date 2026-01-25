// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {LessonNine} from "./9-Lesson.sol";

contract Solver {
    LessonNine public immutable i_challenge;

    constructor(address challengeAddress) {
        i_challenge = LessonNine(challengeAddress);
    }

    function solve(string memory twitterHandle) external {
        uint256 correctAnswer =
            uint256(keccak256(abi.encodePacked(address(this), block.prevrandao, block.timestamp))) % 100000;

        i_challenge.solveChallenge(correctAnswer, twitterHandle);
    }
}
