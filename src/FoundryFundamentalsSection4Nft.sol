// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface LessonNine {
    function solveChallenge(
        uint256 randomGuess,
        string memory twitterHandle
    ) external;
}

contract FoundryFundamentalsSection4Nft is IERC721Receiver {
    LessonNine public challenge;
    address private immutable MY_EOA;
    address private immutable NFT_ADDRESS;

    constructor(
        address _challengeAddress,
        address _MY_EOA,
        address _NFT_ADDRESS
    ) {
        challenge = LessonNine(_challengeAddress);
        MY_EOA = _MY_EOA;
        NFT_ADDRESS = _NFT_ADDRESS;
    }

    function solveSectionChallenge(string memory twitterHandle) external {
        // Generate the pseudo-random guess
        uint256 answer = uint256(
            keccak256(
                abi.encodePacked(
                    address(this),
                    block.prevrandao,
                    block.timestamp
                )
            )
        ) % 100000;
        challenge.solveChallenge(answer, twitterHandle);
    }

    // Required for receiving ERC721 NFT
    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 tokenId,
        bytes calldata /*data*/
    ) external override returns (bytes4) {
        ERC721(NFT_ADDRESS).safeTransferFrom(address(this), MY_EOA, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
}
