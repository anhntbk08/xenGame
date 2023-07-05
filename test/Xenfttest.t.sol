// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NFTRegistry.sol";

interface IxenNFTContract {
    function ownedTokens() external view returns (uint256[] memory);
    function isNFTRegistered(uint256 tokenId) external view returns (bool);
}

contract NFTRegistryTest is Test {
    NFTRegistry public nftRegistry;
    IxenNFTContract public nftContract; // Updated the contract type here
    address public nftContractAddress = 0x0a252663DBCc0b073063D6420a40319e438Cfa59;

    function setUp() public {
        nftContract = IxenNFTContract(nftContractAddress);
        nftRegistry = new NFTRegistry(nftContractAddress);
    }

    function testOwnedTokens() public {
        vm.startPrank(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e);
        console.log("msg.sender", msg.sender);
        try nftContract.ownedTokens() returns (uint256[] memory tokens) {
            console.log("Number of owned tokens:", tokens.length);
            for (uint256 i = 0; i < tokens.length; i++) {
                console.log("Token ID:", tokens[i]);
            }
        } catch Error(string memory reason) {
            console.log("Error encountered:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error");
        }
        vm.stopPrank();
    }

    function testRegisterNFT() public {
        vm.startPrank(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e);

        try nftContract.ownedTokens() returns (uint256[] memory tokens) {
            console.log("Number of owned tokens:", tokens.length);
            for (uint256 i = 0; i < tokens.length; i++) {
                console.log("Token ID:", tokens[i]);
            }
        } catch Error(string memory reason) {
            console.log("Error encountered:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error");
        }

        //require(tokens.length > 0, "No tokens owned by this address.");

        uint256 tokenId = 2;
        nftRegistry.registerNFT(tokenId);

        assertTrue(nftRegistry.isNFTRegistered(tokenId), "NFT not registered.");

        vm.stopPrank();
    }

    function _testRegisterNFT(address _msgSender, uint256 _id) internal {
        vm.startPrank(_msgSender);

        try nftContract.ownedTokens() returns (uint256[] memory tokens) {
            console.log("Number of owned tokens:", tokens.length);
            for (uint256 i = 0; i < tokens.length; i++) {
                console.log("Token ID:", tokens[i]);
            }
        } catch Error(string memory reason) {
            console.log("Error encountered:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error");
        }

        //require(tokens.length > 0, "No tokens owned by this address.");

        uint256 tokenId = _id;
        nftRegistry.registerNFT(tokenId);

        assertTrue(nftRegistry.isNFTRegistered(tokenId), "NFT not registered.");

        vm.stopPrank();
    }

    function _testSendEthToContract(address sender, uint256 amount) internal {
        address sendAddress = sender;
        vm.deal(sender, amount); // sends ethereum to the address
        vm.prank(sendAddress);
        nftRegistry.addToPool{value: amount}();
        console.log("sent ethereum to contract", amount);
    }

    // regester 2 from the same user.
    function testRegester2NFTsOneUser() public {
        _testRegisterNFT(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 2);
        _testRegisterNFT(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 4);
    }

    function testRegesterManyNFTsManyUser() public {
        _testRegisterNFT(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 2);
        _testRegisterNFT(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c, 104);
        _testRegisterNFT(0x35EC38cea5e0dd6B945c78F4e787e962917AC7aF, 1002);
        _testRegisterNFT(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 4);
        _testRegisterNFT(0xBf04A1f170ce7C895A557155B6A6914e62921F07, 1012);
        _testRegisterNFT(0x8AA4bA3DaCf9b96b8a40ab1d4c9bF285dce79D97, 3012);
        _testRegisterNFT(0x0Ab5707841970B815A6FAFcD529c708DbcB069b4, 6015);
        _testRegisterNFT(0x546f565890B5649711ca07F803a9f489c9888888, 3021);
    }

    function testFailRegisterNFT() public {
        uint256 tokenId = 0; // Non-existing or invalid tokenId
        nftRegistry.registerNFT(tokenId);
    }

    function testWithdrawRewards() public {
        testRegesterManyNFTsManyUser();

        _testSendEthToContract(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 1 ether);

        vm.startPrank(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c);

        uint256 balanceBefore = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;
        console.log(address(this));
        nftRegistry.withdrawRewards();
        uint256 balanceAfter = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;
        assertGt(balanceAfter, balanceBefore, "Rewards not withdrawn.");

        vm.stopPrank();
    }

    function testFailWithdrawRewardsTwice() public {
        testRegesterManyNFTsManyUser();

        _testSendEthToContract(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 1 ether);

        vm.startPrank(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c);

        uint256 balanceBefore = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;
        console.log(address(this));
        nftRegistry.withdrawRewards();
        uint256 balanceAfter = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;
        assertGt(balanceAfter, balanceBefore, "Rewards not withdrawn.");
        nftRegistry.withdrawRewards();
        vm.stopPrank();
    }

    function testWithdrawRewardsNewEthNoNewUsers() public {
        testRegesterManyNFTsManyUser();

        _testSendEthToContract(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 1 ether);

        vm.startPrank(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c);

        uint256 balanceBefore = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;
        console.log(address(this));
        nftRegistry.withdrawRewards();
        uint256 balanceAfter = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;
        assertGt(balanceAfter, balanceBefore, "Rewards not withdrawn.");

        _testSendEthToContract(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 2 ether);

        vm.startPrank(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c);
        nftRegistry.withdrawRewards();

        vm.stopPrank();
    }

    function testValue() public {
        testRegesterManyNFTsManyUser();

        _testSendEthToContract(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 1 ether);

        vm.startPrank(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c);

        uint256 balanceBefore = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;
        console.log(address(this));
        nftRegistry.withdrawRewards();
        uint256 balanceAfter = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;

        assertGt(balanceAfter, balanceBefore, "Rewards not withdrawn.");

        _testSendEthToContract(0x92Be9dC410eeA096EdC28BA942B5c66322A2618e, 10 ether);
        vm.startPrank(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c);
        nftRegistry.withdrawRewards();

        uint256 balanceEnd = address(0x9B06aA2C42E0b382D58Fe792d2C055449c3Dc73c).balance;

        console.log("balance starting----------------------------------------------------", balanceBefore);
        console.log("balance after 1st withdraw", balanceAfter);
        console.log("balance after 2nd withdraw", balanceEnd);

        vm.stopPrank();
    }
}
