// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ShareSplitter {
    
    
    address payable public dev1;
    address payable public dev2;

    constructor(address payable _dev1, address payable _dev2) {
        dev1 = _dev1;
        dev2 = _dev2;
    }

    function deposit() external payable {
        
    }    
    
    function checkContractBalance() public view returns(uint256) {
        return address(this).balance;
    }

    function distributeFunds() external {
        uint256 balance = checkContractBalance();
        require(balance > 0, "No funds to distribute.");

        uint256 amount = balance / 2;
        (bool success1, ) = dev1.call{value: amount}("");
        require(success1, "Ether transfer to dev1 failed.");

        (bool success2, ) = dev2.call{value: amount}("");
        require(success2, "Ether transfer to dev2 failed.");
    }
}
