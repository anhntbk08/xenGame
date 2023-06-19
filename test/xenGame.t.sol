// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/NFTRegistry.sol";
import "../src/xenBurn.sol";
import "../src/xenPriceOracle.sol";
import "../src/dev.sol";
import "../src/XenGame.sol";

interface IxenNFTContract {
    function ownedTokens() external view returns (uint256[] memory);
    function isNFTRegistered(uint256 tokenId) external view returns (bool);
    
}


contract XenGameTest is Test {
    xenBurn public XenBurnInstance;
    PriceOracle public priceOracleInstance;
    address public xenCrypto = 0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8; 
    NFTRegistry public nftRegistry;
    IxenNFTContract public nftContract; 
    address public nftContractAddress = 0x0a252663DBCc0b073063D6420a40319e438Cfa59;
    uint public initialBalance = 1 ether;
    XenGame public xenGameInstance;

    function setUp() public {
        priceOracleInstance = new PriceOracle();
        XenBurnInstance = new xenBurn(address(priceOracleInstance), xenCrypto);
        nftRegistry = new NFTRegistry(nftContractAddress);
        xenGameInstance = new XenGame(nftContractAddress, address(nftRegistry), address(XenBurnInstance));

        console.log("setup ran");
    }

    function testBuyWithReferral() public {
        uint initialETHAmount = 1.234 ether;
        uint numberOfKeys = 28;
        uint roundId = 1;
        
        try vm.deal(msg.sender, initialETHAmount) {
        } catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on deal");
        }

        _testGetRoundStats();
        
        uint EarlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        console.log("early key buying time", EarlyKeyBuyinTime);

        vm.warp(EarlyKeyBuyinTime);

        console.log("------Time Updated ------", block.timestamp);
        

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();

        vm.warp(EarlyKeyBuyinTime + 500); 
        console.log("------Time Updated ------", block.timestamp);

        vm.deal(address(1), initialETHAmount);
        vm.prank(address(1));

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();


        uint keysPurchased = xenGameInstance.getPlayerKeysCount(address(1), roundId);
        console.log("keys Purchased ", keysPurchased, "for address", address(1));
            assertTrue(keysPurchased > 0, "No keys were purchased.");

        //_testGetRoundStats();
        
    }

    function testIsRoundActive() public {
        bool roundStatus = xenGameInstance.isRoundActive() ;
            assertTrue(roundStatus, "Round should be active.");
       
    }

    function testFailIsRoundEndedatStart() public {
        bool roundStatus = xenGameInstance.isRoundEnded() ;
            assertFalse(roundStatus, "Round should not be ended.");
        
    }

    function testGetRoundStats() public view {
        uint roundId = 1;  // The round ID to test

        try xenGameInstance.getRoundStats(roundId) returns (
            uint totalKeys, 
            uint totalFunds, 
            uint start, 
            uint end, 
            address activePlayer, 
            bool ended, 
            bool isEarlyBuyin,
            uint keysFunds,
            uint jackpot,
            uint earlyBuyinEth,
            uint lastKeyPrice,
            uint rewardRatio
        ) {
            console.log("Total keys: ", totalKeys);
            console.log("Total funds: ", totalFunds);
            console.log("Current time", block.timestamp);
            console.log("Start: ", start);
            console.log("End: ", end);
            console.log("Active player: ", activePlayer);
            console.log("Ended: ", ended);
            console.log("Is early buyin: ", isEarlyBuyin);
            console.log("Keys funds: ", keysFunds);
            console.log("Jackpot: ", jackpot);
            console.log("Early buyin Eth: ", earlyBuyinEth);
            console.log("Last key price: ", lastKeyPrice);
            console.log("Reward ratio: ", rewardRatio);
        } catch Error(string memory reason) {
            console.log("Error on getRoundStats:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on getRoundStats");
        }
    }

    function _testGetRoundStats() internal view {
        uint roundId = 1;  // The round ID to test

        try xenGameInstance.getRoundStats(roundId) returns (
            uint totalKeys, 
            uint totalFunds, 
            uint start, 
            uint end, 
            address activePlayer, 
            bool ended, 
            bool isEarlyBuyin,
            uint keysFunds,
            uint jackpot,
            uint earlyBuyinEth,
            uint lastKeyPrice,
            uint rewardRatio
        ) {
            console.log("----------------------------------- STATS REPORT -------------------------------------");
            console.log("Total keys: ", totalKeys);
            console.log("Total funds: ", totalFunds);
            console.log("Start: ", start);
            console.log("End: ", end);
            console.log("Active player: ", activePlayer);
            console.log("Ended: ", ended);
            console.log("Is early buyin: ", isEarlyBuyin);
            console.log("Keys funds: ", keysFunds);
            console.log("Jackpot: ", jackpot);
            console.log("Early buyin Eth: ", earlyBuyinEth);
            console.log("Last key price: ", lastKeyPrice);
            console.log("Reward ratio: ", rewardRatio);
            console.log("");
        } catch Error(string memory reason) {
            console.log("Error on getRoundStats:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on getRoundStats");
        }
    }

    function _testGetPlayerInfo(address playerAddress, uint roundNumber) internal view {
        (
            uint keyCount,
            uint earlyBuyinPoints,
            uint referralRewards,
            
            uint lastWithdrawalPoolAmount,
            uint lastRewardRatio
        ) = xenGameInstance.getPlayerInfo(playerAddress, roundNumber);

        console.log("----------------------------------- PLAYER INFO -------------------------------------");
        console.log("Player Address: ", playerAddress);
        console.log("Round Number: ", roundNumber);
        console.log("FORMATTED Key Count: ", keyCount / 1 ether );
        console.log("Early Buyin Points: ", earlyBuyinPoints);
        console.log("Referral Rewards: ", referralRewards);
        
        console.log("Last Withdrawal Pool Amount: ", lastWithdrawalPoolAmount);
        console.log("Last Reward Ratio: ", lastRewardRatio);
        console.log("");
    }



    function testFailBuyWithReferralOnRoundGap() public {
        uint initialETHAmount = .1 ether;
        uint numberOfKeys = 10;
        
        try vm.deal(msg.sender, initialETHAmount) {
        } catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on deal");
        }

        _testGetRoundStats();

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        uint keysPurchased = xenGameInstance.getPlayerKeysCount(msg.sender, 1);
            assertTrue(keysPurchased > 0, "No keys were purchased.");
        
    }

    function testBuyEarlyBuyinPoolNoReferral() public {
        uint initialETHAmount = .1 ether;
        uint numberOfKeys = 10;
        uint roundId = 1;
        
        try vm.deal(msg.sender, initialETHAmount) {
        } catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on deal");
        }

        _testGetRoundStats();
        
        uint EarlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        console.log("early key buying time", EarlyKeyBuyinTime);

        vm.warp(EarlyKeyBuyinTime);

        console.log("------Time Updated ------", block.timestamp);
        

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();

        uint earlyBuyEth = xenGameInstance.getRoundEarlyBuyin(roundId);
            assertTrue(earlyBuyEth == initialETHAmount, "No ETH in early buying pool.");

        console.log("early biyin eth pool amount: ", earlyBuyEth);
        
    }

    function testBuyKeyNormalGamePlayWithKeys() public {
        uint initialETHAmount = 1.234 ether;
        uint numberOfKeys = 28;
        uint roundId = 1;
        
        try vm.deal(msg.sender, initialETHAmount) {
        } catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on deal");
        }
                
        uint EarlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;       

        vm.warp(EarlyKeyBuyinTime);       
        

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();

        vm.warp(EarlyKeyBuyinTime + 500); 
        console.log("------Time Updated ------", block.timestamp);

        vm.deal(address(1), initialETHAmount);
        vm.prank(address(1));

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();


        uint keysPurchased = xenGameInstance.getPlayerKeysCount(address(1), roundId);
        console.log("keys Purchased ", keysPurchased, "for address", address(1));
            assertTrue(keysPurchased > 0, "No keys were purchased.");

        //_testGetRoundStats();
        
    }

    function testBuyKeyNormalGamePlayNOKeys() public {
        
        
        
        
        try vm.deal(address(2), 5 ether) {
        } catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on deal");
        }

        //_testGetRoundStats();
        
        uint EarlyKeyBuyinTime = xenGameInstance.getRoundStart(1) + 1;
        console.log("early key buying time", EarlyKeyBuyinTime);

        vm.warp(EarlyKeyBuyinTime);

        console.log("------Time Updated ------", block.timestamp);
        
        vm.prank(address(2));
        try xenGameInstance.buyWithReferral{value: 5 ether}("", 28) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        //_testGetRoundStats();

        vm.warp(EarlyKeyBuyinTime + 500); 
        console.log("------Time Updated ------", block.timestamp);

        vm.deal(address(1), 5 ether);
        vm.prank(address(1));

        try xenGameInstance.buyWithReferral{value: 1 ether}("", 0) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        //_testGetRoundStats();


        uint keysPurchased = xenGameInstance.getPlayerKeysCount(address(1), 1);
        console.log("keys Purchased formatted:", keysPurchased / 1 ether, "for address", address(1));
            assertTrue(keysPurchased > 0, "No keys were purchased.");

        _testGetRoundStats();
        _testGetPlayerInfo(address(1),1);
        _testGetPlayerInfo(address(2),1);

        
    }

    function testWithdrawPlayerKeyRewards() public {
        
        
        
        
        try vm.deal(address(2), 5 ether) {
        } catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on deal");
        }

        //_testGetRoundStats();
        
        uint EarlyKeyBuyinTime = xenGameInstance.getRoundStart(1) + 1;
        console.log("early key buying time", EarlyKeyBuyinTime);

        vm.warp(EarlyKeyBuyinTime);

        console.log("------Time Updated ------", block.timestamp);
        
        vm.prank(address(2));
        try xenGameInstance.buyWithReferral{value: 5 ether}("", 28) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        //_testGetRoundStats();

        vm.warp(EarlyKeyBuyinTime + 500); 
        console.log("------Time Updated ------", block.timestamp);

        vm.deal(address(1), 5 ether);
        vm.prank(address(1));

        try xenGameInstance.buyWithReferral{value: 1 ether}("", 0) {
        } catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on buyWithReferral");
        }

        //_testGetRoundStats();


        uint keysPurchased = xenGameInstance.getPlayerKeysCount(address(1), 1);
        console.log("keys Purchased formatted:", keysPurchased / 1 ether, "for address", address(1));
            assertTrue(keysPurchased > 0, "No keys were purchased.");

        _testGetRoundStats();
        _testGetPlayerInfo(address(1),1);
        _testGetPlayerInfo(address(2),1);

        vm.startPrank(address(2));

        console.log("balance of address 2 starting", address(2).balance);

        try xenGameInstance.withdrawRewards(1) {
        } catch Error(string memory reason) {
            console.log("Error on withdraw rewards:", reason);
        } catch (bytes memory /*lowLevelData*/) {
            console.log("Low level error on withdraw rewards");
        }

        console.log("balance of address 2 ending", address(2).balance);

        _testGetPlayerInfo(address(2),1);
        _testGetRoundStats();
        
    }



}


