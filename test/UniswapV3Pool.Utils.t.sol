// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";

import "./TestUtils.sol";

abstract contract UniswapV3PoolUtils is Test, TestUtils {
    struct LiquidityRange {
        int24 lowerTick;
        int24 upperTick;
        uint128 amount;
    }

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        uint256 currentPrice;
        LiquidityRange[] liquidity;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiqudity;
    }

    function liquidityRange(
        uint256 lowerPrice,
        uint256 upperPrice,
        uint256 amount0,
        uint256 amount1,
        uint256 currentPrice
    ) internal pure returns (LiquidityRange memory range) {
        range = LiquidityRange({
            lowerTick: tick60(lowerPrice),
            upperTick: tick60(upperPrice),
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP(currentPrice),
                sqrtP60(lowerPrice),
                sqrtP60(upperPrice),
                amount0,
                amount1
            )
        });
    }

    function liquidityRange(
        uint256 lowerPrice,
        uint256 upperPrice,
        uint128 amount
    ) internal pure returns (LiquidityRange memory range) {
        range = LiquidityRange({
            lowerTick: tick60(lowerPrice),
            upperTick: tick60(upperPrice),
            amount: amount
        });
    }
}
