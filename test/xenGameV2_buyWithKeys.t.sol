// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/NFTRegistry.sol";
import "../src/xenBurn.sol";
import "../src/xenPriceOracle.sol";
import "../src/PlayerNameRegistry.sol";
import "./XenGameT.sol";
import "../src/test/NFTContract.sol";
import "./IxenNFTContract.sol";

contract XenGameBuyWithKeysTest is Test {
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
     * AUDIT: there is 1 issue with when the lastKeyPrice = 0
     * the public view calculatePriceForKeys reverted
     */
    function testCalculateMaxKeysToPurchase() public {
        uint256 initialETHAmount = 1.234 ether;
        uint256 roundId = 1;

        uint round1TotalKeys = xenGameInstance.getRoundTotalKeys(roundId);
        assertTrue(round1TotalKeys == 10097300000000000000000000, "NO KEY");

        uint keyPrice = xenGameInstance.getKeyPrice();
        assertTrue(keyPrice == 44087673862494, "Wrong keyprice");

        (uint256 maxKeysToPurchase, uint256 totalCost) = xenGameInstance
            .calculateMaxKeysToPurchase(initialETHAmount);

        assertTrue(maxKeysToPurchase == 12370, "maxKeysToPurchase wrong");

        assertTrue(totalCost == 1233884910679050780, "totalCost wrong");

        xenGameInstance.startNewRoundO();
        keyPrice = xenGameInstance.getKeyPrice();
        assertTrue(
            keyPrice == 9000000000,
            "Wrong keyprice when start new Round"
        );

        uint estimatedPriceForKeys = xenGameInstance.calculatePriceForKeys(1);
        assertTrue(
            estimatedPriceForKeys == 9000000000,
            "Wrong estimatedPriceForKeys when start new Round"
        );

        estimatedPriceForKeys = xenGameInstance.calculatePriceForKeys(10);
        assertTrue(
            estimatedPriceForKeys == 495000000000,
            "Wrong estimatedPriceForKeys when start new Round"
        );

        // calling those function during the gap
        (maxKeysToPurchase, totalCost) = xenGameInstance
            .calculateMaxKeysToPurchase(initialETHAmount);

        assertTrue(maxKeysToPurchase == 16559, "maxKeysToPurchase wrong");

        // calling function when the round is totally active

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        estimatedPriceForKeys = xenGameInstance.calculatePriceForKeys(1);
        assertTrue(
            estimatedPriceForKeys == 9000000000,
            "Wrong estimatedPriceForKeys when start new Round"
        );
    }

    /**
     * Should not allow to buy if round is inactive
     */
    function testCantBuyIfRoundInactive() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 1;

        //vm.deal(msg.sender, initialETHAmount);
        xenGameInstance.startNewRoundO();
        vm.expectRevert(bytes("Cannot purchase keys during the round gap"));
        xenGameInstance.buyWithReferral{value: initialETHAmount}("",numberOfKeys);
    }

    /**
     * Check referral reward 
     */
    function testRefererRewardBuyWithReferral() public {
        uint256 initialETHAmount = 1 ether;
        uint256 registerationFee = 0.02 ether;
        uint256 numberOfKeys = 1;

        //vm.deal(msg.sender, registerationFee);
        playerNameRegistry.registerPlayerName{value: registerationFee}(
            BOB,
            "RefererReward_BuyWithReferral"
        );

        //vm.deal(msg.sender, initialETHAmount);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "RefererReward_BuyWithReferral",
            numberOfKeys
        );

        uint refererReward = xenGameInstance.getPlayerReferralRewards(
            BOB
        );
        assertTrue(
            refererReward == 0.05 ether,
            "BuyWithReferral: invalid referer reward"
        );
    }

    /**
     * If nothing passed as referral, the devteam will receive reward
     */
    function testRefererRewardShouldRewardTo0x0() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 1;

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
            "BuyWithReferral: wrong reward to address(0)"
        );
    }

    /**
     * Test buyWithReferral in earlyBuyin then try to withdraw
     * AUDIT: issue xenGameInstance.getPlayerInfo(address(this), roundId); 
     *  got Arithmetic overflow/underflow issue with those steps
     *  round.rewardRaito is not set
     * AUDIT round2: return 10000000 ether keycount in earlyBuyin
     */
    function testBuyWithReferralEarlyBuyin() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 28;

        xenGameInstance.startNewRoundO();

        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}("",numberOfKeys);

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
    function testBuyWithReferralEarlyBuyinThenWithdrawReward() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 28;

        xenGameInstance.startNewRoundO();

        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}("",numberOfKeys);
        vm.expectRevert();
        xenGameInstance.withdrawRewards(roundId);
    }

    /**
     * scenario: 2 earlyBuyin, then withdraw immediately 
     * expect: able to withdraw
     */
    function testDoubleBuyWithReferralEarlyBuyinThenWithdrawReward() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 28;

        xenGameInstance.startNewRoundO();

        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}("",numberOfKeys);

        vm.deal(ALICE, 10 ether);
        vm.prank(ALICE);
        xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys);
        
        vm.prank(address(this));
        vm.expectRevert();
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
    function testBuyWithReferralEarlyBuyinThenWithdrawMultiple() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 28;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();
        
        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        vm.deal(msg.sender, 10 ether);

        vm.deal(ALICE, 10 ether);
        vm.prank(ALICE);
        xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys);

        vm.deal(BOB, 10 ether);
        vm.prank(BOB);
        xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys);

        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION + 1);

        vm.deal(CARLOS, 10 ether);
        vm.prank(CARLOS);
        xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys);

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
        assertTrue(
            earlyBuyinPoints == 0,
            "wrong early buyin point"
        );

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
        assertTrue(
            earlyBuyinPoints == 0,
            "wrong early buyin point"
        );
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
    function testBuyWithReferralEarlyBuyinThenWithdrawMultipleWaitEndRound() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 28;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();
        
        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        uint256 roundEndTime = xenGameInstance.getRoundEnd(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        vm.deal(msg.sender, 10 ether);

        vm.deal(ALICE, 10 ether);
        vm.prank(ALICE);
        xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys);

        vm.deal(BOB, 10 ether);
        vm.prank(BOB);
        xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys);

        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION + 1);

        vm.deal(CARLOS, 10 ether);
        vm.prank(CARLOS);
        xenGameInstance.buyWithReferral{value: initialETHAmount}("", numberOfKeys);

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
        assertTrue(
            earlyBuyinPoints == 0,
            "wrong early buyin point"
        );
        uint balanceBefore = CARLOS.balance;
        vm.prank(CARLOS);
        xenGameInstance.withdrawRewards(roundId);

        assertTrue(
            CARLOS.balance - balanceBefore == keyRewards,
            "wrong keyrewards calculation"
        );
        (,earlyBuyinPoints,,, keyRewards,) = xenGameInstance.getPlayerInfo(CARLOS, roundId);
        assertTrue(keyRewards == 0, "wrong keyward");
        assertTrue(
            earlyBuyinPoints == 0,
            "wrong early buyin point"
        );

    }

    /**
     * Scenario
     * 1. no early buyin
     * 2. withdraw
     * expect reverted
     */
    function testBuyWithReferrerNoEarlyThenWithdraw() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 28;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) +
            EARLY_BUYIN_DURATION + 1;
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
        assertTrue(keyCount == 28000000000000000000, "In earlybuyin - no key purchased");
        assertTrue(referralRewards == 0, "No referralRewards yet");
        assertTrue(lastRewardRatio == 1, "No lastRewardRatio yet");
        assertTrue(keyRewards == 1735650000000, "wrong keyward");
        assertTrue(
            earlyBuyinPoints == 0,
            "wrong early buyin point"
        );
        
        uint balanceBefore = address(this).balance;
        xenGameInstance.withdrawRewards(roundId);

        assertTrue(
            address(this).balance - balanceBefore == keyRewards,
            "wrong balance"
        );
        
    }

    /**
     * Scenario:
     * -  earlyBuyIn - buyCore
     * -  earlyBuyIn - buyWithKeys
     */
    function testBuyEarlyBuyinPoolNoReferral() public {
        uint256 initialETHAmount = 1 ether;
        uint256 numberOfKeys = 10;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;

        vm.warp(earlyKeyBuyinTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}("",numberOfKeys);

        uint256 earlyBuyEth = xenGameInstance.getRoundEarlyBuyin(roundId);
        assertTrue(
            earlyBuyEth == 0.95 ether,
            "No ETH in early buying pool."
        );

        vm.startPrank(CARLOS);
        vm.deal(CARLOS, 2 ether);
        xenGameInstance.buyWithReferral{value: initialETHAmount}("", 0);

        earlyBuyEth = xenGameInstance.getRoundEarlyBuyin(roundId);
        assertTrue(
            earlyBuyEth == 0.95*2 ether,
            "No ETH in early buying pool."
        );
    }

    function testPlayerNameRegistrationSuccess() public {
        uint256 NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei
        string memory name = "Alice";

        try
            playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(
                msg.sender,
                name
            )
        {
            string memory registeredName = playerNameRegistry
                .getPlayerFirstName(msg.sender);
            assertTrue(
                keccak256(bytes(registeredName)) == keccak256(bytes(name)),
                "Name was not registered correctly."
            );
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

        try
            playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(
                msg.sender,
                name
            )
        {
            fail("Registering duplicate name should fail.");
        } catch Error(string memory reason) {
            assertTrue(
                keccak256(bytes(reason)) ==
                    keccak256("This name is already in use."),
                "Incorrect error message for duplicate name."
            );
        } catch (bytes memory) /*lowLevelData*/ {
            fail("Low level error on registering duplicate name");
        }
    }

    function testPlayerNameRegistrationInsufficientFunds() public {
        string memory name = "Bob";

        try
            playerNameRegistry.registerPlayerName{value: 19000000000000000}(
                msg.sender,
                name
            )
        {
            fail("Registering name without sufficient funds should fail.");
        } catch Error(string memory reason) {
            assertTrue(
                keccak256(bytes(reason)) ==
                    keccak256("Insufficient funds to register the name."),
                "Incorrect error message for insufficient funds."
            );
        } catch (bytes memory) /*lowLevelData*/ {
            fail(
                "Low level error on registering name without sufficient funds"
            );
        }
    }

    function testGetPlayerNames() public {
        string[] memory expectedNames = new string[](2);
        expectedNames[0] = "Alice";
        expectedNames[1] = "Bob";
        uint256 NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei

        // Register two names first
        playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(
            msg.sender,
            expectedNames[0]
        );
        playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(
            msg.sender,
            expectedNames[1]
        );

        string[] memory names = playerNameRegistry.getPlayerNames(msg.sender);
        assertTrue(
            names.length == expectedNames.length,
            "Player does not have the correct number of registered names."
        );
        for (uint256 i = 0; i < names.length; i++) {
            assertTrue(
                keccak256(bytes(names[i])) ==
                    keccak256(bytes(expectedNames[i])),
                "Unexpected name in the list."
            );
        }
    }

    function testGetPlayerFirstName() public {
        string memory name = "Alice";
        uint256 NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei

        // Register a name first
        playerNameRegistry.registerPlayerName{value: NAME_REGISTRATION_FEE}(
            msg.sender,
            name
        );

        string memory firstName = playerNameRegistry.getPlayerFirstName(
            msg.sender
        );
        assertTrue(
            keccak256(bytes(firstName)) == keccak256(bytes(name)),
            "First name getter returned incorrect result."
        );
    }

    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
