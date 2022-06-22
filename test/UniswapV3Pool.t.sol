// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "../src/lib/Position.sol";

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

        int24 currentTick = 85176;
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(5602277097478614198912276234240), // current price, sqrt(5000) * 2**96
            currentTick
        );

        (uint256 amount0, uint256 amount1) = pool.mint(
            address(this),
            lowerTick,
            upperTick,
            liquidity
        );

        uint256 expectedAmount0 = 0.998976618347425280 ether;
        uint256 expectedAmount1 = 5000 ether;
        assertEq(amount0, expectedAmount0, "incorrect amount0");
        assertEq(amount1, expectedAmount1, "incorrect amount1");
        assertEq(token0.balanceOf(address(pool)), expectedAmount0);
        assertEq(token1.balanceOf(address(pool)), expectedAmount1);

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), lowerTick, upperTick)
        );
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(posLiquidity, liquidity);

        (bool initialized, uint128 tickLiquidity) = pool.ticks(lowerTick);
        assertTrue(initialized);
        assertEq(tickLiquidity, liquidity);

        (initialized, tickLiquidity) = pool.ticks(upperTick);
        assertTrue(initialized);
        assertEq(tickLiquidity, liquidity);
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) public {
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }
}
