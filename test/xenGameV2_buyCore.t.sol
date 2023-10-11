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

contract XenGameBuyCoreTest is Test {
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

    /**
     * Should not allow to buyCore if round is inactive
     */
    function testCantBuyNoNumberOfKeysIfRoundInactive() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        //vm.deal(msg.sender, initialETHAmount);
        xenGameInstance.startNewRoundO();
        vm.expectRevert(bytes("Cannot purchase keys during the round gap"));
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );
    }

    /**
     * Check referral reward buyCore
     */
    function testRefererRewardBuyWithReferralNoNumberOfKeys() public {
        uint256 initialETHAmount = 1 ether;
        uint256 registerationFee = 0.02 ether;
        uint256 numberOfKeys = 0;

        //vm.deal(msg.sender, registerationFee);
        playerNameRegistry.registerPlayerName{value: registerationFee}(
            BOB,
            "RefererRewardNoNumberOfKeys"
        );

        //vm.deal(msg.sender, initialETHAmount);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "RefererRewardNoNumberOfKeys",
            numberOfKeys
        );

        uint refererReward = xenGameInstance.getPlayerReferralRewards(BOB);
        assertTrue(
            refererReward == 0.05 ether,
            "BuyWithReferralNoNumberOfKeys: invalid referer reward"
        );
    }

    /**
     * If nothing passed as referral, the devteam will receive reward - buyCore
     */
    function testRefererRewardShouldRewardTo0x0NoNumberOfKeys() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        //vm.deal(msg.sender, initialETHAmount);
        uint beforeRefererReward = xenGameInstance.getPlayerReferralRewards(
            address(0)
        );
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );
        uint refererReward = xenGameInstance.getPlayerReferralRewards(
            address(0)
        );

        assertTrue(
            refererReward - beforeRefererReward == 50000000000000000,
            "BuyWithReferralNoNumberOfKeys: wrong reward to address(0)"
        );
    }


    /**
     * Simple buy and withdraw, make sure getPlayerInfo.keyreward = withdrawReward fund
     */
    function testSimpleBuyNoNumberOfKeys() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        (
            ,,,,uint keyreward,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);


        // withdraw fund to make sure
        uint balanceBefore = address(this).balance;
        xenGameInstance.withdrawRewards(roundId);

        assertTrue(address(this).balance - balanceBefore  == keyreward, "keyreward mismatchs ");
        balanceBefore = address(this).balance;

        xenGameInstance.withdrawRewards(roundId);
        assertTrue(address(this).balance - balanceBefore  == 0, "keyreward should be zero ");
    }

    /**
     * Test buyWithReferral in earlyBuyin then try to withdraw
     * AUDIT: issue xenGameInstance.getPlayerInfo(address(this), roundId);
     *  got Arithmetic overflow/underflow issue with those steps
     *  round.rewardRaito is not set
     * AUDIT round2: return keycount in earlyBuyin -> wrong logic
     */
    function testBuyWithReferralNoNumberOfKeysEarlyBuyin() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        (
            uint256 keyCount,
            uint256 earlyBuyinPoints,
            uint256 referralRewards,
            uint256 lastRewardRatio,
            uint256 keyRewards,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        assertTrue(keyCount == 10000000 ether, "In earlybuyin - no key purchased");
        assertTrue(referralRewards == 0, "No referralRewards yet");
        assertTrue(lastRewardRatio == 1, "No lastRewardRatio yet");
        assertTrue(keyRewards == 0, "wrong keyward");
        assertTrue(
            earlyBuyinPoints == 950000000000000000,
            "wrong early buyin point"
        );
    }

    /**
     * scenario: earlyBuyin, then withdraw immediately
     * expect: unable to withdraw
     */
    function testBuyWithReferralNoNumberOfKeysEarlyBuyinThenWithdrawReward()
        public
    {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();

        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        vm.expectRevert();
        xenGameInstance.withdrawRewards(roundId);
    }

    /**
     * scenario: 2 earlyBuyin, then withdraw immediately
     * expect: able to withdraw
     */
    function testDoubleBuyWithReferralNoNumberOfKeysEarlyBuyinThenWithdrawReward()
        public
    {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();

        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        vm.deal(ALICE, 10 ether);
        vm.prank(ALICE);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        // during this time frame revert "Arithmetic over/underflow" when trying 
        // to withdraw the rewards.
        vm.prank(address(this));
        vm.expectRevert();
        xenGameInstance.withdrawRewards(roundId);

        // wait for the normal time frame
        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION);

        vm.prank(ALICE);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        xenGameInstance.withdrawRewards(roundId);
        xenGameInstance.withdrawRewards(roundId);
    }

    /**
     * Scenario
     * ALICE -> buyinEarly
     * BOB -> buyinEearly
     * CARLOS -> buy not early
     * ALICE -> withdraw
     * BOB -> withdraw
     * CARLOS -> withdraw
     * Expect: all withdraws success
     */
    function testBuyWithReferralNoNumberOfKeysEarlyBuyinThenWithdrawMultiple()
        public
    {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        vm.deal(msg.sender, 10 ether);

        vm.deal(ALICE, 10 ether);
        vm.prank(ALICE);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        vm.deal(BOB, 10 ether);
        vm.prank(BOB);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION + 1);

        vm.deal(CARLOS, 10 ether);
        vm.prank(CARLOS);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        /**
         * Verify the reward in earlybuyin
         */
        vm.prank(ALICE);
        xenGameInstance.withdrawRewards(roundId);

        vm.prank(BOB);
        xenGameInstance.withdrawRewards(roundId);

        /**
         * Verify the reward not in earlyBuyin
         */
        (
            uint256 keyCount,
            uint256 earlyBuyinPoints,
            uint256 referralRewards,
            uint256 lastRewardRatio,
            uint256 keyRewards,
            uint256 numberOfReferrals
        ) = xenGameInstance.getPlayerInfo(CARLOS, roundId);
        assertTrue(keyCount > 0, "");
        assertTrue(referralRewards == 0, "No referralRewards yet");
        assertTrue(lastRewardRatio > 0, "No lastRewardRatio yet");
        assertTrue(keyRewards > 0, "wrong keyward");
        assertTrue(earlyBuyinPoints == 0, "wrong early buyin point");

        uint balanceBefore = CARLOS.balance;
        vm.prank(CARLOS);
        xenGameInstance.withdrawRewards(roundId);

        assertTrue(
            CARLOS.balance - balanceBefore == keyRewards,
            "wrong keyrewards calculation"
        );
        (
            keyCount,
            earlyBuyinPoints,
            referralRewards,
            lastRewardRatio,
            keyRewards,
            numberOfReferrals
        ) = xenGameInstance.getPlayerInfo(CARLOS, roundId);
        assertTrue(keyRewards == 0, "wrong keyward");
        assertTrue(earlyBuyinPoints == 0, "wrong early buyin point");
    }

    /**
     * Scenario wait end round
     * ALICE -> buyinEarly
     * BOB -> buyinEearly
     * CARLOS -> buy not early
     * ALICE -> withdraw
     * BOB -> withdraw
     * CARLOS -> withdraw
     * Expect: all withdraws success
     */
    function testBuyWithReferralNoNumberOfKeysEarlyBuyinThenWithdrawMultipleWaitEndRound()
        public
    {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        uint256 roundEndTime = xenGameInstance.getRoundEnd(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        vm.deal(msg.sender, 10 ether);

        vm.deal(ALICE, 10 ether);
        vm.prank(ALICE);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        vm.deal(BOB, 10 ether);
        vm.prank(BOB);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION + 1);

        vm.deal(CARLOS, 10 ether);
        vm.prank(CARLOS);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        vm.warp(roundEndTime);

        vm.prank(ALICE);
        xenGameInstance.withdrawRewards(roundId);

        vm.prank(BOB);
        xenGameInstance.withdrawRewards(roundId);

        /**
         * Verify the reward not in earlyBuyin
         */
        (
            uint256 keyCount,
            uint256 earlyBuyinPoints,
            uint256 referralRewards,
            uint256 lastRewardRatio,
            uint256 keyRewards,

        ) = xenGameInstance.getPlayerInfo(CARLOS, roundId);
        assertTrue(keyCount > 0, "");
        assertTrue(referralRewards == 0, "No referralRewards yet");
        assertTrue(lastRewardRatio > 0, "No lastRewardRatio yet");
        assertTrue(keyRewards > 0, "wrong keyward");
        assertTrue(earlyBuyinPoints == 0, "wrong early buyin point");
        uint balanceBefore = CARLOS.balance;
        vm.prank(CARLOS);
        xenGameInstance.withdrawRewards(roundId);

        assertTrue(
            CARLOS.balance - balanceBefore == keyRewards,
            "wrong keyrewards calculation"
        );
        (, earlyBuyinPoints, , , keyRewards, ) = xenGameInstance.getPlayerInfo(
            CARLOS,
            roundId
        );
        assertTrue(keyRewards == 0, "wrong keyward");
        assertTrue(earlyBuyinPoints == 0, "wrong early buyin point");
    }

    /**
     * Scenario
     * 1. no early buyin
     * 2. withdraw
     * expect reverted
     */
    function testBuyWithReferrerNoEarlyThenWithdraw() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 normalBuyingTime = xenGameInstance.getRoundStart(roundId) +
            EARLY_BUYIN_DURATION +
            1;
        vm.warp(normalBuyingTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        (
            uint256 keyCount,
            uint256 earlyBuyinPoints,
            uint256 referralRewards,
            uint256 lastRewardRatio,
            uint256 keyRewards,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        assertTrue(
            keyCount == 14906000000000000000000,
            "invalid keyCount"
        );
        assertTrue(referralRewards == 0, "No referralRewards yet");
        assertTrue(lastRewardRatio == 1, "No lastRewardRatio yet");
        assertTrue(keyRewards == 475043659525000000, "wrong keyward");
        assertTrue(earlyBuyinPoints == 0, "wrong early buyin point");

        uint balanceBefore = address(this).balance;
        xenGameInstance.withdrawRewards{gas: 500000}(roundId);

        assertTrue(
            address(this).balance - balanceBefore == keyRewards,
            "wrong balance"
        );
    }

    /**
     * Scenario isRoundEnded
     * 1. Wait for round expired
     * 2. BuyCore
     * 3. check if the round is active again
     * 4. BuyCore
     * 5. Expect keys into player
     * 7. withdraw
     * expect keep full fund back to ALICE and BOB get rewards
     */
    function testBuyWithReferrerRoundExpiredThenWithdraw() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 endTime = xenGameInstance.getRoundEnd(roundId);
        vm.warp(endTime + 1);
        
        bool isActive = xenGameInstance.isRoundActive();
        assertTrue(
            isActive == false,
            "Round should be ended"
        );

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        // if user buy in this time, no keys purchased, just reward = total sent
        (
            uint256 keyCount,
            ,
            ,
            ,
            uint256 keyRewards,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        assertTrue(
            keyCount == 0,
            "In earlybuyin - no key purchased"
        );
        assertTrue(keyRewards == 1 ether, "wrong keyward");

        // round should be active again
        isActive = xenGameInstance.isRoundActive();
        assertTrue(
            isActive == true,
            "Round should be active"
        );

        vm.warp(endTime + 601);
        isActive = xenGameInstance.isRoundActive();
        assertTrue(
            isActive == false,
            "Round should be ended"
        );

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            0
        );
        (
            keyCount,
            ,
            ,
            ,
            keyRewards,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        assertTrue(
            keyCount == 0,
            "In earlybuyin - no key purchased"
        );
        assertTrue(keyRewards == 2 ether, "wrong keyward");

        // round should be active again
        isActive = xenGameInstance.isRoundActive();
        assertTrue(
            isActive == true,
            "Round should be active"
        );

        uint balanceBefore = address(this).balance;
        xenGameInstance.withdrawRewards(roundId);
        assertTrue(
            address(this).balance - balanceBefore == 2 ether,
            "wrong withdrawRewards from address(this)"
        );

        (
            keyCount,
            ,
            ,
            ,
            keyRewards,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        assertTrue(
            keyCount == 0,
            "In earlybuyin - no key purchased"
        );
        assertTrue(keyRewards == 0, "wrong keyward");
    }

    /**
     * Scenario end round if user try to buy at isRoundEnd
     * 1. BuyCore with Alice (no earlyBuyin)
     * 2. Wait for round expired
     * 4. BuyCore again with BOB
     * 5. Expect round ended - trigger start new round
     * 6. withdraw BOB of previous round
     * 7. withdraw BOB of current round
     * 8. withdraw ALICE of previous round
     * 9. withdraw ALICE of current round
     * expect
     *  - with previousRound Alice is winner
     *  - with currentRound alice got no reward
     *  - 
     */
    function testBuyWithReferrerRoundExpiredEndroundThenWithdraw() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        // AUDIT: if earlyBuyin, next person buy in expired time still can't trigger the ended round
        uint256 startTime = xenGameInstance.getRoundEnd(roundId);
        vm.warp(startTime - 1000);

        vm.prank(ALICE);
        vm.deal(ALICE, 10 ether);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        uint256 endTime = xenGameInstance.getRoundEnd(roundId);
        vm.warp(endTime + 1);

        bool isActive = xenGameInstance.isRoundActive();
        assertTrue(
            isActive == false,
            "Round should be ended"
        );

        // this trigger new round
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        assertTrue(
            xenGameInstance.getRoundEnded(roundId) == true,
            "Round should be ended"
        );

        assertTrue(
            xenGameInstance.currentRound() == 3, "starNewRound doesn't success"
        );
        
        uint256 starTime = xenGameInstance.getRoundStart(roundId + 1) + 1;
        vm.warp(starTime);

        isActive = xenGameInstance.isRoundActive();
        assertTrue(
            isActive == true,
            "Round should be active"
        );

        (
            uint256 keyCount,
            ,
            ,
            ,
            uint256 keyRewards,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        assertTrue(
            keyCount == 0,
            "In earlybuyin - no key purchased"
        );
        assertTrue(keyRewards == 0, "wrong keyward");

        (
            keyCount,
            ,
            ,
            ,
            keyRewards,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId+1);
        assertTrue(
            keyCount == 0,
            "In earlybuyin - no key purchased"
        );
        assertTrue(keyRewards == 1 ether, "wrong keyward");


        // ALICE withdraw previous round
        // ALICE is winner - expect successed
        uint balanceBefore = ALICE.balance;
        vm.prank(ALICE);
        xenGameInstance.withdrawRewards(roundId);

        assertTrue(
            ALICE.balance - balanceBefore > 0,
            "wrong balance"
        );

        // withdraw with address(this) --> expect success
        xenGameInstance.withdrawRewards(roundId+1);
    }

    /**
     * Should not trigger the ResetPrice if the jackpot is low < 10
     */
    // function testTriggerPriceReset() public {
    //     uint jackPot; 
    //     uint keyPrice;

    //     uint256 initialETHAmount = 0.01 ether;
    //     uint256 numberOfKeys = 0;
    //     xenGameInstance.startNewRoundO();
    //     uint256 roundId = xenGameInstance.currentRound();

    //     uint256 normalBuyTime = xenGameInstance.getRoundEnd(roundId) - 1000;
    //     vm.warp(normalBuyTime);

    //     for (uint i = 0; i < 10; i++) {
    //         xenGameInstance.buyWithReferral{value: initialETHAmount}(
    //             "",
    //             numberOfKeys
    //         );
    //         jackPot = xenGameInstance.getRoundJackpot(roundId);
    //         keyPrice = xenGameInstance.getKeyPrice();
            
    //     }

    //     assertTrue(false, "check event emiited");
    // }

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

    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
