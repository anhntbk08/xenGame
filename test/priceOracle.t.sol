// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/xenPriceOracle.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract PriceOracleTest is Test {
    PriceOracle public priceOracle;

    function setUp() public {
        priceOracle = new PriceOracle();
    }

    function testCalculateV2Price() public {
        uint256 v2Price = priceOracle.calculateV2Price();
        console.log("V2 XEN/ETH price:", v2Price);
        assertTrue(v2Price > 0, "V2 price should be greater than 0");
    }

    function testCalculateV3Price() public {
        IUniswapV3Pool v3XenEthPool = IUniswapV3Pool(0x2a9d2ba41aba912316D16742f259412B681898Db);
        uint256 v3XenEthPrice;
        try priceOracle.calculateV3Price(v3XenEthPool, true) returns (uint256 _price) {
            v3XenEthPrice = _price;
        } catch Error(string memory reason) {
            console.log("V3 XEN/ETH error:", reason);
        }
        console.log("V3 XEN/ETH price:", v3XenEthPrice);
        assertTrue(v3XenEthPrice > 0, "V3 XEN/ETH price should be greater than 0");

        IUniswapV3Pool v3XenUsdtPool = IUniswapV3Pool(0x92a0515f69b46a1428a9aAcbE8c273FfCA4809D8);
        uint256 v3XenUsdtPrice;
        try priceOracle.calculateV3Price(v3XenUsdtPool, true) returns (uint256 _price) {
            v3XenUsdtPrice = _price;
        } catch Error(string memory reason) {
            console.log("V3 XEN/USDT error:", reason);
        }
        console.log("V3 XEN/USDT price:", v3XenUsdtPrice);
        assertTrue(v3XenUsdtPrice > 0, "V3 XEN/USDT price should be greater than 0");

        IUniswapV3Pool v3XenUsdcPool = IUniswapV3Pool(0x353BB62Ed786cDF7624BD4049859182f3c1E9e5d);
        uint256 v3XenUsdcPrice;
        try priceOracle.calculateV3Price(v3XenUsdcPool, true) returns (uint256 _price) {
            v3XenUsdcPrice = _price;
        } catch Error(string memory reason) {
            console.log("V3 XEN/USDC error:", reason);
        }
        console.log("V3 XEN/USDC price:", v3XenUsdcPrice);
        assertTrue(v3XenUsdcPrice > 0, "V3 XEN/USDC price should be greater than 0");

        IUniswapV3Pool v3EthUsdtPool = IUniswapV3Pool(0x11b815efB8f581194ae79006d24E0d814B7697F6);
        uint256 v3EthUsdtPrice;
        try priceOracle.calculateV3Price(v3EthUsdtPool, false) returns (uint256 _price) {
            v3EthUsdtPrice = _price;
        } catch Error(string memory reason) {
            console.log("V3 ETH/USDT error:", reason);
        }
        console.log("V3 ETH/USDT price:", v3EthUsdtPrice);
        assertTrue(v3EthUsdtPrice > 0, "V3 ETH/USDT price should be greater than 0");

        IUniswapV3Pool v3EthUsdcPool = IUniswapV3Pool(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
        uint256 v3EthUsdcPrice;
        try priceOracle.calculateV3Price(v3EthUsdcPool, false) returns (uint256 _price) {
            v3EthUsdcPrice = _price;
        } catch Error(string memory reason) {
            console.log("V3 ETH/USDC error:", reason);
        }
        console.log("V3 ETH/USDC price:", v3EthUsdcPrice);
        assertTrue(v3EthUsdcPrice > 0, "V3 ETH/USDC price should be greater than 0");
    }

    function testCalculateAveragePrice() public {
        uint256 averagePrice = priceOracle.calculateAveragePrice();
        console.log("Average XEN/ETH price:", averagePrice);
        assertTrue(averagePrice > 0, "Average price should be greater than 0");
    }
}
