// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "../src/UniswapV3Pool.sol";
import "../src/interfaces/IERC20.sol";

contract UniswapV3Manager {
    address private poolAddress;
    address private sender;

    modifier withPool(address poolAddress_) {
        poolAddress = poolAddress_;
        _;
        poolAddress = address(0x0);
    }

    modifier withSender() {
        sender = msg.sender;
        _;
        sender = address(0x0);
    }

    function mint(
        address poolAddress_,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity
    ) public withPool(poolAddress_) withSender {
        UniswapV3Pool(poolAddress_).mint(
            msg.sender,
            lowerTick,
            upperTick,
            liquidity
        );
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) public {
        IERC20 token0 = IERC20(UniswapV3Pool(poolAddress).token0());
        IERC20 token1 = IERC20(UniswapV3Pool(poolAddress).token1());

        token0.transferFrom(sender, msg.sender, amount0);
        token1.transferFrom(sender, msg.sender, amount1);
    }
}
