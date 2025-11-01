// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./NinjaLabsNFT.sol";

/// @title NinjaLabsNFTView
/// @notice Read-only helper contract that aggregates NinjaLabsNFT queries
/// @dev Deploy once per NinjaLabsNFT instance and reuse for dashboards/bots
contract NinjaLabsNFTView {
    error InvalidNFTAddress();

    NinjaLabsNFT public immutable nft;

    struct UserStats {
        uint256 totalOwned;
        uint256 points;
        NinjaLabsNFT.TierLevel highestTier;
        NinjaLabsNFT.TierLevel eligibleTier;
        NinjaLabsNFT.TierLevel nextTier;
        uint256 nextTierThreshold;
        uint256 pointsToNextTier;
    }

    struct TierProgress {
        NinjaLabsNFT.TierLevel currentTier;
        NinjaLabsNFT.TierLevel nextTier;
        uint256 currentPoints;
        uint256 nextTierThreshold;
        uint256 pointsToNextTier;
    }

    struct TokenSnapshot {
        uint256 tokenId;
        NinjaLabsNFT.TierLevel tier;
        uint256 mintDate;
        uint256 lastUpgradeDate;
        string imageHash;
        bool canUpgrade;
        NinjaLabsNFT.TierLevel eligibleTier;
    }

    constructor(address payable nftAddress) {
        if (nftAddress == address(0)) revert InvalidNFTAddress();
        nft = NinjaLabsNFT(nftAddress);
    }

    /// @notice Aggregate per-user stats including tier progress
    function getUserStats(address user) external view returns (UserStats memory stats) {
        uint256 balance = nft.balanceOf(user);
        uint256 points = nft.userPoints(user);
        NinjaLabsNFT.TierLevel highestTier = NinjaLabsNFT.TierLevel.WHITE;

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = nft.tokenOfOwnerByIndex(user, i);
            (NinjaLabsNFT.TierLevel tier,,,) = nft.tokenMetadata(tokenId);
            if (tier > highestTier) {
                highestTier = tier;
            }
        }

        (
            NinjaLabsNFT.TierLevel eligibleTier,
            NinjaLabsNFT.TierLevel nextTier,
            uint256 nextThreshold,
            uint256 pointsToNext
        ) = _tierProgress(points);

        return UserStats({
            totalOwned: balance,
            points: points,
            highestTier: highestTier,
            eligibleTier: eligibleTier,
            nextTier: nextTier,
            nextTierThreshold: nextThreshold,
            pointsToNextTier: pointsToNext
        });
    }

    /// @notice Return tier progress information for a user
    function getTierProgress(address user) external view returns (TierProgress memory progress) {
        uint256 points = nft.userPoints(user);

        (
            NinjaLabsNFT.TierLevel currentTier,
            NinjaLabsNFT.TierLevel nextTier,
            uint256 nextThreshold,
            uint256 pointsToNext
        ) = _tierProgress(points);

        return TierProgress({
            currentTier: currentTier,
            nextTier: nextTier,
            currentPoints: points,
            nextTierThreshold: nextThreshold,
            pointsToNextTier: pointsToNext
        });
    }

    /// @notice Return per-token snapshot enriched with upgrade eligibility
    function getOwnedTokenSnapshots(address user) external view returns (TokenSnapshot[] memory snapshots) {
        uint256 balance = nft.balanceOf(user);
        snapshots = new TokenSnapshot[](balance);

        uint256 points = nft.userPoints(user);
        NinjaLabsNFT.TierLevel eligibleTier = _calculateTier(points);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = nft.tokenOfOwnerByIndex(user, i);
            (NinjaLabsNFT.TierLevel tier, uint256 mintDate, uint256 lastUpgradeDate, string memory imageHash) =
                nft.tokenMetadata(tokenId);
            bool canUpgrade = eligibleTier > tier;

            snapshots[i] = TokenSnapshot({
                tokenId: tokenId,
                tier: tier,
                mintDate: mintDate,
                lastUpgradeDate: lastUpgradeDate,
                imageHash: imageHash,
                canUpgrade: canUpgrade,
                eligibleTier: eligibleTier
            });
        }
    }

    /// @notice Tier thresholds expressed as ranges
    function getTierThresholds()
        external
        view
        returns (uint256 whiteUpperBound, uint256 purpleLowerBound, uint256 purpleUpperBound, uint256 orangeLowerBound)
    {
        uint256 tier1 = nft.tier1Threshold();
        uint256 tier2 = nft.tier2Threshold();

        whiteUpperBound = tier1 == 0 ? 0 : tier1 - 1;
        purpleLowerBound = tier1;
        purpleUpperBound = tier2 == 0 ? 0 : tier2 - 1;
        orangeLowerBound = tier2;
    }

    /// @notice Supply status helper for dashboards
    function getSupplyStatus()
        external
        view
        returns (uint256 totalMintedSupply, uint256 supplyCap, uint256 remainingSupply)
    {
        totalMintedSupply = nft.totalMinted();
        supplyCap = nft.maxSupply();
        remainingSupply = supplyCap - totalMintedSupply;
    }

    function _tierProgress(uint256 points)
        internal
        view
        returns (
            NinjaLabsNFT.TierLevel currentTier,
            NinjaLabsNFT.TierLevel nextTier,
            uint256 nextThreshold,
            uint256 pointsToNext
        )
    {
        currentTier = _calculateTier(points);

        if (currentTier == NinjaLabsNFT.TierLevel.WHITE) {
            nextTier = NinjaLabsNFT.TierLevel.PURPLE;
            nextThreshold = nft.tier1Threshold();
            pointsToNext = points >= nextThreshold ? 0 : nextThreshold - points;
        } else if (currentTier == NinjaLabsNFT.TierLevel.PURPLE) {
            nextTier = NinjaLabsNFT.TierLevel.ORANGE;
            nextThreshold = nft.tier2Threshold();
            pointsToNext = points >= nextThreshold ? 0 : nextThreshold - points;
        } else {
            nextTier = NinjaLabsNFT.TierLevel.ORANGE;
            nextThreshold = 0;
            pointsToNext = 0;
        }
    }

    function _calculateTier(uint256 points) internal view returns (NinjaLabsNFT.TierLevel) {
        uint256 tier1 = nft.tier1Threshold();
        uint256 tier2 = nft.tier2Threshold();

        if (points >= tier2) {
            return NinjaLabsNFT.TierLevel.ORANGE;
        } else if (points >= tier1) {
            return NinjaLabsNFT.TierLevel.PURPLE;
        }
        return NinjaLabsNFT.TierLevel.WHITE;
    }
}
