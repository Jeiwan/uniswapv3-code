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
            14143684505937315, // 0.0002 ETH/USDC, 1.0001^(85174/2)
            85174
        );
    }

    function testExample() public {
        assertTrue(true);
    }
}
