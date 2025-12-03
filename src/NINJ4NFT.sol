// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title NINJ4NFT
/// @notice 500-supply collection with optional per-token CID mapping
contract NINJ4NFT is ERC721, ERC2981, Ownable {
    using Strings for uint256;

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

    /// @dev Tracks whether an address has already minted
    mapping(address => bool) public hasMinted;

    /// @dev Optional per-token IPFS CID override (when set, tokenURI uses ipfs://<cid>)
    mapping(uint256 => string) private _tokenCID;

    /// Events
    event Minted(address indexed minter, uint256 indexed tokenId);

    /// Errors
    error MaxSupplyReached();
    error InsufficientNativeBalance();
    error AlreadyMinted();
    error InvalidMaxSupply();
    error InvalidToken();
    error LengthMismatch();

    /// @param initialMaxSupply Maximum mintable supply for the drop
    /// @param baseTokenURI_ Initial base metadata URI (can be blank when using per-token CID)
    constructor(uint256 initialMaxSupply, string memory baseTokenURI_) ERC721("NINJ4", "NINJ4") Ownable(msg.sender) {
        if (initialMaxSupply == 0) revert InvalidMaxSupply();
        maxSupply = initialMaxSupply;
        _baseTokenURI = baseTokenURI_;

        // Default 5% secondary-market royalty to the deployer (owner)
        _setDefaultRoyalty(msg.sender, 500); // 500 = 5% using feeDenominator 10000
    }

    /// @notice Mint exactly one NFT if wallet holds more than 1 INJ
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

    /// @notice Owner airdrop to multiple recipients
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
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /// @notice Set a single token's CID (stored without ipfs:// prefix)
    function setTokenCID(uint256 tokenId, string calldata cid) external onlyOwner {
        if (tokenId == 0 || tokenId > maxSupply) revert InvalidToken();
        _tokenCID[tokenId] = cid;
    }

    /// @notice Batch set token CIDs
    function setTokenCIDs(uint256[] calldata tokenIds, string[] calldata cids) external onlyOwner {
        uint256 len = tokenIds.length;
        if (len != cids.length) revert LengthMismatch();
        for (uint256 i = 0; i < len; i++) {
            if (tokenIds[i] == 0 || tokenIds[i] > maxSupply) revert InvalidToken();
            _tokenCID[tokenIds[i]] = cids[i];
        }
    }

    /// @notice Update default royalty receiver and fee (basis points, max 10000)
    function setRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /// @notice Clear all default royalties
    function clearRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    /// @notice Returns how many tokens have been minted so far
    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    /// @inheritdoc ERC721
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @inheritdoc ERC721
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert InvalidToken();

        string memory cid = _tokenCID[tokenId];
        if (bytes(cid).length != 0) {
            return string.concat("ipfs://", cid);
        }

        string memory base = _baseURI();
        return bytes(base).length != 0 ? string.concat(base, tokenId.toString(), ".json") : "";
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
