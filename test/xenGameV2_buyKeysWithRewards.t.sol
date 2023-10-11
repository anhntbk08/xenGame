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
     * Should not allow to buyKeysWithRewards if round is inactive
     */
    function testGotRewardIfEarlyBuyin() public {
        xenGameInstance.startNewRoundO();

        vm.expectRevert("Round is not active");
        xenGameInstance.buyKeysWithRewards();
    }

    /**
     * Revert when there is no reward
     */
    function testBuyWithKeyRewardsWhenNoRewards() public {
        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        vm.expectRevert("No rewards to buy keys with");
        xenGameInstance.buyKeysWithRewards();
    }

    /**
     * Scenario
     * - Buy in early Buyin stage
     * - Call Buy with key rewards - expect revert
     * - Buy in normal time frame
     * - call BuyWithKeyRewards until calculateMaxKeysToPurchase(keyreward) == 0
     * - withdraw
     */
    function testBuyWithKeyRewardsContinuously() public {
        uint256 initialETHAmount = 0.001 ether;
        uint256 numberOfKeys = 0;

        xenGameInstance.startNewRoundO();
        uint256 roundId = xenGameInstance.currentRound();

        uint256 earlyKeyBuyinTime = xenGameInstance.getRoundStart(roundId) + 1;
        vm.warp(earlyKeyBuyinTime);

        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        vm.expectRevert(bytes("No rewards to buy keys with"));
        xenGameInstance.buyKeysWithRewards();

        vm.warp(earlyKeyBuyinTime + EARLY_BUYIN_DURATION);
        xenGameInstance.buyWithReferral{value: initialETHAmount}(
            "",
            numberOfKeys
        );

        (
            uint256 keyCount,,,,,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        
        xenGameInstance.buyKeysWithRewards();

        // use Carlos to buy with large fund
        vm.deal(CARLOS, 20 ether);

        for (uint i = 0; i < 10; i++) {
            vm.prank(CARLOS);
            xenGameInstance.buyWithReferral{value: 1 ether}("",0);
        }
        
        // the first user keeps calling buyKeysWithRewards to be winner
        (
            uint256 keyCountAfter,,,,,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        assertTrue(keyCountAfter > keyCount);

        for (uint i = 0; i < 20; i++) {
            xenGameInstance.buyKeysWithRewards();
        }
        (
            uint256 keyCountAfter1,,,,,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);

        assertTrue(keyCountAfter1 > keyCountAfter, "should not allow buyKeysWithRewards multiple times ");

        (
            ,,,, uint keyReward,
        ) = xenGameInstance.getPlayerInfo(address(this), roundId);
        
        (uint maxKey,) = xenGameInstance.calculateMaxKeysToPurchase(keyReward);

        assertTrue(maxKey == 0);

        // withdraw fund to make sure
        uint balanceBefore = address(this).balance;
        xenGameInstance.withdrawRewards(roundId);

        assertTrue(address(this).balance - balanceBefore  == keyReward, "keyreward mismatchs ");
        balanceBefore = address(this).balance;

        xenGameInstance.withdrawRewards(roundId);
        assertTrue(address(this).balance - balanceBefore  == 0, "keyreward should be zero ");
    }
    

    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
