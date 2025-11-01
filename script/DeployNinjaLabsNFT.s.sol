// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/NinjaLabsNFT.sol";

/// @title DeployNinjaLabsNFT
/// @notice Foundry deployment script for Ninja Labs NFT contract
/// @dev Supports testnet and mainnet deployments with configurable parameters
contract DeployNinjaLabsNFT is Script {
    // ============ Deployment Configuration ============

    // Default Configuration (Testnet)
    uint256 constant DEFAULT_MAX_SUPPLY = 200;
    uint256 constant DEFAULT_MAX_PER_WALLET = 1;
    string constant DEFAULT_BASE_URI = "https://api.ninjalabs.xyz/metadata/";
    uint256 constant DEFAULT_TIER1_THRESHOLD = 100; // PURPLE tier
    uint256 constant DEFAULT_TIER2_THRESHOLD = 500; // ORANGE tier

    // Role addresses (to be set via environment variables)
    address public oracleAddress;
    address public upgraderAddress;
    address public treasuryAddress;

    // Deployed contract
    NinjaLabsNFT public nft;

    // ============ Main Deployment Function ============

    function run() external {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Load role addresses from environment (with fallbacks)
        oracleAddress = vm.envOr("ORACLE_ADDRESS", msg.sender);
        upgraderAddress = vm.envOr("UPGRADER_ADDRESS", msg.sender);
        treasuryAddress = vm.envOr("TREASURY_ADDRESS", msg.sender);

        // Load deployment parameters (with defaults)
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", DEFAULT_MAX_SUPPLY);
        uint256 maxPerWallet = vm.envOr("MAX_PER_WALLET", DEFAULT_MAX_PER_WALLET);
        string memory baseURI = vm.envOr("BASE_URI", DEFAULT_BASE_URI);
        uint256 tier1Threshold = vm.envOr("TIER1_THRESHOLD", DEFAULT_TIER1_THRESHOLD);
        uint256 tier2Threshold = vm.envOr("TIER2_THRESHOLD", DEFAULT_TIER2_THRESHOLD);

        console.log("=== Ninja Labs NFT Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Max Supply:", maxSupply);
        console.log("Max Per Wallet:", maxPerWallet);
        console.log("Base URI:", baseURI);
        console.log("Tier 1 Threshold:", tier1Threshold);
        console.log("Tier 2 Threshold:", tier2Threshold);
        console.log("");
        console.log("=== Role Addresses ===");
        console.log("Oracle:", oracleAddress);
        console.log("Upgrader:", upgraderAddress);
        console.log("Treasury:", treasuryAddress);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contract
        nft = new NinjaLabsNFT(maxSupply, maxPerWallet, baseURI, tier1Threshold, tier2Threshold);

        console.log("=== Deployment Successful ===");
        console.log("Contract Address:", address(nft));
        console.log("");

        // Grant roles if different from deployer
        if (oracleAddress != vm.addr(deployerPrivateKey)) {
            nft.grantRole(nft.ORACLE_ROLE(), oracleAddress);
            console.log("Granted ORACLE_ROLE to:", oracleAddress);
        }

        if (upgraderAddress != vm.addr(deployerPrivateKey)) {
            nft.grantRole(nft.UPGRADER_ROLE(), upgraderAddress);
            console.log("Granted UPGRADER_ROLE to:", upgraderAddress);
        }

        if (treasuryAddress != vm.addr(deployerPrivateKey)) {
            nft.grantRole(nft.TREASURY_ROLE(), treasuryAddress);
            console.log("Granted TREASURY_ROLE to:", treasuryAddress);
        }

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Next Steps:");
        console.log("1. Verify contract on block explorer");
        console.log("2. Set mint status: setMintActive(true)");
        console.log("3. Upload metadata to IPFS");
        console.log("4. Update base URI if needed");
        console.log("5. Test minting on testnet");

        vm.stopBroadcast();

        // Save deployment info
        saveDeploymentInfo();
    }

    // ============ Testnet Deployment ============

    function deployTestnet() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Testnet Deployment ===");
        console.log("Network: Injective Testnet");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy with testnet parameters
        nft = new NinjaLabsNFT(
            DEFAULT_MAX_SUPPLY,
            DEFAULT_MAX_PER_WALLET,
            DEFAULT_BASE_URI,
            DEFAULT_TIER1_THRESHOLD,
            DEFAULT_TIER2_THRESHOLD
        );

        console.log("Testnet Contract:", address(nft));
        console.log("Deployer has all roles for testing");

        // Enable minting for testnet
        nft.setMintActive(true);
        console.log("Minting enabled for testnet");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Testnet Ready ===");
        console.log("Contract Address:", address(nft));
    }

    // ============ Mainnet Deployment ============

    function deployMainnet() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Mainnet addresses (MUST be set via environment)
        oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        upgraderAddress = vm.envAddress("UPGRADER_ADDRESS");
        treasuryAddress = vm.envAddress("TREASURY_ADDRESS");

        // Mainnet parameters (MUST be set via environment)
        uint256 maxSupply = vm.envUint("MAX_SUPPLY");
        uint256 maxPerWallet = vm.envUint("MAX_PER_WALLET");
        string memory baseURI = vm.envString("BASE_URI");
        uint256 tier1Threshold = vm.envUint("TIER1_THRESHOLD");
        uint256 tier2Threshold = vm.envUint("TIER2_THRESHOLD");

        console.log("=== MAINNET DEPLOYMENT ===");
        console.log("WARNING: Deploying to MAINNET");
        console.log("Network: Injective Mainnet");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("");
        console.log("Configuration:");
        console.log("Max Supply:", maxSupply);
        console.log("Max Per Wallet:", maxPerWallet);
        console.log("Tier 1 Threshold:", tier1Threshold);
        console.log("Tier 2 Threshold:", tier2Threshold);
        console.log("");
        console.log("Roles:");
        console.log("Oracle:", oracleAddress);
        console.log("Upgrader:", upgraderAddress);
        console.log("Treasury:", treasuryAddress);
        console.log("");

        // Confirmation prompt (comment out for automated deployment)
        console.log("Deploying in 3 seconds...");
        console.log("Press Ctrl+C to cancel");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy with mainnet parameters
        nft = new NinjaLabsNFT(maxSupply, maxPerWallet, baseURI, tier1Threshold, tier2Threshold);

        console.log("Contract Deployed:", address(nft));

        // Grant roles
        nft.grantRole(nft.ORACLE_ROLE(), oracleAddress);
        nft.grantRole(nft.UPGRADER_ROLE(), upgraderAddress);
        nft.grantRole(nft.TREASURY_ROLE(), treasuryAddress);

        console.log("Roles granted successfully");
        console.log("");
        console.log("IMPORTANT: Minting is DISABLED by default");
        console.log("Enable after verification: setMintActive(true)");

        vm.stopBroadcast();

        console.log("");
        console.log("=== MAINNET DEPLOYMENT COMPLETE ===");
        console.log("Contract Address:", address(nft));
        console.log("");
        console.log("Next Steps:");
        console.log("1. Verify contract on Injective Explorer");
        console.log("2. Upload final metadata to IPFS");
        console.log("3. Confirm base URI is correct");
        console.log("4. Test with small mint before public launch");
        console.log("5. Enable public minting: setMintActive(true)");
        console.log("6. Monitor contract events");
        console.log("7. Set up Oracle for point syncing");

        saveDeploymentInfo();
    }

    // ============ Helper Functions ============

    function saveDeploymentInfo() internal {
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "contract": "',
                vm.toString(address(nft)),
                '",\n',
                '  "deployer": "',
                vm.toString(msg.sender),
                '",\n',
                '  "oracle": "',
                vm.toString(oracleAddress),
                '",\n',
                '  "upgrader": "',
                vm.toString(upgraderAddress),
                '",\n',
                '  "treasury": "',
                vm.toString(treasuryAddress),
                '",\n',
                '  "maxSupply": ',
                vm.toString(nft.maxSupply()),
                ",\n",
                '  "tier1Threshold": ',
                vm.toString(nft.tier1Threshold()),
                ",\n",
                '  "tier2Threshold": ',
                vm.toString(nft.tier2Threshold()),
                "\n",
                "}"
            )
        );

        console.log("");
        console.log("=== Deployment Info ===");
        console.log(deploymentInfo);
    }

    // ============ Verification Helper ============

    function getVerificationCommand() external view returns (string memory) {
        return string(
            abi.encodePacked(
                "forge verify-contract ",
                vm.toString(address(nft)),
                " src/NinjaLabsNFT.sol:NinjaLabsNFT ",
                "--chain-id <CHAIN_ID> ",
                "--etherscan-api-key <API_KEY> ",
                "--constructor-args $(cast abi-encode \"constructor(uint256,uint256,string,uint256,uint256)\" ",
                vm.toString(nft.maxSupply()),
                " ",
                vm.toString(nft.maxPerWallet()),
                " ",
                "\"<BASE_URI>\" ",
                vm.toString(nft.tier1Threshold()),
                " ",
                vm.toString(nft.tier2Threshold()),
                ")"
            )
        );
    }
}
