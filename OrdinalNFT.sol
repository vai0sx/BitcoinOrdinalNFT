// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./OrdinalNFT.sol";

contract BitcoinOrdinalNFTMarketplace is ReentrancyGuard {
    using SafeMath for uint256;

    address public admin;
    IERC20 public bitcoinToken;
    uint256 public feePercentage = 2;

    struct Offer {
        bool isForSale;
        uint256 tokenId;
        address seller;
        uint256 price;
    }

    mapping(uint256 => Offer) public tokenIdToOffer;

    event OfferCreated(uint256 indexed tokenId, uint256 price, address indexed seller);
    event OfferCancelled(uint256 indexed tokenId);
    event NFTSold(uint256 indexed tokenId, uint256 price, address indexed seller, address indexed buyer);

    constructor(address _bitcoinToken) {
        admin = msg.sender;
        bitcoinToken = IERC20(_bitcoinToken);
    }

    function createOffer(address nftAddress, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        OrdinalNFT nft = OrdinalNFT(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "You must own the NFT to create an offer");

        nft.transferFrom(msg.sender, address(this), tokenId);

        tokenIdToOffer[tokenId] = Offer(true, tokenId, msg.sender, price);

        emit OfferCreated(tokenId, price, msg.sender);
    }

    function cancelOffer(address nftAddress, uint256 tokenId) external {
        require(tokenIdToOffer[tokenId].isForSale, "Offer does not exist");
        require(tokenIdToOffer[tokenId].seller == msg.sender, "Only the seller can cancel the offer");

        OrdinalNFT nft = OrdinalNFT(nftAddress);
        nft.transferFrom(address(this), msg.sender, tokenId);

        tokenIdToOffer[tokenId].isForSale = false;

        emit OfferCancelled(tokenId);
    }

    function buyNFT(address nftAddress, uint256 tokenId) external nonReentrant {
        Offer memory offer = tokenIdToOffer[tokenId];
        require(offer.isForSale, "Offer does not exist");

        OrdinalNFT nft = OrdinalNFT(nftAddress);

        uint256 fee = offer.price.mul(feePercentage).div(100);
        uint256 sellerProceeds = offer.price.sub(fee);

        bitcoinToken.transferFrom(msg.sender, admin, fee);
        bitcoinToken.transferFrom(msg.sender, offer.seller, sellerProceeds);
        nft.transferFrom(address(this), msg.sender, tokenId);

        tokenIdToOffer[tokenId].isForSale = false;

        emit NFTSold(tokenId, offer.price, offer.seller, msg.sender);
    }

