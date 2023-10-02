pragma solidity 0.8.17;

contract NFTContract {
    function ownerOf(uint256) external view returns (address){
        return msg.sender;
    }
}