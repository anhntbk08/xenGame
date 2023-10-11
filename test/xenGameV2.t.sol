// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/NFTRegistry.sol";
import "../src/xenBurn.sol";
import "../src/xenPriceOracle.sol";
import "../src/PlayerNameRegistry.sol";
import "./XenGameT.sol";

import "./IxenNFTContract.sol";

contract XenGameTest is Test {
    uint256 public initialBalance = 1 ether;
    XenGameT public xenGameInstance;
    xenBurn public XenBurnInstance;
    PriceOracle public priceOracleInstance;
    address public xenCrypto = 0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8;
    NFTRegistry public nftRegistry;
    IxenNFTContract public nftContract;
    address public nftContractAddress =
        0x0a252663DBCc0b073063D6420a40319e438Cfa59;
    PlayerNameRegistry public playerNameRegistry;
    uint256 constant EARLY_BUYIN_DURATION = 300;
    uint256 constant ROUND_GAP = 24 hours;

    address public ALICE = 0x44a7c24669bb4836e7d9708eA119a7C424EEB45B;
    address public BOB = 0xccbc6EF4FF1cf99C90c3BE29456f76d8487bF2CB;
    address public CARLOS = 0xE21906f557eb723434E94ae27f2C734059a82cBf;

    function setUp() public {
        priceOracleInstance = new PriceOracle();

        playerNameRegistry = new PlayerNameRegistry(
            payable(address(4)),
            payable(address(5))
        );
        nftRegistry = new NFTRegistry(nftContractAddress);
        XenBurnInstance = new xenBurn(
            address(priceOracleInstance),
            xenCrypto,
            address(playerNameRegistry)
        );
        xenGameInstance = new XenGameT(
            nftContractAddress,
            address(nftRegistry),
            address(XenBurnInstance),
            address(playerNameRegistry)
        );
    }

    function testCalculateMaxKeysToPurchase() public {
        xenGameInstance.startNewRoundO();
        (uint lowestCase, uint totalCost) = xenGameInstance.calculateMaxKeysToPurchase(0.000000009 ether);
        assertTrue(
            lowestCase == 1, "minimum key is 1"
        );
        assertTrue(
            totalCost == 0.000000009 ether, "cost must be 0.000000009 ether"
        );

        (lowestCase, totalCost) = xenGameInstance.calculateMaxKeysToPurchase(0.0000000009 ether);
        assertTrue(
            lowestCase == 0, "not enough to buy any key"
        );
        assertTrue(
            totalCost == 0, "no cost"
        );

        (lowestCase, totalCost) = xenGameInstance.calculateMaxKeysToPurchase(1 ether);
        assertTrue(
            lowestCase == 14906, "wrong totalKeys"
        );
        assertTrue(
            totalCost == 999916839000000000, "wrong cost"
        );
    }

    function testWithdrawReferralRewards() public {
        uint256 initialETHAmount = 1 ether;
        uint256 registerationFee = 0.02 ether;
        uint256 numberOfKeys = 0;

        playerNameRegistry.registerPlayerName{value: registerationFee}(
            BOB,
            "RefererRewardNoNumberOfKeys"
        );

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "RefererRewardNoNumberOfKeys",
            numberOfKeys
        );

        uint refererReward = xenGameInstance.getPlayerReferralRewards(BOB);
        assertTrue(
            refererReward == 0.05 ether,
            "BuyWithReferralNoNumberOfKeys: invalid referer reward"
        );

        uint balanceBefore = BOB.balance;
        vm.prank(BOB);
        xenGameInstance.withdrawReferralRewards();

        assertTrue(BOB.balance - balanceBefore  == refererReward, "keyreward mismatchs ");

    }

    function testWithdrawBurntKeyRewards() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 20;
        
        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        
        xenGameInstance.withdrawRewards(roundId);

        vm.expectRevert(bytes("Can't withdraw BurntKey Rewards tell round end."));
        xenGameInstance.WithdrawBurntKeyRewards(roundId);
        
        // start new roun
        xenGameInstance.startNewRoundO();

        // withdraw successfully
        xenGameInstance.WithdrawBurntKeyRewards(roundId);

    }

    function testFundDistributeWhenBuyAKeyIfRoundEnd() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;
        
        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 buyTime = xenGameInstance.getRoundEnd(roundId) + 1;
        vm.warp(buyTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );
        
        // expect the referer reward of buyer = amount*0.05
        uint devWalletReward = xenGameInstance.getPlayerReferralRewards(address(0));
        assertTrue(devWalletReward == 0.05 ether, "");

        // expect the buyer keyreward = amount*0.95
        (,,,,uint playerReward,) = xenGameInstance.getPlayerInfo(address(this), roundId);
        assertTrue(playerReward == 0.95 ether, "");
    }

    function testFundDistributeWhenBuyAKeyIfRoundActive() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;
        
        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION);

        uint beforeApexFund = nftRegistry.totalRewards();

        (
            ,
            uint256 totalCost
        ) = xenGameInstance.calculateMaxKeysToPurchase(1 ether);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        // verify how the game distributed fund when user deposit 1 ether to make sure
        // the game doesn't print more money than reserve
        /** 
         *  Input amount = 1 ether
         *  REFERRAL_REWARD_PERCENTAGE = 10% = 0.1 ether;
         *      - 5% for referrer
         *      - 5% for the player
         *  KEYS_FUND_PERCENTAGE = 50% * 0.9
            JACKPOT_PERCENTAGE = 30% * 0.9
            BURN_FUND_PERCENTAGE = 15% * 0.9
            APEX_FUND_PERCENTAGE = 5% * 0.9
        */
        // expect the referer reward of buyer = amount*0.05
        uint devWalletReward = xenGameInstance.getPlayerReferralRewards(address(0));
        assertTrue(devWalletReward == 0.05 ether, "");

        uint remainAmount = totalCost - 0.05 ether;

        uint realJackpot = xenGameInstance.getRoundJackpot(roundId);
        assertTrue(realJackpot == (remainAmount * 30) / 100, "wrong expected jackpot");

        uint realApexFund = nftRegistry.totalRewards();
        assertTrue((remainAmount * 5) / 100  == realApexFund - beforeApexFund, "wrong expected apex fund");

        uint realBurnFund = address(XenBurnInstance).balance;
        assertTrue(realBurnFund == (remainAmount * 15) / 100, "wrong expected burn fund");

    }

    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
