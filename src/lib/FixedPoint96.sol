// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 2**96;
}
