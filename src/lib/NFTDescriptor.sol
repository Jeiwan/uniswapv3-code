// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV3Pool.sol";

contract NFTRenderer {
    struct RendererParams {
        address pool;
        int24 lowerTick;
        int24 upperTick;
        uint24 fee;
    }

    function render(RenderParams memory params)
        internal
        pure
        returns (string memory)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(params.pool);
        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());

        return string.concat("data:application/json;base64,");
    }
}
