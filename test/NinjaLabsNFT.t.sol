// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../src/NinjaLabsNFT.sol";
import "../src/NinjaLabsNFTView.sol";

contract NinjaLabsNFTTest is Test {
    using Strings for uint256;

    NinjaLabsNFT internal nft;
    NinjaLabsNFTView internal nftView;

    address internal owner;
    address internal oracle;
    address internal upgrader;
    address internal treasury;
    address internal user1;
    address internal user2;
    address internal user3;

    uint256 internal constant MAX_SUPPLY = 200;
    uint256 internal constant MAX_PER_WALLET = 2;
    uint256 internal constant TIER1_THRESHOLD = 100;
    uint256 internal constant TIER2_THRESHOLD = 500;
    string internal constant BASE_URI = "ipfs://QmTest/";
    string internal constant IMAGE_HASH_1 = "QmImage1";
    string internal constant IMAGE_HASH_2 = "QmImage2";

    event NFTMinted(address indexed to, uint256 indexed tokenId, string imageHash, uint256 timestamp);
    event NFTUpgraded(
        uint256 indexed tokenId, NinjaLabsNFT.TierLevel oldTier, NinjaLabsNFT.TierLevel newTier, uint256 timestamp
    );
    event PointsUpdated(address indexed user, uint256 oldPoints, uint256 newPoints, uint256 timestamp);
    event PaymentReceived(address indexed from, uint256 amount, uint256 timestamp);
    event FundsWithdrawn(address indexed to, uint256 amount, uint256 timestamp);

    function setUp() public {
        owner = address(this);
        oracle = makeAddr("oracle");
        upgrader = makeAddr("upgrader");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        nft = new NinjaLabsNFT(MAX_SUPPLY, MAX_PER_WALLET, BASE_URI, TIER1_THRESHOLD, TIER2_THRESHOLD);

        nft.grantRole(nft.ORACLE_ROLE(), oracle);
        nft.grantRole(nft.UPGRADER_ROLE(), upgrader);
        nft.grantRole(nft.TREASURY_ROLE(), treasury);

        nftView = new NinjaLabsNFTView(payable(address(nft)));

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    // ============ Constructor Tests ============

    function testConstructorInitialization() public {
        assertEq(nft.maxSupply(), MAX_SUPPLY);
        assertEq(nft.maxPerWallet(), MAX_PER_WALLET);
        assertEq(nft.tier1Threshold(), TIER1_THRESHOLD);
        assertEq(nft.tier2Threshold(), TIER2_THRESHOLD);
        assertEq(nft.totalMinted(), 0);
        assertFalse(nft.mintActive());
    }

    function testConstructorRevertsOnInvalidMaxSupply() public {
        vm.expectRevert(NinjaLabsNFT.InvalidMaxSupply.selector);
        new NinjaLabsNFT(0, MAX_PER_WALLET, BASE_URI, TIER1_THRESHOLD, TIER2_THRESHOLD);
    }

    function testConstructorRevertsOnInvalidMaxPerWallet() public {
        vm.expectRevert(NinjaLabsNFT.WalletLimitExceeded.selector);
        new NinjaLabsNFT(MAX_SUPPLY, 0, BASE_URI, TIER1_THRESHOLD, TIER2_THRESHOLD);
    }

    function testConstructorRevertsOnMaxPerWalletExceedsSupply() public {
        vm.expectRevert(NinjaLabsNFT.WalletLimitExceeded.selector);
        new NinjaLabsNFT(10, 20, BASE_URI, TIER1_THRESHOLD, TIER2_THRESHOLD);
    }

    function testConstructorRevertsOnInvalidThresholds() public {
        vm.expectRevert(NinjaLabsNFT.InvalidThresholds.selector);
        new NinjaLabsNFT(MAX_SUPPLY, MAX_PER_WALLET, BASE_URI, 500, 100);
    }

    function testConstructorGrantsRolesToDeployer() public {
        assertTrue(nft.hasRole(nft.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(nft.hasRole(nft.ORACLE_ROLE(), owner));
        assertTrue(nft.hasRole(nft.UPGRADER_ROLE(), owner));
        assertTrue(nft.hasRole(nft.TREASURY_ROLE(), owner));
    }

    // ============ Minting Tests ============

    function testMintRevertsWhenClosed() public {
        vm.prank(user1);
        vm.expectRevert(NinjaLabsNFT.MintClosed.selector);
        nft.mint(IMAGE_HASH_1);
    }

    function testMintRevertsWhenValueSent() public {
        nft.setMintActive(true);

        vm.prank(user1);
        (bool success,) = address(nft).call{value: 1 wei}(abi.encodeWithSelector(nft.mint.selector, IMAGE_HASH_1));
        assertFalse(success);
        assertEq(nft.balanceOf(user1), 0);
    }

    function testMint() public {
        nft.setMintActive(true);

        vm.prank(user1);
        nft.mint(IMAGE_HASH_1);

        assertEq(nft.balanceOf(user1), 1);
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.mintedCount(user1), 1);
    }

    function testMintRespectsWalletLimit() public {
        nft.setMintActive(true);

        vm.startPrank(user1);
        nft.mint(IMAGE_HASH_1);
        nft.mint(IMAGE_HASH_2);

        vm.expectRevert(NinjaLabsNFT.WalletLimitExceeded.selector);
        nft.mint("QmOverflow");
        vm.stopPrank();
    }

    function testMintRespectsMaxSupply() public {
        NinjaLabsNFT smallNft = new NinjaLabsNFT(2, 2, BASE_URI, TIER1_THRESHOLD, TIER2_THRESHOLD);
        smallNft.setMintActive(true);

        vm.prank(user1);
        smallNft.mint(IMAGE_HASH_1);

        vm.prank(user2);
        smallNft.mint(IMAGE_HASH_2);

        vm.prank(user3);
        vm.expectRevert(NinjaLabsNFT.SupplyExceeded.selector);
        smallNft.mint("QmLast");
    }

    function testMintWhenPaused() public {
        nft.setMintActive(true);
        nft.pause();

        vm.prank(user1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        nft.mint(IMAGE_HASH_1);
    }

    // ============ Admin Mint Tests ============

    function testAdminMint() public {
        nft.adminMint(user1, IMAGE_HASH_1);

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.balanceOf(user1), 1);
    }

    function testAdminMintRevertsOnInvalidAddress() public {
        vm.expectRevert(NinjaLabsNFT.InvalidAddress.selector);
        nft.adminMint(address(0), IMAGE_HASH_1);
    }

    function testAdminMintRevertsOnSupplyExceeded() public {
        NinjaLabsNFT smallNft = new NinjaLabsNFT(1, 1, BASE_URI, TIER1_THRESHOLD, TIER2_THRESHOLD);
        smallNft.adminMint(user1, IMAGE_HASH_1);

        vm.expectRevert(NinjaLabsNFT.SupplyExceeded.selector);
        smallNft.adminMint(user2, IMAGE_HASH_1);
    }

    function testAdminMintRequiresRole() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.adminMint(user2, IMAGE_HASH_1);
    }

    function testBatchMint() public {
        string[] memory hashes = new string[](3);
        hashes[0] = "QmHash1";
        hashes[1] = "QmHash2";
        hashes[2] = "QmHash3";

        nft.batchMint(user1, hashes);

        assertEq(nft.balanceOf(user1), 3);
        assertEq(nft.totalMinted(), 3);
    }

    function testBatchMintRevertsOnZeroQuantity() public {
        string[] memory hashes = new string[](0);

        vm.expectRevert(NinjaLabsNFT.QuantityZero.selector);
        nft.batchMint(user1, hashes);
    }

    // ============ Point Management Tests ============

    function testUpdatePoints() public {
        vm.expectEmit(true, false, false, true);
        emit PointsUpdated(user1, 0, 150, block.timestamp);

        vm.prank(oracle);
        nft.updatePoints(user1, 150);

        assertEq(nft.getUserPoints(user1), 150);
    }

    function testUpdatePointsRequiresOracleRole() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.updatePoints(user2, 100);
    }

    function testUpdatePointsRevertsOnInvalidAddress() public {
        vm.prank(oracle);
        vm.expectRevert(NinjaLabsNFT.InvalidAddress.selector);
        nft.updatePoints(address(0), 100);
    }

    function testBatchUpdatePoints() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        uint256[] memory points = new uint256[](3);
        points[0] = 100;
        points[1] = 250;
        points[2] = 600;

        vm.prank(oracle);
        nft.batchUpdatePoints(users, points);

        assertEq(nft.getUserPoints(user1), 100);
        assertEq(nft.getUserPoints(user2), 250);
        assertEq(nft.getUserPoints(user3), 600);
    }

    function testBatchUpdatePointsRevertsOnArrayMismatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        uint256[] memory points = new uint256[](3);
        points[0] = 100;
        points[1] = 200;
        points[2] = 300;

        vm.prank(oracle);
        vm.expectRevert(NinjaLabsNFT.ArrayLengthMismatch.selector);
        nft.batchUpdatePoints(users, points);
    }

    // ============ Upgrade Tests ============

    function _mintFor(address user) internal returns (uint256 tokenId) {
        nft.setMintActive(true);
        vm.prank(user);
        nft.mint(IMAGE_HASH_1);
        tokenId = nft.tokenOfOwnerByIndex(user, nft.balanceOf(user) - 1);
    }

    function testUpgradeNFTFromWhiteToPurple() public {
        uint256 tokenId = _mintFor(user1);

        vm.prank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD);

        vm.expectEmit(true, false, false, true);
        emit NFTUpgraded(tokenId, NinjaLabsNFT.TierLevel.WHITE, NinjaLabsNFT.TierLevel.PURPLE, block.timestamp);

        vm.prank(user1);
        nft.upgradeNFT(tokenId);

        NinjaLabsNFT.NFTMetadata memory metadata = nft.getNFTMetadata(tokenId);
        assertEq(uint256(metadata.tier), uint256(NinjaLabsNFT.TierLevel.PURPLE));
        assertEq(metadata.lastUpgradeDate, block.timestamp);
    }

    function testUpgradeNFTFromPurpleToOrange() public {
        uint256 tokenId = _mintFor(user1);

        vm.prank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD);
        vm.prank(user1);
        nft.upgradeNFT(tokenId);

        vm.prank(oracle);
        nft.updatePoints(user1, TIER2_THRESHOLD);

        vm.prank(user1);
        nft.upgradeNFT(tokenId);

        NinjaLabsNFT.NFTMetadata memory metadata = nft.getNFTMetadata(tokenId);
        assertEq(uint256(metadata.tier), uint256(NinjaLabsNFT.TierLevel.ORANGE));
    }

    function testUpgradeRevertsIfNotOwner() public {
        uint256 tokenId = _mintFor(user1);

        vm.prank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD);

        vm.prank(user2);
        vm.expectRevert(NinjaLabsNFT.NotTokenOwner.selector);
        nft.upgradeNFT(tokenId);
    }

    function testUpgradeRevertsIfAlreadyMaxTier() public {
        uint256 tokenId = _mintFor(user1);

        vm.prank(oracle);
        nft.updatePoints(user1, TIER2_THRESHOLD);

        vm.prank(user1);
        nft.upgradeNFT(tokenId);

        vm.prank(user1);
        vm.expectRevert(NinjaLabsNFT.AlreadyMaxTier.selector);
        nft.upgradeNFT(tokenId);
    }

    function testUpgradeRevertsIfInsufficientPoints() public {
        uint256 tokenId = _mintFor(user1);

        vm.prank(oracle);
        nft.updatePoints(user1, 50);

        vm.prank(user1);
        vm.expectRevert(NinjaLabsNFT.InsufficientPoints.selector);
        nft.upgradeNFT(tokenId);
    }

    function testUpgradeWhenPaused() public {
        uint256 tokenId = _mintFor(user1);

        vm.prank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD);

        nft.pause();

        vm.prank(user1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        nft.upgradeNFT(tokenId);
    }

    function testBatchUpgrade() public {
        uint256 tokenId1 = _mintFor(user1);
        uint256 tokenId2 = _mintFor(user2);
        uint256 tokenId3 = _mintFor(user3);

        vm.startPrank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD);
        nft.updatePoints(user2, TIER2_THRESHOLD);
        nft.updatePoints(user3, 50);
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        tokenIds[2] = tokenId3;

        vm.prank(upgrader);
        nft.batchUpgrade(tokenIds);

        assertEq(uint256(nft.getNFTMetadata(tokenId1).tier), uint256(NinjaLabsNFT.TierLevel.PURPLE));
        assertEq(uint256(nft.getNFTMetadata(tokenId2).tier), uint256(NinjaLabsNFT.TierLevel.ORANGE));
        assertEq(uint256(nft.getNFTMetadata(tokenId3).tier), uint256(NinjaLabsNFT.TierLevel.WHITE));
    }

    function testBatchUpgradeRequiresRole() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(user1);
        vm.expectRevert();
        nft.batchUpgrade(tokenIds);
    }

    function testCanUpgrade() public {
        uint256 tokenId = _mintFor(user1);

        (bool canUpgradeInitial, NinjaLabsNFT.TierLevel tierInitial) = nft.canUpgrade(tokenId);
        assertFalse(canUpgradeInitial);
        assertEq(uint256(tierInitial), uint256(NinjaLabsNFT.TierLevel.WHITE));

        vm.prank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD);

        (bool canUpgradeAfter, NinjaLabsNFT.TierLevel tierAfter) = nft.canUpgrade(tokenId);
        assertTrue(canUpgradeAfter);
        assertEq(uint256(tierAfter), uint256(NinjaLabsNFT.TierLevel.PURPLE));
    }

    // ============ Query Tests ============

    function testGetUserStatsIncludesProgress() public {
        nft.adminMint(user1, IMAGE_HASH_1);

        vm.prank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD + 50);

        NinjaLabsNFTView.UserStats memory stats = nftView.getUserStats(user1);
        assertEq(stats.totalOwned, 1);
        assertEq(stats.points, TIER1_THRESHOLD + 50);
        assertEq(uint256(stats.highestTier), uint256(NinjaLabsNFT.TierLevel.WHITE));
        assertEq(uint256(stats.eligibleTier), uint256(NinjaLabsNFT.TierLevel.PURPLE));
        assertEq(uint256(stats.nextTier), uint256(NinjaLabsNFT.TierLevel.ORANGE));
        assertEq(stats.nextTierThreshold, TIER2_THRESHOLD);
        assertEq(stats.pointsToNextTier, TIER2_THRESHOLD - (TIER1_THRESHOLD + 50));
    }

    function testGetTierProgress() public {
        vm.prank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD - 10);

        NinjaLabsNFTView.TierProgress memory progress = nftView.getTierProgress(user1);
        assertEq(uint256(progress.currentTier), uint256(NinjaLabsNFT.TierLevel.WHITE));
        assertEq(uint256(progress.nextTier), uint256(NinjaLabsNFT.TierLevel.PURPLE));
        assertEq(progress.currentPoints, TIER1_THRESHOLD - 10);
        assertEq(progress.nextTierThreshold, TIER1_THRESHOLD);
        assertEq(progress.pointsToNextTier, 10);
    }

    function testGetOwnedTokenSnapshotsReflectEligibility() public {
        uint256 tokenId = _mintFor(user1);

        vm.prank(oracle);
        nft.updatePoints(user1, TIER1_THRESHOLD);

        NinjaLabsNFTView.TokenSnapshot[] memory snapshots = nftView.getOwnedTokenSnapshots(user1);
        assertEq(snapshots.length, 1);
        assertEq(snapshots[0].tokenId, tokenId);
        assertTrue(snapshots[0].canUpgrade);
        assertEq(uint256(snapshots[0].eligibleTier), uint256(NinjaLabsNFT.TierLevel.PURPLE));
    }

    function testGetTierThresholds() public {
        (uint256 whiteUpper, uint256 purpleLower, uint256 purpleUpper, uint256 orangeLower) =
            nftView.getTierThresholds();
        assertEq(whiteUpper, TIER1_THRESHOLD - 1);
        assertEq(purpleLower, TIER1_THRESHOLD);
        assertEq(purpleUpper, TIER2_THRESHOLD - 1);
        assertEq(orangeLower, TIER2_THRESHOLD);
    }

    function testGetSupplyStatus() public {
        nft.adminMint(user1, IMAGE_HASH_1);

        (uint256 minted, uint256 cap, uint256 remaining) = nftView.getSupplyStatus();
        assertEq(minted, 1);
        assertEq(cap, MAX_SUPPLY);
        assertEq(remaining, MAX_SUPPLY - 1);
    }

    // ============ Treasury Tests ============

    function testWithdraw() public {
        vm.prank(user1);
        (bool success,) = address(nft).call{value: 2 ether}("");
        assertTrue(success);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(treasury, 2 ether, block.timestamp);

        vm.prank(treasury);
        nft.withdraw();

        assertEq(treasury.balance, treasuryBalanceBefore + 2 ether);
        assertEq(nft.getTreasuryBalance(), 0);
    }

    function testWithdrawRequiresTreasuryRole() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.withdraw();
    }

    function testReceiveFallback() public {
        vm.expectEmit(true, false, false, true);
        emit PaymentReceived(user1, 1 ether, block.timestamp);

        vm.prank(user1);
        (bool success,) = address(nft).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(nft.getTreasuryBalance(), 1 ether);
    }

    // ============ Configuration Tests ============

    function testSetTierThresholds() public {
        nft.setTierThresholds(200, 1000);

        assertEq(nft.tier1Threshold(), 200);
        assertEq(nft.tier2Threshold(), 1000);
    }

    function testSetTierThresholdsRevertsOnInvalidValues() public {
        vm.expectRevert(NinjaLabsNFT.InvalidThresholds.selector);
        nft.setTierThresholds(1000, 200);
    }

    function testSetMaxSupply() public {
        nft.setMaxSupply(300);
        assertEq(nft.maxSupply(), 300);
    }

    function testSetMaxSupplyRejectsDecrease() public {
        vm.expectRevert(NinjaLabsNFT.InvalidMaxSupply.selector);
        nft.setMaxSupply(MAX_SUPPLY - 1);
    }

    function testSetMaxSupplyRevertsIfLessThanMinted() public {
        nft.adminMint(user1, IMAGE_HASH_1);

        vm.expectRevert(NinjaLabsNFT.InvalidMaxSupply.selector);
        nft.setMaxSupply(0);
    }

    function testSetBaseURI() public {
        string memory newURI = "ipfs://newHash/";
        nft.setBaseURI(newURI);
        // baseURI is internal, validate via token URI composition
        nft.setMintActive(true);
        vm.prank(user1);
        nft.mint(IMAGE_HASH_1);
        assertEq(nft.tokenURI(1), string(abi.encodePacked(newURI, "1")));
    }

    function testSetMintActive() public {
        nft.setMintActive(true);
        assertTrue(nft.mintActive());
    }

    function testSetMaxPerWallet() public {
        nft.setMaxPerWallet(3);
        assertEq(nft.maxPerWallet(), 3);
    }

    function testPauseAndUnpause() public {
        nft.pause();
        assertTrue(nft.paused());

        nft.unpause();
        assertFalse(nft.paused());
    }
}
