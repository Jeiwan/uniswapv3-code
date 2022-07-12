// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Quoter.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Manager.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

contract UniswapV3QuoterTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;
    UniswapV3Manager manager;
    UniswapV3Quoter quoter;

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);

        uint256 wethBalance = 100 ether;
        uint256 usdcBalance = 1000000 ether;

        token0.mint(address(this), wethBalance);
        token1.mint(address(this), usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            5602277097478614198912276234240,
            85176
        );

        manager = new UniswapV3Manager();

        token0.approve(address(manager), wethBalance);
        token1.approve(address(manager), usdcBalance);

        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;
        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        manager.mint(address(pool), lowerTick, upperTick, liquidity, extra);

        quoter = new UniswapV3Quoter();
    }

    function testQuoteUSDCforETH() public {
        (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter) = quoter
            .quote(
                UniswapV3Quoter.QuoteParams({
                    pool: address(pool),
                    amountIn: 0.01337 ether,
                    zeroForOne: true
                })
            );

        assertEq(amountOut, 66.808388890199406685 ether, "invalid amountOut");
        assertEq(
            sqrtPriceX96After,
            5598789932670288701514545755210,
            "invalid sqrtPriceX96After"
        );
        assertEq(tickAfter, 85163, "invalid tickAFter");
    }

    function testQuoteETHforUSDC() public {
        (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter) = quoter
            .quote(
                UniswapV3Quoter.QuoteParams({
                    pool: address(pool),
                    amountIn: 42 ether,
                    zeroForOne: false
                })
            );

        assertEq(amountOut, 0.008396714242162445 ether, "invalid amountOut");
        assertEq(
            sqrtPriceX96After,
            5604469350942327889444743441197,
            "invalid sqrtPriceX96After"
        );
        assertEq(tickAfter, 85184, "invalid tickAFter");
    }

    function testQuoteAndSwapUSDCforETH() public {
        uint256 amountIn = 0.01337 ether;
        (uint256 amountOut, , ) = quoter.quote(
            UniswapV3Quoter.QuoteParams({
                pool: address(pool),
                amountIn: amountIn,
                zeroForOne: true
            })
        );

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        (int256 amount0Delta, int256 amount1Delta) = manager.swap(
            address(pool),
            true,
            amountIn,
            extra
        );

        assertEq(uint256(amount0Delta), amountIn, "invalid amount0Delta");
        assertEq(uint256(-amount1Delta), amountOut, "invalid amount1Delta");
    }

    function testQuoteAndSwapETHforUSDC() public {
        uint256 amountIn = 55 ether;
        (uint256 amountOut, , ) = quoter.quote(
            UniswapV3Quoter.QuoteParams({
                pool: address(pool),
                amountIn: amountIn,
                zeroForOne: false
            })
        );

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        (int256 amount0Delta, int256 amount1Delta) = manager.swap(
            address(pool),
            false,
            amountIn,
            extra
        );

        assertEq(uint256(-amount0Delta), amountOut, "invalid amount0Delta");
        assertEq(uint256(amount1Delta), amountIn, "invalid amount1Delta");
    }
}
