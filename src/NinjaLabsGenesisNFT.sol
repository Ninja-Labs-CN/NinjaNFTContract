// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title NinjaLabsGenesisNFT
/// @notice Genesis drop for Ninja Labs with a balance-gated free mint
/// @dev Allows one mint per wallet when it holds more than 1 INJ of native balance
contract NinjaLabsGenesisNFT is ERC721, Ownable {
    /// @notice Minimum native token balance required to mint (1 INJ expressed in wei)
    uint256 public constant MIN_REQUIRED_BALANCE = 1 ether;

    /// @notice Maximum number of tokens that can ever be minted
    uint256 public immutable maxSupply;

    /// @dev Tracks total mints
    uint256 private _totalMinted;

    /// @dev Tracks the next token identifier
    uint256 private _nextTokenId = 1;

    /// @dev Base URI for metadata
    string private _baseTokenURI;

    /// @dev Tracks whether an address has already minted its genesis token
    mapping(address => bool) public hasMinted;

    /// @notice Emitted whenever a wallet completes a successful mint
    event Minted(address indexed minter, uint256 indexed tokenId);

    /// @notice Reverts if the collection supply has already been reached
    error MaxSupplyReached();

    /// @notice Reverts if the caller does not hold enough native balance
    error InsufficientNativeBalance();

    /// @notice Reverts when attempting to mint more than once from the same wallet
    error AlreadyMinted();

    /// @notice Reverts if deployed with zero max supply
    error InvalidMaxSupply();

    /// @param initialMaxSupply Maximum mintable supply for the genesis drop
    /// @param baseTokenURI_ Initial base metadata URI
    constructor(uint256 initialMaxSupply, string memory baseTokenURI_)
        ERC721("Ninja Labs Genesis", "NINJAGEN")
        Ownable(msg.sender)
    {
        if (initialMaxSupply == 0) revert InvalidMaxSupply();
        maxSupply = initialMaxSupply;
        _baseTokenURI = baseTokenURI_;
    }

    /// @notice Mint exactly one genesis NFT if the wallet holds more than 1 INJ
    function mint() external {
        if (msg.sender.balance <= MIN_REQUIRED_BALANCE) revert InsufficientNativeBalance();
        if (hasMinted[msg.sender]) revert AlreadyMinted();
        if (_totalMinted >= maxSupply) revert MaxSupplyReached();

        uint256 tokenId = _nextTokenId++;
        _totalMinted++;
        hasMinted[msg.sender] = true;

        _safeMint(msg.sender, tokenId);
        emit Minted(msg.sender, tokenId);
    }

    /// @notice Owner-only airdrop to distribute tokens manually
    /// @param recipients Array of wallets to receive the mint
    function airdrop(address[] calldata recipients) external onlyOwner {
        uint256 count = recipients.length;
        if (count == 0) return;

        for (uint256 i = 0; i < count; i++) {
            address to = recipients[i];
            if (to == address(0) || hasMinted[to]) {
                continue;
            }
            if (_totalMinted >= maxSupply) revert MaxSupplyReached();

            uint256 tokenId = _nextTokenId++;
            _totalMinted++;
            hasMinted[to] = true;

            _safeMint(to, tokenId);
            emit Minted(to, tokenId);
        }
    }

    /// @notice Update the base metadata URI
    /// @param newBaseURI The new base URI to apply
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /// @notice Returns how many tokens have been minted so far
    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    /// @inheritdoc ERC721
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
