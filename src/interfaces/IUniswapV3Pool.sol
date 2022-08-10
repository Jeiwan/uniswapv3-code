// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

interface IUniswapV3Pool {
    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext
        );

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function tickSpacing() external view returns (uint24);

    function fee() external view returns (uint24);

    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256, int256);
}
