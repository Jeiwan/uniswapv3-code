// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

interface IUniswapV3FlashCallback {
    function uniswapV3FlashCallback(bytes calldata data) external;
}
