// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FoundryFundamentalsSection4Nft} from "src/FoundryFundamentalsSection4Nft.sol";

contract Section4NftHelper is Script {
    function run() external {
        vm.startBroadcast();

        FoundryFundamentalsSection4Nft helper = new FoundryFundamentalsSection4Nft(
                vm.envAddress("CHALLENGE_ADDRESS"),
                vm.envAddress("MY_EOA"),
                vm.envAddress("NFT_ADDRESS")
            );
        helper.solveSectionChallenge("Olaniyi_dev");

        vm.stopBroadcast();
    }
}
