# NinjaLabsNFT 合约使用说明

## 1. 合约概览
- **合约名称**：`NinjaLabsNFT`
- **标准**：ERC-721（继承 `ERC721Enumerable`，兼容 Injective EVM）
- **主要特性**：
  - 免费铸造（用户只支付 gas）。
  - 基于积分的三段式等级（WHITE / PURPLE / ORANGE）。
  - 支持链上动态升级、批量升级和可配置上限。
  - 通过角色控制（`DEFAULT_ADMIN_ROLE`、`ORACLE_ROLE`、`UPGRADER_ROLE`、`TREASURY_ROLE`）。

## 2. 部署准备
1. 安装 Foundry 并执行 `foundryup` 更新。
2. 拉取依赖：`git submodule update --init --recursive`。
3. 复制配置：`cp .env.example .env`，并在 `.env` 中设置以下变量：
   - `PRIVATE_KEY`：部署者私钥。
  
   - 可选覆盖项：`ORACLE_ADDRESS`、`UPGRADER_ADDRESS`、`TREASURY_ADDRESS`、`MAX_SUPPLY`、`MAX_PER_WALLET`、`BASE_URI`、`TIER1_THRESHOLD`、`TIER2_THRESHOLD`。

## 3. 部署流程
1. 选择 RPC：Injective Testnet 示例 `https://injective-testnet-rpc`。
2. 执行部署（读取 `.env` 参数）：
   ```bash
   forge script script/DeployNinjaLabsNFT.s.sol:DeployNinjaLabsNFT \
     --rpc-url $INJ_RPC_URL \
     --broadcast \
     --verify
   ```
3. 部署脚本功能：
   - 以默认参数或 `.env` 覆盖值实例化合约。
   - 按需将 Oracle/Upgrader/Treasury 角色授予指定地址。
   - 在控制台输出验证命令与部署摘要。
4. 快速测试部署：调用 `forge script script/DeployNinjaLabsNFT.s.sol:deployTestnet` 使用默认参数并自动开启铸造。

## 4. 角色与权限
- `DEFAULT_ADMIN_ROLE`：配置供应上限、级别阈值、Base URI、暂停状态等。
- `ORACLE_ROLE`：调用 `updatePoints` / `batchUpdatePoints` 同步积分。
- `UPGRADER_ROLE`：执行 `batchUpgrade`，适用于后台自动升级或活动奖励。
- `TREASURY_ROLE`：调用 `withdraw` 提取合约余额。
- 示例：
  ```solidity
  nft.grantRole(nft.ORACLE_ROLE(), oracleWallet);
  ```

## 5. 积分与等级阈值
- 阈值设定：`setTierThresholds(uint256 tier1, uint256 tier2)`，要求 `tier1 < tier2`。
- Oracle 同步：
  ```solidity
  // 单用户刷新
  nft.updatePoints(user, 250);
  // 批量刷新
  nft.batchUpdatePoints(users, pointsArray);
  ```
- 刷新后可由后台（`UPGRADER_ROLE`）调用 `batchUpgrade`，或由用户自行调用 `upgradeNFT`。

## 6. 铸造与升级流程
- **开启铸造**：管理员调用 `setMintActive(true)`。
- **用户免费铸造**：
  ```solidity
  nft.mint("ipfs://hash-for-white-tier");
  ```
  - 限制：总量 `maxSupply`，每地址 `maxPerWallet`。
- **用户自助升级**：
  ```solidity
  nft.upgradeNFT(tokenId);
  ```
  - 仅在积分达到更高阈值时成功；ORANGE 为最终等级。
- **后台批量升级**：
  ```solidity
  uint256[] memory ids = new uint256[](3);
  ids[0] = 1;
  ids[1] = 2;
  ids[2] = 3;
  nft.batchUpgrade(ids);
  ```

## 7. 查询接口（前端 / Bot 使用）
- 部署只读伴随合约 `NinjaLabsNFTView`（`src/NinjaLabsNFTView.sol`）：
  ```solidity
  NinjaLabsNFTView viewContract = new NinjaLabsNFTView(payable(address(nft)));
  ```
- View 合约提供聚合查询：
  - `getUserStats(address)`：返回持有数量、当前积分、最高等级、下一等级差值。
  - `getTierProgress(address)`：返回当前等级、下一等级阈值与所需积分。
  - `getOwnedTokenSnapshots(address)`：列出所有 NFT 的等级、可否升级、图片哈希、时间戳。
  - `getTierThresholds()`：返回 WHITE→PURPLE→ORANGE 的分值边界。
  - `getSupplyStatus()`：返回已铸数量、供应上限、剩余可铸数量。
- 主合约仍暴露基础只读数据：`userPoints(address)`, `tokenMetadata(uint256)`, `canUpgrade(uint256)` 等，可按需组合。

## 8. 配置与维护
- **扩充供应**：`setMaxSupply(newMax)` 仅允许增量（必须 ≥ 已铸数量和当前上限）。
- **更新 Base URI**：`setBaseURI(newUri)`；前端通过 `tokenURI` 拼接元数据。
- **暂停/恢复**：`pause()` / `unpause()` 用于紧急止损。
- **资金管理**：收到的 INJ 通过 `withdraw()` 由 Treasury 钱包提取。

## 9. 社区与运营集成
- Bot 可监听以下事件即时推送：`PointsUpdated`、`NFTUpgraded`、`MintStatusChanged`。
- Dashboard 使用 `getTierProgress` + `getOwnedTokenSnapshots` 提供可视化升级路径。
- 积分判定在链下执行，可结合 Discord、工单或活动系统，最终经 Oracle 上链确认。
- 可在 `.env.example` 中维护默认配置，确保新成员同步最新参数。

## 10. 测试与调试
- 全量测试：`forge test`（当前 49 项用例覆盖铸造、积分、升级、配置与查询）。
- 定向测试：`forge test --match-test testUpgradeNFTFromWhiteToPurple`。
- Fork 调试（示例）：
  ```bash
  forge test --fork-url $INJ_MAINNET_RPC --match-test testBatchUpgrade
  ```

## 11. 常见问题解答
- **铸造失败**：检查 `mintActive` 是否为 `true`，钱包是否超额，以及供应是否已满。
- **积分刷新但 NFT 未升级**：用户需调用 `upgradeNFT`，或由后台批量升级。
- **阈值调整影响**：调用 `setTierThresholds` 后需同步前端及 Oracle 配置。
- **如何查下一等级差距**：`getTierProgress` 返回 `pointsToNextTier`。

若需扩展交易市场、质押或跨项目合作，建议以独立模块实现并沿用现有角色体系，以降低合约复杂度与攻击面。
