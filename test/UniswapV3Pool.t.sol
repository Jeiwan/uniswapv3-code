// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(5602277097478614198912276234240), // currentTick, sqrt(5000) << 96
            85176
        );
    }

    function testExample() public {
        assertTrue(true);
    }
}
