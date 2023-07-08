// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/NFTRegistry.sol";
import "../src/xenBurn.sol";
import "../src/xenPriceOracle.sol";
import "../src/PlayerNameRegistry.sol";
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
    uint256 public initialBalance = 1 ether;
    XenGame public xenGameInstance;
    PlayerNameRegistry public playerNameRegistry;

    function setUp() public {
        priceOracleInstance = new PriceOracle();

        playerNameRegistry = new PlayerNameRegistry(payable(address(4)), payable(address(5)));
        nftRegistry = new NFTRegistry(nftContractAddress);
        XenBurnInstance = new xenBurn(address(priceOracleInstance), xenCrypto, address(playerNameRegistry));
        xenGameInstance =
            new XenGame(nftContractAddress, address(nftRegistry), address(XenBurnInstance), address(playerNameRegistry));

        console.log("setup ran");
    }

    function testBuyWithReferral() public {
        uint256 initialETHAmount = 1.234 ether;
        uint256 numberOfKeys = 28;
        uint256 roundId = 1;

        try vm.deal(msg.sender, initialETHAmount) {}
        catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on deal");
        }

        _testGetRoundStats();

        uint256 EarlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        console.log("early key buying time", EarlyKeyBuyinTime);

        vm.warp(EarlyKeyBuyinTime);

        console.log("------Time Updated ------", block.timestamp);

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();

        vm.warp(EarlyKeyBuyinTime + 500);
        console.log("------Time Updated ------", block.timestamp);

        vm.deal(address(1), initialETHAmount);
        vm.prank(address(1));

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();

        uint256 keysPurchased = xenGameInstance.getPlayerKeysCount(address(1), roundId);
        console.log("keys Purchased ", keysPurchased, "for address", address(1));
        assertTrue(keysPurchased > 0, "No keys were purchased.");

        //_testGetRoundStats();
    }

    function testIsRoundActive() public {
        testBuyWithReferral();
        bool roundStatus = xenGameInstance.isRoundActive();
        assertTrue(roundStatus, "Round should be active.");
    }

    function testIsRoundIsNotEndedatStart() public {
        testBuyWithReferral();
        bool roundStatus = xenGameInstance.isRoundEnded();
        console.log("roundStatus :", roundStatus);
        assertFalse(roundStatus, "Round should not be ended.");
    }

    function testGetRoundStats() public view {
        uint256 roundId = 1; // The round ID to test

        try xenGameInstance.getRoundStats(roundId) returns (
            uint256 totalKeys,
            uint256 totalFunds,
            uint256 start,
            uint256 end,
            address activePlayer,
            bool ended,
            bool isEarlyBuyin,
            uint256 keysFunds,
            uint256 jackpot,
            uint256 earlyBuyinEth,
            uint256 lastKeyPrice,
            uint256 rewardRatio
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
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on getRoundStats");
        }
    }

    function _testGetRoundStats() internal view {
        uint256 roundId = 1; // The round ID to test

        try xenGameInstance.getRoundStats(roundId) returns (
            uint256 totalKeys,
            uint256 totalFunds,
            uint256 start,
            uint256 end,
            address activePlayer,
            bool ended,
            bool isEarlyBuyin,
            uint256 keysFunds,
            uint256 jackpot,
            uint256 earlyBuyinEth,
            uint256 lastKeyPrice,
            uint256 rewardRatio
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
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on getRoundStats");
        }
    }

    function _testGetPlayerInfo(address playerAddress, uint256 roundNumber) internal view {
        (
            uint256 keyCount, 
            uint256 earlyBuyinPoints, 
            uint256 referralRewards, 
            uint256 lastRewardRatio,
            uint256 keyRewards,
            uint256 numberOfReferrals
        ) = xenGameInstance.getPlayerInfo(playerAddress, roundNumber);

        console.log("----------------------------------- PLAYER INFO -------------------------------------");
        console.log("Player Address: ", playerAddress);
        console.log("Round Number: ", roundNumber);
        console.log("FORMATTED Key Count: ", keyCount / 1 ether);
        console.log("Early Buyin Points: ", earlyBuyinPoints);
        console.log("Referral Rewards: ", referralRewards);
        console.log("Last Reward Ratio: ", lastRewardRatio);
        console.log("Key Rewards: ", keyRewards);
        console.log("Number of Referrals: ", numberOfReferrals);
        console.log("");
    }


    function testFailBuyWithReferralOnRoundGap() public {
        uint256 initialETHAmount = 0.1 ether;
        uint256 numberOfKeys = 10;

        try vm.deal(msg.sender, initialETHAmount) {}
        catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on deal");
        }

        _testGetRoundStats();

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        uint256 keysPurchased = xenGameInstance.getPlayerKeysCount(msg.sender, 1);
        assertTrue(keysPurchased > 0, "No keys were purchased.");
    }

    function testBuyEarlyBuyinPoolNoReferral() public {
        uint256 initialETHAmount = 0.1 ether;
        uint256 numberOfKeys = 10;
        uint256 roundId = 1;

        try vm.deal(msg.sender, initialETHAmount) {}
        catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on deal");
        }

        _testGetRoundStats();

        uint256 EarlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        console.log("early key buying time", EarlyKeyBuyinTime);

        vm.warp(EarlyKeyBuyinTime);

        console.log("------Time Updated ------", block.timestamp);

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();

        uint256 earlyBuyEth = xenGameInstance.getRoundEarlyBuyin(roundId);
        assertTrue(earlyBuyEth == initialETHAmount, "No ETH in early buying pool.");

        console.log("early biyin eth pool amount: ", earlyBuyEth);
    }

    function testBuyKeyNormalGamePlayWithKeys() public {
        uint256 initialETHAmount = 1.234 ether;
        uint256 numberOfKeys = 28;
        uint256 roundId = 1;

        try vm.deal(msg.sender, initialETHAmount) {}
        catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on deal");
        }

        uint256 EarlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;

        vm.warp(EarlyKeyBuyinTime);

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();

        vm.warp(EarlyKeyBuyinTime + 500);
        console.log("------Time Updated ------", block.timestamp);

        vm.deal(address(1), initialETHAmount);
        vm.prank(address(1));

        try xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        _testGetRoundStats();

        uint256 keysPurchased = xenGameInstance.getPlayerKeysCount(address(1), roundId);
        console.log("keys Purchased ", keysPurchased, "for address", address(1));
        assertTrue(keysPurchased > 0, "No keys were purchased.");

        //_testGetRoundStats();
    }

    function testBuyKeyNormalGamePlayNOKeys() public {
        try vm.deal(address(2), 5 ether) {}
        catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on deal");
        }

        //_testGetRoundStats();

        uint256 EarlyKeyBuyinTime = xenGameInstance.getRoundStart(1) + 1;
        console.log("early key buying time", EarlyKeyBuyinTime);

        vm.warp(EarlyKeyBuyinTime);

        console.log("------Time Updated ------", block.timestamp);

        vm.prank(address(2));
        try xenGameInstance.buyWithReferral{value: 5 ether}("", 28) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        //_testGetRoundStats();

        vm.warp(EarlyKeyBuyinTime + 500);
        console.log("------Time Updated ------", block.timestamp);

        vm.deal(address(1), 5 ether);
        vm.prank(address(1));

        try xenGameInstance.buyWithReferral{value: 1 ether}("", 0) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        //_testGetRoundStats();

        uint256 keysPurchased = xenGameInstance.getPlayerKeysCount(address(1), 1);
        console.log("keys Purchased formatted:", keysPurchased / 1 ether, "for address", address(1));
        assertTrue(keysPurchased > 0, "No keys were purchased.");

        _testGetRoundStats();
        _testGetPlayerInfo(address(1), 1);
        _testGetPlayerInfo(address(2), 1);
    }

    function testWithdrawPlayerKeyRewards() public {
        try vm.deal(address(2), 5 ether) {}
        catch Error(string memory reason) {
            console.log("Error on deal:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on deal");
        }

        //_testGetRoundStats();

        uint256 EarlyKeyBuyinTime = xenGameInstance.getRoundStart(1) + 1;
        console.log("early key buying time", EarlyKeyBuyinTime);

        vm.warp(EarlyKeyBuyinTime);

        console.log("------Time Updated ------", block.timestamp);

        vm.prank(address(2));
        try xenGameInstance.buyWithReferral{value: 5 ether}("", 28) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        //_testGetRoundStats();

        vm.warp(EarlyKeyBuyinTime + 500);
        console.log("------Time Updated ------", block.timestamp);

        vm.deal(address(1), 5 ether);
        vm.prank(address(1));

        try xenGameInstance.buyWithReferral{value: 1 ether}("", 0) {}
        catch Error(string memory reason) {
            console.log("Error on buyWithReferral:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on buyWithReferral");
        }

        //_testGetRoundStats();

        uint256 keysPurchased = xenGameInstance.getPlayerKeysCount(address(1), 1);
        console.log("keys Purchased formatted:", keysPurchased / 1 ether, "for address", address(1));
        assertTrue(keysPurchased > 0, "No keys were purchased.");

        _testGetRoundStats();
        _testGetPlayerInfo(address(1), 1);
        _testGetPlayerInfo(address(2), 1);

        vm.startPrank(address(2));

        console.log("balance of address 2 starting", address(2).balance);

        try xenGameInstance.withdrawRewards(1) {}
        catch Error(string memory reason) {
            console.log("Error on withdraw rewards:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on withdraw rewards");
        }

        console.log("balance of address 2 ending", address(2).balance);

        _testGetPlayerInfo(address(2), 1);
        _testGetRoundStats();
    }

    
    function testPlayerNameRegistrationSuccess() public {
        uint256 NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei
        string memory name = "Alice";

        try playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(msg.sender, name) {
            string memory registeredName = playerNameRegistry.getPlayerFirstName(msg.sender);
            assertTrue(keccak256(bytes(registeredName)) == keccak256(bytes(name)), "Name was not registered correctly.");
        } catch Error(string memory reason) {
            fail(reason);
        } catch (bytes memory) /*lowLevelData*/ {
            fail("Low level error on registering name");
        }
    }

    function testPlayerNameRegistrationDuplicate() public {
        uint256 NAME_REGISTRATION_FEE = 20000000000000000000; // 0.02 Ether in Wei
        string memory name = "Alice";

        testPlayerNameRegistrationSuccess();

        try playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(msg.sender, name) {
            fail("Registering duplicate name should fail.");
        } catch Error(string memory reason) {
            assertTrue(
                keccak256(bytes(reason)) == keccak256("This name is already in use."),
                "Incorrect error message for duplicate name."
            );
        } catch (bytes memory) /*lowLevelData*/ {
            fail("Low level error on registering duplicate name");
        }
    }

    function testPlayerNameRegistrationInsufficientFunds() public {
        string memory name = "Bob";

        try playerNameRegistry.registerPlayerName{value: 19000000000000000}(msg.sender, name) {
            fail("Registering name without sufficient funds should fail.");
        } catch Error(string memory reason) {
            assertTrue(
                keccak256(bytes(reason)) == keccak256("Insufficient funds to register the name."),
                "Incorrect error message for insufficient funds."
            );
        } catch (bytes memory) /*lowLevelData*/ {
            fail("Low level error on registering name without sufficient funds");
        }
    }

    function testGetPlayerNames() public {
        string[] memory expectedNames = new string[](2);
        expectedNames[0] = "Alice";
        expectedNames[1] = "Bob";
        uint256 NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei

        // Register two names first
        playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(msg.sender, expectedNames[0]);
        playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(msg.sender, expectedNames[1]);

        string[] memory names = playerNameRegistry.getPlayerNames(msg.sender);
        assertTrue(names.length == expectedNames.length, "Player does not have the correct number of registered names.");
        for (uint256 i = 0; i < names.length; i++) {
            assertTrue(keccak256(bytes(names[i])) == keccak256(bytes(expectedNames[i])), "Unexpected name in the list.");
        }
    }

    function testGetPlayerFirstName() public {
        string memory name = "Alice";
        uint256 NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei

        // Register a name first
        playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(msg.sender, name);

        string memory firstName = playerNameRegistry.getPlayerFirstName(msg.sender);
        assertTrue(
            keccak256(bytes(firstName)) == keccak256(bytes(name)), "First name getter returned incorrect result."
        );
    }

    function testPlayerNameRegistryReferralRewards() public {
        testBuyKeyNormalGamePlayNOKeys();
        // Register a name for user 1
        uint256 NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei
        string memory userName = "Alice";

        try playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(address(1), userName) {
            string memory name = playerNameRegistry.getPlayerFirstName(address(1));
            console.log("Registered name:", name);

            // Perform the key purchase using user 2 as a referral
            uint256 numberOfKeys = 10;

            try xenGameInstance.buyWithReferral{value: 5 ether}(userName, numberOfKeys) {
                // Check if referral rewards and key rewards are recorded in the player struct for user 1
                (,, uint256 referralRewards,, uint256 keyRewards,) = xenGameInstance.getPlayerInfo(address(1), 1);
                console.log("Referral Rewards for User 1:", referralRewards);
                console.log("Key Rewards for User 1:", keyRewards);


                assertTrue(referralRewards > 0, "Referral rewards not recorded in the player struct for user 1.");
            } catch Error(string memory reason) {
                fail(reason);
            } catch (bytes memory) /*lowLevelData*/ {
                fail("Low level error on buyWithReferral");
            }
        } catch Error(string memory reason) {
            fail(reason);
        } catch (bytes memory) /*lowLevelData*/ {
            fail("Low level error on registering name");
        }
    }
}
