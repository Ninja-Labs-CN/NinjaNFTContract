// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title NinjaLabsNFT
/// @notice Dynamic NFT with tiered upgrade system for Ninja Labs community
/// @dev ERC721 with role-based access control, point tracking, and tier upgrades
contract NinjaLabsNFT is ERC721Enumerable, AccessControl, ReentrancyGuard, Pausable {
    // ============ Roles ============
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // ============ Enums ============
    enum TierLevel {
        WHITE, // Level 0: New members (0 points)
        PURPLE, // Level 1: Senior contributors (100+ points)
        ORANGE // Level 2: Top contributors (500+ points)

    }

    // ============ Structs ============
    struct NFTMetadata {
        TierLevel tier;
        uint256 mintDate;
        uint256 lastUpgradeDate;
        string imageHash;
    }

    // ============ State Variables ============

    // NFT Tracking
    uint256 private _nextTokenId = 1;
    uint256 private _totalMinted;
    uint256 public maxSupply;
    uint256 public maxPerWallet;

    // Tier Configuration
    mapping(uint256 => NFTMetadata) public tokenMetadata;
    uint256 public tier1Threshold; // Points for PURPLE tier
    uint256 public tier2Threshold; // Points for ORANGE tier

    // Point System
    mapping(address => uint256) public userPoints;

    // Minting Configuration
    bool public mintActive;

    // Metadata
    string private _baseTokenURI;

    // User tracking
    mapping(address => uint256) public mintedCount;

    // ============ Errors ============
    error MintClosed();
    error QuantityZero();
    error SupplyExceeded();
    error WalletLimitExceeded();
    error InvalidThresholds();
    error NotTokenOwner();
    error AlreadyMaxTier();
    error InsufficientPoints();
    error InvalidAddress();
    error InvalidTokenId();
    error ArrayLengthMismatch();
    error WithdrawalFailed();
    error InvalidMaxSupply();

    // ============ Events ============

    // Minting Events
    event NFTMinted(address indexed to, uint256 indexed tokenId, string imageHash, uint256 timestamp);
    event BatchMinted(address indexed to, uint256[] tokenIds, uint256 timestamp);

    // Upgrade Events
    event NFTUpgraded(uint256 indexed tokenId, TierLevel oldTier, TierLevel newTier, uint256 timestamp);
    event BatchUpgraded(uint256[] tokenIds, uint256 timestamp);

    // Point Events
    event PointsUpdated(address indexed user, uint256 oldPoints, uint256 newPoints, uint256 timestamp);
    event PointsBatchUpdated(address[] users, uint256 timestamp);

    // Configuration Events
    event TierThresholdsUpdated(uint256 tier1Threshold, uint256 tier2Threshold);
    event MaxSupplyUpdated(uint256 oldMax, uint256 newMax);
    event BaseURIUpdated(string newBaseURI);
    event MintStatusChanged(bool active);

    // Treasury Events
    event FundsWithdrawn(address indexed to, uint256 amount, uint256 timestamp);
    event PaymentReceived(address indexed from, uint256 amount, uint256 timestamp);

    // ============ Constructor ============

    /// @notice Initialize the Ninja Labs NFT contract
    constructor(
        uint256 initialMaxSupply,
        uint256 initialMaxPerWallet,
        string memory baseTokenURI,
        uint256 initialTier1Threshold,
        uint256 initialTier2Threshold
    ) ERC721("Ninja Labs NFT", "NINJA") {
        if (initialMaxSupply == 0) revert InvalidMaxSupply();
        if (initialMaxPerWallet == 0) revert WalletLimitExceeded();
        if (initialMaxPerWallet > initialMaxSupply) revert WalletLimitExceeded();
        if (initialTier1Threshold >= initialTier2Threshold) revert InvalidThresholds();

        maxSupply = initialMaxSupply;
        maxPerWallet = initialMaxPerWallet;
        _baseTokenURI = baseTokenURI;
        tier1Threshold = initialTier1Threshold;
        tier2Threshold = initialTier2Threshold;

        // Grant roles to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(TREASURY_ROLE, msg.sender);
    }

    // ============ Minting Functions ============

    /// @notice Mint a single NFT with payment
    function mint(string calldata imageHash) external nonReentrant whenNotPaused {
        if (!mintActive) revert MintClosed();
        if (_totalMinted >= maxSupply) revert SupplyExceeded();
        if (mintedCount[msg.sender] >= maxPerWallet) revert WalletLimitExceeded();

        uint256 tokenId = _nextTokenId++;
        _totalMinted++;
        mintedCount[msg.sender]++;

        _safeMint(msg.sender, tokenId);

        tokenMetadata[tokenId] =
            NFTMetadata({tier: TierLevel.WHITE, mintDate: block.timestamp, lastUpgradeDate: 0, imageHash: imageHash});

        emit NFTMinted(msg.sender, tokenId, imageHash, block.timestamp);
    }

    /// @notice Admin function to mint NFT without payment (for airdrops)
    function adminMint(address to, string calldata imageHash) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        if (_totalMinted >= maxSupply) revert SupplyExceeded();

        uint256 tokenId = _nextTokenId++;
        _totalMinted++;

        _safeMint(to, tokenId);

        tokenMetadata[tokenId] =
            NFTMetadata({tier: TierLevel.WHITE, mintDate: block.timestamp, lastUpgradeDate: 0, imageHash: imageHash});

        emit NFTMinted(to, tokenId, imageHash, block.timestamp);
    }

    /// @notice Batch mint multiple NFTs (admin only)
    function batchMint(address to, string[] calldata imageHashes) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        uint256 quantity = imageHashes.length;
        if (quantity == 0) revert QuantityZero();
        if (_totalMinted + quantity > maxSupply) revert SupplyExceeded();

        uint256[] memory tokenIds = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _nextTokenId++;
            _totalMinted++;

            _safeMint(to, tokenId);

            tokenMetadata[tokenId] = NFTMetadata({
                tier: TierLevel.WHITE,
                mintDate: block.timestamp,
                lastUpgradeDate: 0,
                imageHash: imageHashes[i]
            });

            tokenIds[i] = tokenId;
        }

        emit BatchMinted(to, tokenIds, block.timestamp);
    }

    // ============ Point Management (Oracle Role) ============

    /// @notice Update points for a single user (off-chain sync)
    function updatePoints(address user, uint256 newPoints) external onlyRole(ORACLE_ROLE) {
        if (user == address(0)) revert InvalidAddress();

        uint256 oldPoints = userPoints[user];
        userPoints[user] = newPoints;

        emit PointsUpdated(user, oldPoints, newPoints, block.timestamp);
    }

    /// @notice Batch update points for multiple users
    function batchUpdatePoints(address[] calldata users, uint256[] calldata points) external onlyRole(ORACLE_ROLE) {
        if (users.length != points.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == address(0)) revert InvalidAddress();

            uint256 oldPoints = userPoints[users[i]];
            userPoints[users[i]] = points[i];

            emit PointsUpdated(users[i], oldPoints, points[i], block.timestamp);
        }

        emit PointsBatchUpdated(users, block.timestamp);
    }

    // ============ Upgrade Functions ============

    /// @notice Upgrade NFT tier based on owner's points
    function upgradeNFT(uint256 tokenId) external nonReentrant whenNotPaused {
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner();

        NFTMetadata storage metadata = tokenMetadata[tokenId];
        TierLevel currentTier = metadata.tier;

        if (currentTier == TierLevel.ORANGE) revert AlreadyMaxTier();

        uint256 points = userPoints[msg.sender];
        TierLevel newTier = _calculateTier(points);

        if (newTier <= currentTier) revert InsufficientPoints();

        metadata.tier = newTier;
        metadata.lastUpgradeDate = block.timestamp;

        emit NFTUpgraded(tokenId, currentTier, newTier, block.timestamp);
    }

    /// @notice Admin batch upgrade for multiple tokens
    function batchUpgrade(uint256[] calldata tokenIds) external onlyRole(UPGRADER_ROLE) nonReentrant {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (!_exists(tokenId)) revert InvalidTokenId();

            NFTMetadata storage metadata = tokenMetadata[tokenId];
            TierLevel currentTier = metadata.tier;

            if (currentTier == TierLevel.ORANGE) continue;

            address owner = ownerOf(tokenId);
            uint256 points = userPoints[owner];
            TierLevel newTier = _calculateTier(points);

            if (newTier > currentTier) {
                metadata.tier = newTier;
                metadata.lastUpgradeDate = block.timestamp;

                emit NFTUpgraded(tokenId, currentTier, newTier, block.timestamp);
            }
        }

        emit BatchUpgraded(tokenIds, block.timestamp);
    }

    /// @notice Check if a token can be upgraded
    function canUpgrade(uint256 tokenId) external view returns (bool, TierLevel) {
        if (!_exists(tokenId)) revert InvalidTokenId();

        NFTMetadata memory metadata = tokenMetadata[tokenId];
        TierLevel currentTier = metadata.tier;

        if (currentTier == TierLevel.ORANGE) {
            return (false, TierLevel.ORANGE);
        }

        address owner = ownerOf(tokenId);
        uint256 points = userPoints[owner];
        TierLevel eligibleTier = _calculateTier(points);

        return (eligibleTier > currentTier, eligibleTier);
    }

    // ============ Treasury Management ============

    /// @notice Withdraw contract balance
    function withdraw() external onlyRole(TREASURY_ROLE) nonReentrant {
        uint256 balance = address(this).balance;

        (bool success,) = payable(msg.sender).call{value: balance}("");
        if (!success) revert WithdrawalFailed();

        emit FundsWithdrawn(msg.sender, balance, block.timestamp);
    }

    /// @notice Get current treasury balance
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ============ Configuration Functions (Admin) ============

    /// @notice Set tier thresholds for upgrades
    function setTierThresholds(uint256 newTier1Threshold, uint256 newTier2Threshold)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newTier1Threshold >= newTier2Threshold) revert InvalidThresholds();

        tier1Threshold = newTier1Threshold;
        tier2Threshold = newTier2Threshold;

        emit TierThresholdsUpdated(newTier1Threshold, newTier2Threshold);
    }

    /// @notice Update max supply (can only increase)
    function setMaxSupply(uint256 newMax) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMax < _totalMinted || newMax < maxSupply) revert InvalidMaxSupply();

        uint256 oldMax = maxSupply;
        maxSupply = newMax;

        emit MaxSupplyUpdated(oldMax, newMax);
    }

    /// @notice Update base URI for metadata
    function setBaseURI(string calldata newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /// @notice Toggle mint status
    function setMintActive(bool active) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintActive = active;
        emit MintStatusChanged(active);
    }

    /// @notice Update max per wallet
    function setMaxPerWallet(uint256 newMax) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMax == 0) revert WalletLimitExceeded();
        maxPerWallet = newMax;
    }

    /// @notice Pause contract
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ============ Query Functions ============

    /// @notice Get user's current points
    function getUserPoints(address user) external view returns (uint256) {
        return userPoints[user];
    }

    /// @notice Get user's eligible tier based on points
    function getEligibleTier(address user) external view returns (TierLevel) {
        return _calculateTier(userPoints[user]);
    }

    /// @notice Get NFT metadata
    function getNFTMetadata(uint256 tokenId) external view returns (NFTMetadata memory) {
        if (!_exists(tokenId)) revert InvalidTokenId();
        return tokenMetadata[tokenId];
    }

    /// @notice Get tier name
    function getTierName(TierLevel tier) public pure returns (string memory) {
        if (tier == TierLevel.WHITE) return "WHITE";
        if (tier == TierLevel.PURPLE) return "PURPLE";
        return "ORANGE";
    }

    /// @notice Get total minted count
    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    // ============ Internal Functions ============

    /// @notice Calculate tier based on points
    function _calculateTier(uint256 points) internal view returns (TierLevel) {
        if (points >= tier2Threshold) {
            return TierLevel.ORANGE;
        } else if (points >= tier1Threshold) {
            return TierLevel.PURPLE;
        }
        return TierLevel.WHITE;
    }

    /// @notice Override base URI
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Check if token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId < _nextTokenId && _ownerOf(tokenId) != address(0);
    }

    // ============ Interface Support ============

    /// @notice Check interface support
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ============ Fallback ============

    /// @notice Receive ETH
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value, block.timestamp);
    }
}
