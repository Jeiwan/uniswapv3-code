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
    }

    function testMint() public {
        token0.mint(address(this), 1 ether);
        token1.mint(address(this), 5_000 ether);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(5602277097478614198912276234240), // currentTick, sqrt(5000) << 96
            85176
        );

        (uint256 amount0, uint256 amount1) = pool.mint(
            address(this),
            84222,
            86129,
            1517882343751509868544
        );

        assertEq(amount0, 0.998976618347425280 ether, "incorrect amount0");
        assertEq(amount1, 5000 ether, "incorrect amount1");
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) public {
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }
}
