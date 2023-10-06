pragma solidity ^0.8.17;
interface IxenNFTContract {
    function ownedTokens() external view returns (uint256[] memory);

    function isNFTRegistered(uint256 tokenId) external view returns (bool);
}