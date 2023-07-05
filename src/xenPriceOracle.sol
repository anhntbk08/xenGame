// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// for testing only
import "forge-std/console.sol";

contract PriceOracle {
    // Assuming these addresses are for the pairs you're interested in
    address private constant V2_PAIR = 0xC0d776E2223c9a2ad13433DAb7eC08cB9C5E76ae; // V2 XEN/ETH Pair
    address private constant V3_XEN_ETH = 0x2a9d2ba41aba912316D16742f259412B681898Db; // V3 XEN/ETH Pool
    address private constant V3_XEN_USDT = 0x92a0515f69b46a1428a9aAcbE8c273FfCA4809D8; // V3 XEN/USDT Pool
    address private constant V3_XEN_USDC = 0x353BB62Ed786cDF7624BD4049859182f3c1E9e5d; // V3 XEN/USDC Pool
    address private constant V3_ETH_USDT = 0x11b815efB8f581194ae79006d24E0d814B7697F6; // V3 ETH/USDT Pool
    address private constant V3_ETH_USDC = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // V3 ETH/USDC Pool
    address private constant XenAddress = 0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8; // Xen crypto on ETH

    function calculateV2Price() public view returns (uint256) {
        // The IUniswapV2Pair.getReserves function returns the liquidity reserves of token0 and token1 in the pair
        // token0 is the token with the lower sort order of the pair
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(V2_PAIR).getReserves();
        require(reserve1 != 0, "Reserve for ETH is 0");

        // The price is calculated as the ratio of the reserves of token0 to token1
        // Assuming that token0 is XEN and token1 is ETH, this will return the price of XEN in terms of ETH
        return uint256(reserve0) / uint256(reserve1); // Returns the price as token0/token1 (XEN/ETH)
    }

    function calculateV3Price(IUniswapV3Pool pool, bool isToken0Xen) public view returns (uint256) {
        // The IUniswapV3Pool.slot0 function returns the current state of the pool,
        // which includes the square root price as a Q64.96 fixed-point number
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        console.log("slot0", sqrtPriceX96);

        // Get the token0 and token1 addresses of the pool
        (address token0, address token1) = (pool.token0(), pool.token1());

        console.log("token0", token0);
        console.log("token1", token1);

        // Check which token is XEN in the pair
        isToken0Xen = token0 == XenAddress;
        bool isToken1Xen = token1 == XenAddress;

        // require(isToken0Xen || isToken1Xen, "Neither token in the Uniswap V3 pool is XEN");

        // The square root price is squared to get the actual price,
        // and it is shifted right by 192 (96*2) to convert from Q64.96 format to an integer
        uint256 priceToken0Token1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) >> 96; // Price of token0 in terms of token1

        console.log("price returned", priceToken0Token1);

        // The actual price is calculated differently depending on which token in the pair is XEN
        if (isToken0Xen) {
            // If token0 is XEN, the price is already token0/token1 (XEN/Other) and can be returned directly
            return priceToken0Token1; // Return XEN/Other price
        } else {
            // If token1 is XEN, the price is token1/token0 (Other/XEN),
            // so we return the reciprocal to get the price as XEN/Other
            require(priceToken0Token1 != 0, "Price is 0");
            return (10 ** 36) / priceToken0Token1; // Return Other/XEN price
        }
    }

    function calculateAveragePrice() public view returns (uint256) {
        uint256 total; // Initialize total price accumulator
        uint256 count; // Initialize counter for the number of price points

        // V2 price calculation
        uint256 v2Price = calculateV2Price(); // Get the XEN/ETH price from the Uniswap V2 pool
        if (v2Price != 0) {
            total += v2Price; // Add the price to the total if it is not zero
            count++; // Increase the price point count by one
        }

        // V3 XEN/ETH price calculation
        uint256 xenEthPrice = calculateV3Price(IUniswapV3Pool(V3_XEN_ETH), true); // Get the XEN/ETH price from the Uniswap V3 pool
        if (xenEthPrice != 0) {
            total += xenEthPrice; // Add the price to the total if it is not zero
            count++; // Increase the price point count by one
        }

        // V3 XEN/USDT price calculation
        uint256 xenUsdtPrice = calculateV3Price(IUniswapV3Pool(V3_XEN_USDT), true); // Get the XEN/USDT price
        if (xenUsdtPrice != 0) {
            // Convert XEN/USDT to XEN/ETH using the ETH/USDT price
            uint256 ethUsdtPrice = calculateV3Price(IUniswapV3Pool(V3_ETH_USDT), false); // Get the ETH/USDT price
            if (ethUsdtPrice != 0) {
                uint256 xenEthUsdtPrice = xenUsdtPrice / ethUsdtPrice; // Convert XEN/USDT to XEN/ETH
                total += xenEthUsdtPrice; // Add the converted price to the total
                count++; // Increase the price point count by one
            }
        }

        // V3 XEN/USDC price calculation
        uint256 xenUsdcPrice = calculateV3Price(IUniswapV3Pool(V3_XEN_USDC), true); // Get the XEN/USDC price
        if (xenUsdcPrice != 0) {
            // Convert XEN/USDC to XEN/ETH using the ETH/USDC price
            uint256 ethUsdcPrice = calculateV3Price(IUniswapV3Pool(V3_ETH_USDC), false); // Get the ETH/USDC price
            if (ethUsdcPrice != 0) {
                uint256 xenEthUsdcPrice = xenUsdcPrice / ethUsdcPrice; // Convert XEN/USDC to XEN/ETH
                total += xenEthUsdcPrice; // Add the converted price to the total
                count++; // Increase the price point count by one
            }
        }

        // Return the average price, dividing the total by the number of price points
        // The result is the average price of XEN in terms of ETH
        require(count != 0, "No valid price points");

        console.log("count", count);
        return total / count;
    }
}
