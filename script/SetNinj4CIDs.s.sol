// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "../src/NINJ4NFT.sol";

/// @notice Batch set per-token CIDs from docs/ninj4/metadata_cid_arrays.json
contract SetNinj4CIDs is Script {
    using stdJson for string;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address contractAddr = vm.envAddress("GENESIS_ADDRESS");
        string memory path = vm.envOr("CID_ARRAY_PATH", string("docs/ninj4/metadata_cid_arrays.json"));
        uint256 batchSize = vm.envOr("CID_BATCH_SIZE", uint256(40));

        string memory json = vm.readFile(path);
        uint256[] memory ids = abi.decode(vm.parseJson(json, ".tokenIds"), (uint256[]));
        string[] memory cids = abi.decode(vm.parseJson(json, ".cids"), (string[]));
        require(ids.length == cids.length, "array length mismatch");

        NINJ4NFT nft = NINJ4NFT(contractAddr);

        vm.startBroadcast(pk);
        for (uint256 i = 0; i < ids.length; i += batchSize) {
            uint256 end = i + batchSize;
            if (end > ids.length) end = ids.length;
            uint256 chunk = end - i;
            uint256[] memory idBatch = new uint256[](chunk);
            string[] memory cidBatch = new string[](chunk);
            for (uint256 j = 0; j < chunk; j++) {
                idBatch[j] = ids[i + j];
                cidBatch[j] = cids[i + j];
            }
            nft.setTokenCIDs(idBatch, cidBatch);
        }
        vm.stopBroadcast();
    }
}
