// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/NinjaLabsGenesisNFT.sol";

contract NinjaLabsGenesisNFTTest is Test {
    NinjaLabsGenesisNFT internal genesis;

    address internal minter = address(0xA11CE);
    address internal other = address(0xB0B);

    string internal constant BASE_URI = "ipfs://genesis/";
    uint256 internal constant MAX_SUPPLY = 2;

    function setUp() public {
        genesis = new NinjaLabsGenesisNFT(MAX_SUPPLY, BASE_URI);
    }

    function testConstructorRejectsZeroSupply() public {
        vm.expectRevert(NinjaLabsGenesisNFT.InvalidMaxSupply.selector);
        new NinjaLabsGenesisNFT(0, BASE_URI);
    }

    function testMintRequiresBalanceGreaterThanOneInj() public {
        vm.deal(minter, 1 ether);

        vm.prank(minter);
        vm.expectRevert(NinjaLabsGenesisNFT.InsufficientNativeBalance.selector);
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
        vm.expectRevert(NinjaLabsGenesisNFT.AlreadyMinted.selector);
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
        vm.expectRevert(NinjaLabsGenesisNFT.MaxSupplyReached.selector);
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

        vm.expectRevert(NinjaLabsGenesisNFT.MaxSupplyReached.selector);
        genesis.airdrop(recipients);
    }

    function testSetBaseUriUpdatesTokenUri() public {
        vm.deal(minter, 2 ether);
        vm.prank(minter);
        genesis.mint();

        genesis.setBaseURI("ipfs://updated/");

        assertEq(genesis.tokenURI(1), "ipfs://updated/1");
    }
}
