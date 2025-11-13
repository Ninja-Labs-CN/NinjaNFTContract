// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/NinjaLabsGenesisNFT.sol";

/// @title DeployGenesisNinjaLabs
/// @notice Deploys the NinjaLabsGenesisNFT contract using Foundry scripts
contract DeployGenesisNinjaLabs is Script {
    uint256 internal constant DEFAULT_GENESIS_MAX_SUPPLY = 1000;
    string internal constant DEFAULT_GENESIS_BASE_URI = "https://api.ninjalabs.xyz/genesis/";

    NinjaLabsGenesisNFT public genesis;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 maxSupply = vm.envOr("GENESIS_MAX_SUPPLY", DEFAULT_GENESIS_MAX_SUPPLY);
        string memory baseURI = vm.envOr("GENESIS_BASE_URI", DEFAULT_GENESIS_BASE_URI);

        console.log("=== NinjaLabs Genesis Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Max Supply:", maxSupply);
        console.log("Base URI:", baseURI);

        vm.startBroadcast(deployerPrivateKey);
        genesis = new NinjaLabsGenesisNFT(maxSupply, baseURI);
        vm.stopBroadcast();

        console.log("Genesis contract deployed at:", address(genesis));
    }
}
