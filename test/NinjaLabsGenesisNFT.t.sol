// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/NINJ4NFT.sol";

contract NINJ4NFTTest is Test {
    NINJ4NFT internal genesis;

    address internal minter = address(0xA11CE);
    address internal other = address(0xB0B);

    string internal constant BASE_URI = "ipfs://genesis/";
    uint256 internal constant MAX_SUPPLY = 2;

    function setUp() public {
        genesis = new NINJ4NFT(MAX_SUPPLY, BASE_URI);
    }

    function testConstructorRejectsZeroSupply() public {
        vm.expectRevert(NINJ4NFT.InvalidMaxSupply.selector);
        new NINJ4NFT(0, BASE_URI);
    }

    function testMintRequiresBalanceGreaterThanOneInj() public {
        vm.deal(minter, 1 ether);

        vm.prank(minter);
        vm.expectRevert(NINJ4NFT.InsufficientNativeBalance.selector);
        genesis.mint();
    }

    function testMintSucceeds() public {
        vm.deal(minter, 2 ether);

        vm.prank(minter);
        genesis.mint();

        assertEq(genesis.balanceOf(minter), 1);
        assertEq(genesis.totalMinted(), 1);
        assertTrue(genesis.hasMinted(minter));
        assertEq(genesis.ownerOf(1), minter);
    }

    function testMintRevertsWhenAlreadyMinted() public {
        vm.deal(minter, 2 ether);

        vm.startPrank(minter);
        genesis.mint();
        vm.expectRevert(NINJ4NFT.AlreadyMinted.selector);
        genesis.mint();
        vm.stopPrank();
    }

    function testMintStopsAtMaxSupply() public {
        vm.deal(minter, 2 ether);
        vm.deal(other, 2 ether);

        vm.prank(minter);
        genesis.mint();

        vm.prank(other);
        genesis.mint();

        address extra = address(0xC0FFEE);
        vm.deal(extra, 2 ether);
        vm.prank(extra);
        vm.expectRevert(NINJ4NFT.MaxSupplyReached.selector);
        genesis.mint();
    }

    function testAirdropMintsToRecipients() public {
        address[] memory recipients = new address[](2);
        recipients[0] = minter;
        recipients[1] = other;

        genesis.airdrop(recipients);

        assertEq(genesis.balanceOf(minter), 1);
        assertEq(genesis.balanceOf(other), 1);
        assertEq(genesis.totalMinted(), 2);
        assertTrue(genesis.hasMinted(minter));
        assertTrue(genesis.hasMinted(other));
    }

    function testAirdropSkipsZeroAndAlreadyMintedAddresses() public {
        address[] memory firstRecipients = new address[](1);
        firstRecipients[0] = minter;
        genesis.airdrop(firstRecipients);

        address[] memory recipients = new address[](3);
        recipients[0] = address(0);
        recipients[1] = minter;
        recipients[2] = other;

        genesis.airdrop(recipients);

        assertEq(genesis.balanceOf(minter), 1);
        assertEq(genesis.balanceOf(other), 1);
        assertEq(genesis.totalMinted(), 2);
    }

    function testAirdropRespectsSupplyCap() public {
        address[] memory recipients = new address[](3);
        recipients[0] = minter;
        recipients[1] = other;
        recipients[2] = address(0xC0FFEE);

        vm.expectRevert(NINJ4NFT.MaxSupplyReached.selector);
        genesis.airdrop(recipients);
    }

    function testSetBaseUriUpdatesTokenUri() public {
        vm.deal(minter, 2 ether);
        vm.prank(minter);
        genesis.mint();

        genesis.setBaseURI("ipfs://updated/");

        assertEq(genesis.tokenURI(1), "ipfs://updated/1.json");
    }

    function testDefaultRoyaltyIsFivePercent() public {
        (address receiver, uint256 royaltyAmount) = genesis.royaltyInfo(1, 1 ether);
        assertEq(receiver, address(this));
        assertEq(royaltyAmount, 0.05 ether);
    }

    function testOwnerCanUpdateRoyalty() public {
        genesis.setRoyalty(other, 750); // 7.5%
        (address receiver, uint256 amount) = genesis.royaltyInfo(1, 2 ether);
        assertEq(receiver, other);
        assertEq(amount, 0.15 ether);
    }

    function testSupportsERC2981Interface() public {
        assertTrue(genesis.supportsInterface(0x2a55205a));
    }
}
