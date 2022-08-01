// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Manager.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Quoter.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

contract UniswapV3QuoterTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    ERC20Mintable token2;
    UniswapV3Factory factory;
    UniswapV3Pool pool;
    UniswapV3Pool pool2;
    UniswapV3Manager manager;
    UniswapV3Quoter quoter;

    function setUp() public {
        token1 = new ERC20Mintable("USDC", "USDC", 18);
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token2 = new ERC20Mintable("Uniswap Coin", "UNI", 18);
        factory = new UniswapV3Factory();

        uint256 wethBalance = 100 ether;
        uint256 usdcBalance = 1000000 ether;
        uint256 uniBalance = 1000 ether;

        token0.mint(address(this), wethBalance);
        token1.mint(address(this), usdcBalance);
        token2.mint(address(this), uniBalance);

        pool = UniswapV3Pool(
            factory.createPool(address(token0), address(token1), 60)
        );
        pool.initialize(sqrtP(5000));

        pool2 = UniswapV3Pool(
            factory.createPool(address(token0), address(token2), 60)
        );
        pool2.initialize(sqrtP(10));

        manager = new UniswapV3Manager(address(factory));

        token0.approve(address(manager), wethBalance);
        token1.approve(address(manager), usdcBalance);
        token2.approve(address(manager), uniBalance);

        manager.mint(
            IUniswapV3Manager.MintParams({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: 60,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: 1 ether,
                amount1Desired: 5000 ether,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        manager.mint(
            IUniswapV3Manager.MintParams({
                tokenA: address(token0),
                tokenB: address(token2),
                tickSpacing: 60,
                lowerTick: tick60(7),
                upperTick: tick60(13),
                amount0Desired: 10 ether,
                amount1Desired: 100 ether,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        quoter = new UniswapV3Quoter(address(factory));
    }

    function testQuoteUSDCforETH() public {
        (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter) = quoter
            .quoteSingle(
                UniswapV3Quoter.QuoteSingleParams({
                    tokenIn: address(token0),
                    tokenOut: address(token1),
                    tickSpacing: 60,
                    amountIn: 0.01337 ether,
                    sqrtPriceLimitX96: sqrtP(4993)
                })
            );

        assertEq(amountOut, 66.809153442256308009 ether, "invalid amountOut");
        assertEq(
            sqrtPriceX96After,
            5598854004958668990019104567840,
            "invalid sqrtPriceX96After"
        );
        assertEq(tickAfter, 85163, "invalid tickAFter");
    }

    function testQuoteETHforUSDC() public {
        (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter) = quoter
            .quoteSingle(
                UniswapV3Quoter.QuoteSingleParams({
                    tokenIn: address(token1),
                    tokenOut: address(token0),
                    tickSpacing: 60,
                    amountIn: 42 ether,
                    sqrtPriceLimitX96: sqrtP(5005)
                })
            );

        assertEq(amountOut, 0.008396774627565324 ether, "invalid amountOut");
        assertEq(
            sqrtPriceX96After,
            5604429046402228950611610935846,
            "invalid sqrtPriceX96After"
        );
        assertEq(tickAfter, 85183, "invalid tickAFter");
    }

    function testQuoteUNIforUSDCviaETH() public {
        bytes memory path = bytes.concat(
            bytes20(address(token2)),
            bytes3(uint24(60)),
            bytes20(address(token0)),
            bytes3(uint24(60)),
            bytes20(address(token1))
        );
        (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            int24[] memory tickAfterList
        ) = quoter.quote(path, 3 ether);

        assertEq(amountOut, 1472.545906750265423538 ether, "invalid amountOut");
        assertEq(
            sqrtPriceX96AfterList[0],
            251775459842086338964371349270,
            "invalid sqrtPriceX96After"
        );
        assertEq(
            sqrtPriceX96AfterList[1],
            5526828440835641442172064165001,
            "invalid sqrtPriceX96After"
        );
        assertEq(tickAfterList[0], 23125, "invalid tickAFter");
        assertEq(tickAfterList[1], 84904, "invalid tickAFter");
    }

    function testQuoteAndSwapUSDCforETH() public {
        uint256 amountIn = 0.01337 ether;
        (uint256 amountOut, , ) = quoter.quoteSingle(
            UniswapV3Quoter.QuoteSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                tickSpacing: 60,
                amountIn: amountIn,
                sqrtPriceLimitX96: sqrtP(4993)
            })
        );

        IUniswapV3Manager.SwapSingleParams memory swapParams = IUniswapV3Manager
            .SwapSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                tickSpacing: 60,
                amountIn: amountIn,
                sqrtPriceLimitX96: sqrtP(4993)
            });
        uint256 amountOutActual = manager.swapSingle(swapParams);

        assertEq(amountOutActual, amountOut, "invalid amount1Delta");
    }

    function testQuoteAndSwapETHforUSDC() public {
        uint256 amountIn = 55 ether;
        (uint256 amountOut, , ) = quoter.quoteSingle(
            UniswapV3Quoter.QuoteSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                tickSpacing: 60,
                amountIn: amountIn,
                sqrtPriceLimitX96: sqrtP(5010)
            })
        );

        IUniswapV3Manager.SwapSingleParams memory swapParams = IUniswapV3Manager
            .SwapSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                tickSpacing: 60,
                amountIn: amountIn,
                sqrtPriceLimitX96: sqrtP(5010)
            });
        uint256 amountOutActual = manager.swapSingle(swapParams);

        assertEq(amountOutActual, amountOut, "invalid amount0Delta");
    }
}
