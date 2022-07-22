// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./lib/TickMath.sol";

contract UniswapV3Manager {
    function mint(
        address poolAddress_,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity,
        bytes calldata data
    ) public returns (uint256, uint256) {
        return
            IUniswapV3Pool(poolAddress_).mint(
                msg.sender,
                lowerTick,
                upperTick,
                liquidity,
                data
            );
    }

    function swap(
        address poolAddress_,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) public returns (int256, int256) {
        return
            IUniswapV3Pool(poolAddress_).swap(
                msg.sender,
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : sqrtPriceLimitX96,
                data
            );
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        IUniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (IUniswapV3Pool.CallbackData)
        );

        IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
        IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        IUniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (IUniswapV3Pool.CallbackData)
        );

        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount0)
            );
        }

        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount1)
            );
        }
    }
}
