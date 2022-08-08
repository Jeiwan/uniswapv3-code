// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./UniswapV3Pool.Utils.t.sol";

import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/lib/LiquidityMath.sol";
import "../src/lib/TickMath.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3PoolSwapsTest is Test, UniswapV3PoolUtils {
    ERC20Mintable weth;
    ERC20Mintable usdc;
    UniswapV3Factory factory;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;
    bytes extra;

    function setUp() public {
        usdc = new ERC20Mintable("USDC", "USDC", 18);
        weth = new ERC20Mintable("Ether", "ETH", 18);
        factory = new UniswapV3Factory();

        extra = encodeExtra(address(weth), address(usdc), address(this));
    }

    //  One price range
    //
    //          5000
    //  4545 -----|----- 5500
    //
    function testBuyETHOnePriceRange() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(1 ether), 5000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 42 ether; // 42 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(5004),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            -0.008371593947078468 ether,
            42 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5604422590555458105735383351329, // 5003.830413717752
                tick: 85183,
                currentLiquidity: liquidity[0].amount,
                feeGrowthGlobal0X128: 0,
                feeGrowthGlobal1X128: 27727650748765949686643356806934465 // 0.000081484242041869
            })
        );

        assertPosition(
            ExpectedPosition({
                pool: pool,
                ticks: [liquidity[0].lowerTick, liquidity[0].upperTick],
                liquidity: liquidity[0].amount,
                feeGrowth: [uint256(0), 0],
                tokensOwed: [uint128(0), 0]
            })
        );
    }

    //  Two equal price ranges
    //
    //          5000
    //  4545 -----|----- 5500
    //  4545 -----|----- 5500
    //
    function testBuyETHTwoEqualPriceRanges() public {
        LiquidityRange memory range = liquidityRange(
            4545,
            5500,
            1 ether,
            5000 ether,
            5000
        );
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(2 ether), 10000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(range, range),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 42 ether; // 42 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(5002),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            -0.008373196666644049 ether,
            42 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5603349844017036048802233057296, // 5001.915023528226
                tick: 85180,
                currentLiquidity: liquidity[0].amount + liquidity[1].amount,
                feeGrowthGlobal0X128: 0,
                feeGrowthGlobal1X128: 13863825374382974843321678403467232 // 0.000040742121020935
            })
        );
    }

    //  Consecutive price ranges
    //
    //          5000
    //  4545 -----|----- 5500
    //             5500 ----------- 6250
    //
    function testBuyETHConsecutivePriceRanges() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(2 ether), 10000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000),
                        liquidityRange(5500, 6250, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 10000 ether; // 10000 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(6106),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            -1.806151062659754716 ether,
            9938.146841864722991247 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 6190959796047061453084569894912, // 6106.000000000001
                tick: 87174,
                currentLiquidity: liquidity[1].amount,
                feeGrowthGlobal0X128: 0,
                feeGrowthGlobal1X128: 7607942642143955456943817214090051843 // 0.022357733993050518
            })
        );
    }

    //  Partially overlapping price ranges
    //
    //          5000
    //  4545 -----|----- 5500
    //      5000+1 ----------- 6250
    //
    function testBuyETHPartiallyOverlappingPriceRanges() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(2 ether), 10000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000),
                        liquidityRange(5001, 6250, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 10000 ether; // 10000 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(6056),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            -1.846400936777913635 ether,
            9932.742771767366603035 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 6165559837476377838496291749888, // 6055.999999999999
                tick: 87092,
                currentLiquidity: liquidity[1].amount,
                feeGrowthGlobal0X128: 0,
                feeGrowthGlobal1X128: 7279681885732197095096592710711050900 // 0.021393062331153838
            })
        );
    }

    // Slippage protection doesn't cause a failure but interrupts early.
    function testBuyETHSlippageInterruption() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(1 ether), 5000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 42 ether; // 42 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(5003),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            -0.006557492291469846 ether,
            32.895984173313069971 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: sqrtP(5003),
                tick: tick(5003),
                currentLiquidity: liquidity[0].amount,
                feeGrowthGlobal0X128: 0,
                feeGrowthGlobal1X128: 21717341909394213709358341211545367 // 0.000063821531823423
            })
        );
    }

    //  One price range
    //
    //          5000
    //  4545 -----|----- 5500
    //
    function testBuyUSDCOnePriceRange() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(1 ether), 5000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 0.01337 ether;
        weth.mint(address(this), swapAmount);
        weth.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            true,
            swapAmount,
            sqrtP(4993),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            0.01337 ether,
            -66.608848079558229698 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5598864267980327381293641469695, // 4993.909994249256
                tick: 85164,
                currentLiquidity: liquidity[0].amount,
                feeGrowthGlobal0X128: 8826635488357160650248135250207, // 0.000000025939150383
                feeGrowthGlobal1X128: 0
            })
        );
    }

    //  Two equal price ranges
    //
    //          5000
    //  4545 -----|----- 5500
    //  4545 -----|----- 5500
    //
    function testBuyUSDCTwoEqualPriceRanges() public {
        LiquidityRange memory range = liquidityRange(
            4545,
            5500,
            1 ether,
            5000 ether,
            5000
        );
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(2 ether), 10000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(range, range),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 0.01337 ether;
        weth.mint(address(this), swapAmount);
        weth.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            true,
            swapAmount,
            sqrtP(4996),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            0.01337 ether,
            -66.629142854363394713 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5600570162809008817738050929469, // 4996.953605470648
                tick: 85170,
                currentLiquidity: liquidity[0].amount + liquidity[1].amount,
                feeGrowthGlobal0X128: 4413317744178580325124067625103, // 0.000000012969575192
                feeGrowthGlobal1X128: 0
            })
        );
    }

    //  Consecutive price ranges
    //
    //                     5000
    //             4545 -----|----- 5500
    //  4000 ----------- 4545
    //
    function testBuyUSDCConsecutivePriceRanges() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(2 ether), 10000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000),
                        liquidityRange(4000, 4545, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 2 ether;
        weth.mint(address(this), swapAmount);
        weth.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            true,
            swapAmount,
            sqrtP(4094),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            1.992510070712824953 ether,
            -9052.445703934334276106 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5069364309721000022884193665024, // 4094
                tick: 83176,
                currentLiquidity: liquidity[1].amount,
                feeGrowthGlobal0X128: 1522240169177611694234867497214043, // 0.000004473461798658
                feeGrowthGlobal1X128: 0
            })
        );
    }

    //  Partially overlapping price ranges
    //
    //                5000
    //        4545 -----|----- 5500
    //  4000 ----------- 5000-1
    //
    function testBuyUSDCPartiallyOverlappingPriceRanges() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(2 ether), 10000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000),
                        liquidityRange(4000, 4999, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 2 ether;
        weth.mint(address(this), swapAmount);
        weth.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            true,
            swapAmount,
            sqrtP(4128),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            1.996627649722534946 ether,
            -9282.886546310580739342 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5090370906297125436716365119488, // 4128.0
                tick: 83259,
                currentLiquidity: liquidity[1].amount,
                feeGrowthGlobal0X128: 1456201564392000426097400539712801, // 0.000004279391781503
                feeGrowthGlobal1X128: 0
            })
        );
    }

    // Slippage protection doesn't cause a failure but interrupts early.
    function testBuyUSDCSlippageInterruption() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(1 ether), 5000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 swapAmount = 0.01337 ether;
        weth.mint(address(this), swapAmount);
        weth.approve(address(this), swapAmount);

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(weth.balanceOf(address(this))),
            int256(usdc.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            true,
            swapAmount,
            sqrtP(4994),
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            0.013172223319600129 ether,
            -65.624123301724744142 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: sqrtP(4994),
                tick: tick(4994),
                currentLiquidity: liquidity[0].amount,
                feeGrowthGlobal0X128: 8696066852157821093692702995967, // 0.000000025555443648
                feeGrowthGlobal1X128: 0
            })
        );
    }

    function testSwapBuyEthNotEnoughLiquidity() public {
        LiquidityRange[] memory liquidity = new LiquidityRange[](1);
        liquidity[0] = liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000);
        PoolParams memory params = PoolParams({
            balances: [uint256(1 ether), 5000 ether],
            currentPrice: 5000,
            liquidity: liquidity,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupPool(params);

        uint256 swapAmount = 5300 ether;
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        vm.expectRevert(encodeError("NotEnoughLiquidity()"));
        pool.swap(address(this), false, swapAmount, sqrtP(6000), extra);
    }

    function testSwapBuyUSDCNotEnoughLiquidity() public {
        LiquidityRange[] memory liquidity = new LiquidityRange[](1);
        liquidity[0] = liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000);
        PoolParams memory params = PoolParams({
            balances: [uint256(1 ether), 5000 ether],
            currentPrice: 5000,
            liquidity: liquidity,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupPool(params);

        uint256 swapAmount = 1.1 ether;
        weth.mint(address(this), swapAmount);
        weth.approve(address(this), swapAmount);

        vm.expectRevert(encodeError("NotEnoughLiquidity()"));
        pool.swap(address(this), true, swapAmount, sqrtP(4000), extra);
    }

    function testSwapMixed() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(1 ether), 5000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        uint256 ethAmount = 0.01337 ether;
        weth.mint(address(this), ethAmount);
        weth.approve(address(this), ethAmount);

        uint256 usdcAmount = 55 ether;
        usdc.mint(address(this), usdcAmount);
        usdc.approve(address(this), usdcAmount);

        int256 userBalance0Before = int256(weth.balanceOf(address(this)));
        int256 userBalance1Before = int256(usdc.balanceOf(address(this)));

        (int256 amount0Delta1, int256 amount1Delta1) = pool.swap(
            address(this),
            true,
            ethAmount,
            sqrtP(4993),
            extra
        );

        (int256 amount0Delta2, int256 amount1Delta2) = pool.swap(
            address(this),
            false,
            usdcAmount,
            sqrtP(5004),
            extra
        );

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: weth,
                token1: usdc,
                userBalance0: uint256(
                    userBalance0Before - amount0Delta1 - amount0Delta2
                ),
                userBalance1: uint256(
                    userBalance1Before - amount1Delta1 - amount1Delta2
                ),
                poolBalance0: uint256(
                    int256(poolBalance0) + amount0Delta1 + amount0Delta2
                ),
                poolBalance1: uint256(
                    int256(poolBalance1) + amount1Delta1 + amount1Delta2
                ),
                sqrtPriceX96: 5601673842247623244689987477875, // 4998.923254346182
                tick: 85174,
                currentLiquidity: liquidity[0].amount,
                feeGrowthGlobal0X128: 8826635488357160650248135250207, // 0.000000025939150383
                feeGrowthGlobal1X128: 36310018837669696018223443437652275 // 0.000106705555054829
            })
        );
    }

    function testSwapInsufficientInputAmount() public {
        LiquidityRange[] memory liquidity = new LiquidityRange[](1);
        liquidity[0] = liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000);
        PoolParams memory params = PoolParams({
            balances: [uint256(1 ether), 5000 ether],
            currentPrice: 5000,
            liquidity: liquidity,
            transferInMintCallback: true,
            transferInSwapCallback: false,
            mintLiqudity: true
        });
        setupPool(params);

        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.swap(address(this), false, 42 ether, sqrtP(5004), "");
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // CALLBACKS
    //
    ////////////////////////////////////////////////////////////////////////////
    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        if (transferInSwapCallback) {
            IUniswapV3Pool.CallbackData memory cbData = abi.decode(
                data,
                (IUniswapV3Pool.CallbackData)
            );

            if (amount0 > 0) {
                IERC20(cbData.token0).transferFrom(
                    cbData.payer,
                    msg.sender,
                    uint256(amount0)
                );
            }

            if (amount1 > 0) {
                IERC20(cbData.token1).transferFrom(
                    cbData.payer,
                    msg.sender,
                    uint256(amount1)
                );
            }
        }
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        if (transferInMintCallback) {
            IUniswapV3Pool.CallbackData memory cbData = abi.decode(
                data,
                (IUniswapV3Pool.CallbackData)
            );

            IERC20(cbData.token0).transferFrom(
                cbData.payer,
                msg.sender,
                amount0
            );
            IERC20(cbData.token1).transferFrom(
                cbData.payer,
                msg.sender,
                amount1
            );
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function setupPool(PoolParams memory params)
        internal
        returns (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        )
    {
        weth.mint(address(this), params.balances[0]);
        usdc.mint(address(this), params.balances[1]);

        pool = deployPool(
            factory,
            address(weth),
            address(usdc),
            3000,
            params.currentPrice
        );

        if (params.mintLiqudity) {
            weth.approve(address(this), params.balances[0]);
            usdc.approve(address(this), params.balances[1]);

            uint256 poolBalance0Tmp;
            uint256 poolBalance1Tmp;
            for (uint256 i = 0; i < params.liquidity.length; i++) {
                (poolBalance0Tmp, poolBalance1Tmp) = pool.mint(
                    address(this),
                    params.liquidity[i].lowerTick,
                    params.liquidity[i].upperTick,
                    params.liquidity[i].amount,
                    extra
                );
                poolBalance0 += poolBalance0Tmp;
                poolBalance1 += poolBalance1Tmp;
            }
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
        liquidity = params.liquidity;
    }
}
