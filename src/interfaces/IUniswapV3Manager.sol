// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

interface IUniswapV3Manager {
    struct MintParams {
        address tokenA;
        address tokenB;
        uint24 tickSpacing;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct SwapParams {
        address tokenA;
        address tokenB;
        uint24 tickSpacing;
        bool zeroForOne;
        uint256 amountSpecified;
        uint160 sqrtPriceLimitX96;
        bytes data;
    }
}
