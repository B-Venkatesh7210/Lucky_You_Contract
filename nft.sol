pragma solidity ^0.8.3;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


 contract NFTs is ERC721URIStorage { 
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct LuckyYouNFTSource {
        address creator;

        string metadataUri;
    }
    mapping (uint256 => LuckyYouNFTSource) public idToLuckyYouNFTSource;

    mapping (uint256 => bool) public nftMinted;

    constructor () ERC721("LuckyYou","LkYU"){}

    function createToken(string memory metadataUri, uint256 giveawayId) public returns (uint) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, metadataUri);
        idToLuckyYouNFTSource[newItemId] = LuckyYouNFTSource( msg.sender, metadataUri);
        nftMinted[giveawayId] = true;
        return newItemId;
    }

    function tokenSource(uint256 _tokenId)
        public
        view
        returns (
            address creator,
            string memory metadataUri)
        {
          LuckyYouNFTSource memory luckyYouNFTSource = idToLuckyYouNFTSource[_tokenId];
          return (luckyYouNFTSource.creator, luckyYouNFTSource.metadataUri);
        }


    function getNftMinted (uint256 giveawayId) public view returns(bool){
        return nftMinted[giveawayId];
    }
}
