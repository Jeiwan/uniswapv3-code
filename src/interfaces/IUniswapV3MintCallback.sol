// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

interface IUniswapV3MintCallback {
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external;
}
