// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "../src/UniswapV3Pool.sol";
import "../src/interfaces/IERC20.sol";

contract UniswapV3Manager {
    address private poolAddress;

    modifier pool(address poolAddress_) {
        poolAddress = poolAddress_;
        _;
        poolAddress = address(0x0);
    }

    function mint(
        address poolAddress_,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity
    ) public pool(poolAddress_) {
        UniswapV3Pool(poolAddress).mint(
            msg.sender,
            lowerTick,
            upperTick,
            liquidity
        );
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) public {
        IERC20(UniswapV3Pool(poolAddress).token0()).transfer(
            msg.sender,
            amount0
        );
        IERC20(UniswapV3Pool(poolAddress).token1()).transfer(
            msg.sender,
            amount1
        );
    }
}
