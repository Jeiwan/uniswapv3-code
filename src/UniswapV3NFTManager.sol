// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

contract UniswapV3NFTManager {
    struct Position {
        uint80 poolId; // token0 + token1 + fee
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
    }

    mapping(uint256 => Position) public positions;

    constructor() {}
}
