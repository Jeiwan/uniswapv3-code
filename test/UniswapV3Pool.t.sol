// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3PoolTest is Test {
    UniswapV3Pool pool;

    function setUp() public {
        pool = new UniswapV3Pool();
    }

    function testExample() public {
        assertTrue(true);
    }
}
