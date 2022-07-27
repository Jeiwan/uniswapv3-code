// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";

import "../src/UniswapV3Factory.sol";

contract UniswapV3FactoryTest is Test {
    UniswapV3Factory factory;

    function setUp() public {
        factory = new UniswapV3Factory();
    }

    function testCreatePool() public {}
}
