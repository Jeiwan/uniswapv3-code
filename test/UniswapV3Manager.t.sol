// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {Test, stdError} from "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

import "../src/lib/LiquidityMath.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Manager.sol";

contract UniswapV3ManagerTest is Test, TestUtils {
    ERC20Mintable weth;
    ERC20Mintable usdc;
    ERC20Mintable uni;
    UniswapV3Factory factory;
    UniswapV3Pool pool;
    UniswapV3Manager manager;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;
    bytes extra;

    function setUp() public {
        usdc = new ERC20Mintable("USDC", "USDC", 18);
        weth = new ERC20Mintable("Ether", "ETH", 18);
        uni = new ERC20Mintable("Uniswap Coin", "UNI", 18);
        factory = new UniswapV3Factory();
        manager = new UniswapV3Manager(address(factory));

        extra = encodeExtra(address(weth), address(usdc), address(this));
    }

    function testMintInRange() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.987286567250950170 ether,
            4998.958915878679752572 ether
        );

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect weth deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect usdc deposited amount"
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[0].lowerTick,
                upperTick: mints[0].upperTick,
                position: Position.Info({
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintRangeBelow() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4000, 4996, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0 ether,
            4999.999999999999999994 ether
        );

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect weth deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect usdc deposited amount"
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[0].lowerTick,
                upperTick: mints[0].upperTick,
                position: Position.Info({
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintRangeAbove() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(5027, 6250, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 10 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        (uint256 expectedAmount0, uint256 expectedAmount1) = (1 ether, 0);

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect weth deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect usdc deposited amount"
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: mints[0].lowerTick,
                upperTick: mints[0].upperTick,
                position: Position.Info({
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    //
    //          5000
    //   4545 ----|---- 5500
    // 4000 ------|------ 6250
    //
    function testMintOverlappingRanges() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](2);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        mints[1] = mintParams(
            4000,
            6250,
            (1 ether * 75) / 100,
            (5000 ether * 75) / 100
        );
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 3 ether,
            usdcBalance: 15000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupTestCase(params);

        (uint256 amount0, uint256 amount1) = (
            1.733464437577149733 ether,
            8748.624200287228469107 ether
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                position: Position.Info({
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity(mints[0], 5000) +
                    liquidity(mints[1], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick60(4000),
                upperTick: tick60(6250),
                position: Position.Info({
                    liquidity: liquidity(mints[1], 5000),
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity(mints[0], 5000) +
                    liquidity(mints[1], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    //
    //          5000
    //   4545 ----|---- 5500
    // 4000 ------ ------ 6250
    //      5000-1 5000+1
    function testMintPartiallyOverlappingRanges() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](3);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        mints[1] = mintParams(
            4000,
            4996,
            (1 ether * 75) / 100,
            (5000 ether * 75) / 100
        );
        mints[2] = mintParams(
            5027,
            6250,
            (1 ether * 50) / 100,
            (5000 ether * 50) / 100
        );
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 3 ether,
            usdcBalance: 15000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupTestCase(params);

        (uint256 amount0, uint256 amount1) = (
            1.487286567250950170 ether,
            8748.958915878679752566 ether
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                position: Position.Info({
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick60(4000),
                upperTick: tick60(4996),
                position: Position.Info({
                    liquidity: liquidity(mints[1], 5000),
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick60(5027),
                upperTick: tick60(6250),
                position: Position.Info({
                    liquidity: liquidity(mints[2], 5000),
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintInvalidTickRangeLower() public {
        pool = deployPool(factory, address(weth), address(usdc), 3000, 1);
        manager = new UniswapV3Manager(address(factory));

        // Reverted in TickMath.getSqrtRatioAtTick
        vm.expectRevert(bytes("T"));
        manager.mint(
            IUniswapV3Manager.MintParams({
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: 3000,
                lowerTick: -887273,
                upperTick: 0,
                amount0Desired: 0,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function testMintInvalidTickRangeUpper() public {
        pool = deployPool(factory, address(weth), address(usdc), 3000, 1);
        manager = new UniswapV3Manager(address(factory));

        // Reverted in TickMath.getSqrtRatioAtTick
        vm.expectRevert(bytes("T"));
        manager.mint(
            IUniswapV3Manager.MintParams({
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: 3000,
                lowerTick: 0,
                upperTick: 887273,
                amount0Desired: 0,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function testMintZeroLiquidity() public {
        pool = deployPool(factory, address(weth), address(usdc), 3000, 1);
        manager = new UniswapV3Manager(address(factory));

        vm.expectRevert(encodeError("ZeroLiquidity()"));
        manager.mint(
            IUniswapV3Manager.MintParams({
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: 3000,
                lowerTick: 0,
                upperTick: 1,
                amount0Desired: 0,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0
            })
        );
    }

    function testMintInsufficientTokenBalance() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 0,
            usdcBalance: 0,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: false,
            transferInSwapCallback: true,
            mintLiqudity: false
        });
        setupTestCase(params);

        vm.expectRevert(stdError.arithmeticError);
        manager.mint(mints[0]);
    }

    function testMintSlippageProtection() public {
        (uint256 amount0, uint256 amount1) = (1 ether, 5000 ether);
        pool = deployPool(factory, address(weth), address(usdc), 3000, 5000);
        manager = new UniswapV3Manager(address(factory));

        weth.mint(address(this), amount0);
        usdc.mint(address(this), amount1);
        weth.approve(address(manager), amount0);
        usdc.approve(address(manager), amount1);

        vm.expectRevert(
            encodeSlippageCheckFailed(
                0.987286567250950170 ether,
                4998.958915878679752572 ether
            )
        );
        manager.mint(
            IUniswapV3Manager.MintParams({
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: 3000,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0,
                amount1Min: amount1
            })
        );

        manager.mint(
            IUniswapV3Manager.MintParams({
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: 3000,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: (amount0 * 98) / 100,
                amount1Min: (amount1 * 98) / 100
            })
        );
    }

    function testSwapBuyEth() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 swapAmount = 42 ether; // 42 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(manager), swapAmount);

        (uint256 userBalance0Before, uint256 userBalance1Before) = (
            weth.balanceOf(address(this)),
            usdc.balanceOf(address(this))
        );

        uint256 amountOut = manager.swapSingle(
            IUniswapV3Manager.SwapSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(weth),
                fee: 3000,
                amountIn: swapAmount,
                sqrtPriceLimitX96: sqrtP(5004)
            })
        );

        uint256 expectedAmountOut = 0.008371593947078468 ether;

        assertEq(amountOut, expectedAmountOut, "invalid ETH out");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: userBalance0Before + amountOut,
                userBalance1: userBalance1Before - swapAmount,
                poolBalance0: poolBalance0 - amountOut,
                poolBalance1: poolBalance1 + swapAmount,
                sqrtPriceX96: 5604422590555458105735383351329, // 5003.830413717752
                tick: 85183,
                currentLiquidity: liquidity(mints[0], 5000),
                feeGrowthGlobal0X128: 0,
                feeGrowthGlobal1X128: 27727650748765949686643356806934465 // 0.000081484242041869
            })
        );
    }

    function testSwapBuyUSDC() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 swapAmount = 0.01337 ether;
        weth.mint(address(this), swapAmount);
        weth.approve(address(manager), swapAmount);

        (uint256 userBalance0Before, uint256 userBalance1Before) = (
            weth.balanceOf(address(this)),
            usdc.balanceOf(address(this))
        );

        uint256 amountOut = manager.swapSingle(
            IUniswapV3Manager.SwapSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdc),
                fee: 3000,
                amountIn: swapAmount,
                sqrtPriceLimitX96: sqrtP(4993)
            })
        );

        uint256 expectedAmountOut = 66.608848079558229698 ether;

        assertEq(amountOut, expectedAmountOut, "invalid ETH out");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: userBalance0Before - swapAmount,
                userBalance1: userBalance1Before + amountOut,
                poolBalance0: poolBalance0 + swapAmount,
                poolBalance1: poolBalance1 - amountOut,
                sqrtPriceX96: 5598864267980327381293641469695, // 4993.909994249256
                tick: 85164,
                currentLiquidity: liquidity(mints[0], 5000),
                feeGrowthGlobal0X128: 8826635488357160650248135250207, // 0.000000025939150383
                feeGrowthGlobal1X128: 0
            })
        );
    }

    function testSwapBuyMultipool() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        // Deploy WETH/UNI pool
        weth.mint(address(this), 10 ether);
        weth.approve(address(manager), 10 ether);
        uni.mint(address(this), 100 ether);
        uni.approve(address(manager), 100 ether);
        UniswapV3Pool wethUNI = deployPool(
            factory,
            address(weth),
            address(uni),
            3000,
            10
        );
        manager.mint(
            mintParams(address(weth), address(uni), 7, 13, 10 ether, 100 ether)
        );

        uint256 swapAmount = 2.5 ether;
        uni.mint(address(this), swapAmount);
        uni.approve(address(manager), swapAmount);

        bytes memory path = bytes.concat(
            bytes20(address(uni)),
            bytes3(uint24(3000)),
            bytes20(address(weth)),
            bytes3(uint24(3000)),
            bytes20(address(usdc))
        );

        (
            uint256 userBalance0Before,
            uint256 userBalance1Before,
            uint256 userBalance2Before
        ) = (
                weth.balanceOf(address(this)),
                usdc.balanceOf(address(this)),
                uni.balanceOf(address(this))
            );

        uint256 amountOut = manager.swap(
            IUniswapV3Manager.SwapParams({
                path: path,
                recipient: address(this),
                amountIn: swapAmount,
                minAmountOut: 0
            })
        );

        uint256 expectedAmountOut = 1223.599499987434636079 ether;
        assertEq(amountOut, expectedAmountOut, "invalid USDC out");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: userBalance0Before,
                userBalance1: userBalance1Before + expectedAmountOut,
                poolBalance0: poolBalance0 + 0.248234183855004780 ether, // initial + 2.5 UNI sold for ETH
                poolBalance1: poolBalance1 - expectedAmountOut,
                sqrtPriceX96: 5539583677789714904047360872750, // 4888.719128166855
                tick: 84951,
                currentLiquidity: liquidity(mints[0], 5000),
                feeGrowthGlobal0X128: 163879779853250804931705964313699,
                feeGrowthGlobal1X128: 0
            })
        );

        assertEq(
            uni.balanceOf(address(this)),
            userBalance2Before - swapAmount,
            "invalid user UNI balance"
        );
        assertEq(
            uni.balanceOf(address(wethUNI)),
            102.499932902940812596 ether, // 100 UNI minted + 2.5 UNI swapped
            "invalid pool UNI balance"
        );

        (uint160 sqrtPriceX96, int24 currentTick) = wethUNI.slot0();
        assertEq(
            sqrtPriceX96,
            251566706235579008314845847774, // 10.082010831439806
            "invalid current sqrtP"
        );
        assertEq(currentTick, 23108, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1546311247949719370887,
            "invalid current liquidity"
        );
    }

    function testSwapMixed() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 ethAmount = 0.01337 ether;
        weth.mint(address(this), ethAmount);
        weth.approve(address(manager), ethAmount);

        uint256 usdcAmount = 55 ether;
        usdc.mint(address(this), usdcAmount);
        usdc.approve(address(manager), usdcAmount);

        uint256 userBalance0Before = weth.balanceOf(address(this));
        uint256 userBalance1Before = usdc.balanceOf(address(this));

        uint256 amountOut1 = manager.swapSingle(
            IUniswapV3Manager.SwapSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdc),
                fee: 3000,
                amountIn: ethAmount,
                sqrtPriceLimitX96: sqrtP(4990)
            })
        );

        uint256 amountOut2 = manager.swapSingle(
            IUniswapV3Manager.SwapSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(weth),
                fee: 3000,
                amountIn: usdcAmount,
                sqrtPriceLimitX96: sqrtP(5004)
            })
        );

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: userBalance0Before - ethAmount + amountOut2,
                userBalance1: userBalance1Before - usdcAmount + amountOut1,
                poolBalance0: poolBalance0 + ethAmount - amountOut2,
                poolBalance1: poolBalance1 + usdcAmount - amountOut1,
                sqrtPriceX96: 5601673842247623244689987477875, // 4998.923254346182
                tick: 85174,
                currentLiquidity: liquidity(mints[0], 5000),
                feeGrowthGlobal0X128: 8826635488357160650248135250207, // 0.000000025939150383
                feeGrowthGlobal1X128: 36310018837669696018223443437652275 // 0.000106705555054829
            })
        );
    }

    function testSwapBuyEthNotEnoughLiquidity() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupTestCase(params);

        uint256 swapAmount = 5300 ether;
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        vm.expectRevert(encodeError("NotEnoughLiquidity()"));
        manager.swapSingle(
            IUniswapV3Manager.SwapSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdc),
                fee: 3000,
                amountIn: swapAmount,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function testSwapBuyUSDCNotEnoughLiquidity() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupTestCase(params);

        uint256 swapAmount = 1.1 ether;
        weth.mint(address(this), swapAmount);
        weth.approve(address(this), swapAmount);

        vm.expectRevert(encodeError("NotEnoughLiquidity()"));
        manager.swapSingle(
            IUniswapV3Manager.SwapSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdc),
                fee: 3000,
                amountIn: swapAmount,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function testSwapInsufficientInputAmount() public {
        IUniswapV3Manager.MintParams[]
            memory mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mintParams(4545, 5500, 1 ether, 5000 ether);
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentPrice: 5000,
            mints: mints,
            transferInMintCallback: true,
            transferInSwapCallback: false,
            mintLiqudity: true
        });
        setupTestCase(params);

        vm.expectRevert(stdError.arithmeticError);
        manager.swapSingle(
            IUniswapV3Manager.SwapSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(weth),
                fee: 3000,
                amountIn: 42 ether,
                sqrtPriceLimitX96: sqrtP(5010)
            })
        );
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        uint256 currentPrice;
        IUniswapV3Manager.MintParams[] mints;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiqudity;
    }

    function mintParams(
        uint256 lowerPrice,
        uint256 upperPrice,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (IUniswapV3Manager.MintParams memory params) {
        params = mintParams(
            address(weth),
            address(usdc),
            lowerPrice,
            upperPrice,
            amount0,
            amount1
        );
    }

    function liquidity(
        IUniswapV3Manager.MintParams memory params,
        uint256 currentPrice
    ) internal pure returns (uint128 liquidity_) {
        liquidity_ = LiquidityMath.getLiquidityForAmounts(
            sqrtP(currentPrice),
            sqrtP60FromTick(params.lowerTick),
            sqrtP60FromTick(params.upperTick),
            params.amount0Desired,
            params.amount1Desired
        );
    }

    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        weth.mint(address(this), params.wethBalance);
        usdc.mint(address(this), params.usdcBalance);

        pool = deployPool(
            factory,
            address(weth),
            address(usdc),
            3000,
            params.currentPrice
        );

        if (params.mintLiqudity) {
            weth.approve(address(manager), params.wethBalance);
            usdc.approve(address(manager), params.usdcBalance);

            uint256 poolBalance0Tmp;
            uint256 poolBalance1Tmp;
            for (uint256 i = 0; i < params.mints.length; i++) {
                (poolBalance0Tmp, poolBalance1Tmp) = manager.mint(
                    params.mints[i]
                );
                poolBalance0 += poolBalance0Tmp;
                poolBalance1 += poolBalance1Tmp;
            }
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
    }
}
