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
        (
            IUniswapV3Manager.MintParams[] memory mints,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    wethBalance: 1 ether,
                    usdcBalance: 5000 ether,
                    currentPrice: 5000,
                    mints: mintParams(
                        mintParams(4545, 5500, 1 ether, 5000 ether)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiquidity: true
                })
            );

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.987078348444137445 ether,
            5000 ether
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

        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000),
                fees: [uint256(0), 0],
                userBalances: [
                    1 ether - expectedAmount0,
                    5000 ether - expectedAmount1
                ],
                poolBalances: [expectedAmount0, expectedAmount1],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[0].lowerTick, mints[0].upperTick],
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[0], 5000),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    function testMintRangeBelow() public {
        (
            IUniswapV3Manager.MintParams[] memory mints,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    wethBalance: 1 ether,
                    usdcBalance: 5000 ether,
                    currentPrice: 5000,
                    mints: mintParams(
                        mintParams(4000, 4996, 1 ether, 5000 ether)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiquidity: true
                })
            );

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

        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000),
                fees: [uint256(0), 0],
                userBalances: [
                    1 ether - expectedAmount0,
                    5000 ether - expectedAmount1
                ],
                poolBalances: [expectedAmount0, expectedAmount1],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[0].lowerTick, mints[0].upperTick],
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[0], 5000),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    function testMintRangeAbove() public {
        (
            IUniswapV3Manager.MintParams[] memory mints,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    wethBalance: 1 ether,
                    usdcBalance: 5000 ether,
                    currentPrice: 5000,
                    mints: mintParams(
                        mintParams(5027, 6250, 1 ether, 5000 ether)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiquidity: true
                })
            );

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

        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000),
                fees: [uint256(0), 0],
                userBalances: [
                    1 ether - expectedAmount0,
                    5000 ether - expectedAmount1
                ],
                poolBalances: [expectedAmount0, expectedAmount1],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[0].lowerTick, mints[0].upperTick],
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[0], 5000),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    //
    //          5000
    //   4545 ----|---- 5500
    // 4000 ------|------ 6250
    //
    function testMintOverlappingRanges() public {
        (IUniswapV3Manager.MintParams[] memory mints, , ) = setupPool(
            PoolParams({
                wethBalance: 3 ether,
                usdcBalance: 15000 ether,
                currentPrice: 5000,
                mints: mintParams(
                    mintParams(4545, 5500, 1 ether, 5000 ether),
                    mintParams(
                        4000,
                        6250,
                        (1 ether * 75) / 100,
                        (5000 ether * 75) / 100
                    )
                ),
                transferInMintCallback: true,
                transferInSwapCallback: true,
                mintLiquidity: true
            })
        );

        (uint256 amount0, uint256 amount1) = (
            1.733189275014643934 ether,
            8750.000000000000000000 ether
        );

        assertMany(
            ExpectedPoolAndBalances({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity(mints[0], 5000) +
                    liquidity(mints[1], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000),
                fees: [uint256(0), 0],
                userBalances: [3 ether - amount0, 15000 ether - amount1],
                poolBalances: [amount0, amount1]
            })
        );

        assertMany(
            ExpectedPositionAndTicks({
                pool: pool,
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[0].lowerTick, mints[0].upperTick],
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[0], 5000)
            })
        );

        assertMany(
            ExpectedPositionAndTicks({
                pool: pool,
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[1].lowerTick, mints[1].upperTick],
                    liquidity: liquidity(mints[1], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[1], 5000)
            })
        );

        assertObservation(
            ExpectedObservation({
                pool: pool,
                index: 0,
                timestamp: 1,
                tickCumulative: 0,
                initialized: true
            })
        );
    }

    //
    //          5000
    //   4545 ----|---- 5500
    // 4000 ------ ------ 6250
    //      5000-1 5000+1
    function testMintPartiallyOverlappingRanges() public {
        (IUniswapV3Manager.MintParams[] memory mints, , ) = setupPool(
            PoolParams({
                wethBalance: 3 ether,
                usdcBalance: 15000 ether,
                currentPrice: 5000,
                mints: mintParams(
                    mintParams(4545, 5500, 1 ether, 5000 ether),
                    mintParams(
                        4000,
                        4996,
                        (1 ether * 75) / 100,
                        (5000 ether * 75) / 100
                    ),
                    mintParams(
                        5027,
                        6250,
                        (1 ether * 50) / 100,
                        (5000 ether * 50) / 100
                    )
                ),
                transferInMintCallback: true,
                transferInSwapCallback: true,
                mintLiquidity: true
            })
        );

        (uint256 amount0, uint256 amount1) = (
            1.487078348444137445 ether,
            8749.999999999999999994 ether
        );

        assertMany(
            ExpectedPoolAndBalances({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000),
                fees: [uint256(0), 0],
                userBalances: [3 ether - amount0, 15000 ether - amount1],
                poolBalances: [amount0, amount1]
            })
        );

        assertMany(
            ExpectedPositionAndTicks({
                pool: pool,
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[0].lowerTick, mints[0].upperTick],
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[0], 5000)
            })
        );

        assertMany(
            ExpectedPositionAndTicks({
                pool: pool,
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[1].lowerTick, mints[1].upperTick],
                    liquidity: liquidity(mints[1], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[1], 5000)
            })
        );

        assertObservation(
            ExpectedObservation({
                pool: pool,
                index: 0,
                timestamp: 1,
                tickCumulative: 0,
                initialized: true
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
        (IUniswapV3Manager.MintParams[] memory mints, , ) = setupPool(
            PoolParams({
                wethBalance: 0,
                usdcBalance: 0,
                currentPrice: 5000,
                mints: mintParams(mintParams(4545, 5500, 1 ether, 5000 ether)),
                transferInMintCallback: false,
                transferInSwapCallback: true,
                mintLiquidity: false
            })
        );

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
            encodeSlippageCheckFailed(0.987078348444137445 ether, 5000 ether)
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
        (
            IUniswapV3Manager.MintParams[] memory mints,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    wethBalance: 1 ether,
                    usdcBalance: 5000 ether,
                    currentPrice: 5000,
                    mints: mintParams(
                        mintParams(4545, 5500, 1 ether, 5000 ether)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiquidity: true
                })
            );

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

        uint256 expectedAmountOut = 0.008371593947078467 ether;

        assertEq(amountOut, expectedAmountOut, "invalid ETH out");

        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: 5604422590555458105735383351329, // 5003.830413717752
                tick: 85183,
                fees: [
                    uint256(0),
                    27727650748765949686643356806934465 // 0.000081484242041869
                ],
                userBalances: [
                    userBalance0Before + amountOut,
                    userBalance1Before - swapAmount
                ],
                poolBalances: [
                    poolBalance0 - amountOut,
                    poolBalance1 + swapAmount
                ],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[0].lowerTick, mints[0].upperTick],
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[0], 5000),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    function testSwapBuyUSDC() public {
        (
            IUniswapV3Manager.MintParams[] memory mints,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    wethBalance: 1 ether,
                    usdcBalance: 5000 ether,
                    currentPrice: 5000,
                    mints: mintParams(
                        mintParams(4545, 5500, 1 ether, 5000 ether)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiquidity: true
                })
            );

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

        uint256 expectedAmountOut = 66.608848079558229697 ether;

        assertEq(amountOut, expectedAmountOut, "invalid ETH out");

        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: 5598864267980327381293641469695, // 4993.909994249256
                tick: 85164,
                fees: [
                    uint256(8826635488357160650248135250207), // 0.000000025939150383
                    0
                ],
                userBalances: [
                    userBalance0Before - swapAmount,
                    userBalance1Before + amountOut
                ],
                poolBalances: [
                    poolBalance0 + swapAmount,
                    poolBalance1 - amountOut
                ],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[0].lowerTick, mints[0].upperTick],
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[0], 5000),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    function testSwapBuyMultipool() public {
        // Deploy WETH/USDC pool
        (
            IUniswapV3Manager.MintParams[] memory mints,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    wethBalance: 1 ether,
                    usdcBalance: 5000 ether,
                    currentPrice: 5000,
                    mints: mintParams(
                        mintParams(4545, 5500, 1 ether, 5000 ether)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiquidity: true
                })
            );

        // Deploy WETH/UNI pool
        (
            UniswapV3Pool wethUNI,
            IUniswapV3Manager.MintParams[] memory wethUNIMints,
            uint256 wethUNIBalance0,
            uint256 wethUNIBalance1
        ) = setupPool(
                PoolParamsFull({
                    token0: weth,
                    token1: uni,
                    token0Balance: 10 ether,
                    token1Balance: 100 ether,
                    currentPrice: 10,
                    mints: mintParams(
                        mintParams(weth, uni, 7, 13, 10 ether, 100 ether)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiquidity: true
                })
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

        uint256[] memory userBalances = new uint256[](3);
        (userBalances[0], userBalances[1], userBalances[2]) = (
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

        assertEq(amountOut, 1223.599499987434631189 ether, "invalid USDC out");

        IUniswapV3Manager.MintParams memory mint = mints[0];
        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity(mint, 5000),
                sqrtPriceX96: 5539583677789714904297843583839, // 4888.719128166855
                tick: 84951,
                fees: [
                    uint256(163879779853250804931705964313699), // 0.000000481599388579
                    0
                ],
                userBalances: [userBalances[0], userBalances[1] + amountOut],
                poolBalances: [
                    poolBalance0 + 0.248234183855004779 ether, // initial + 2.5 UNI sold for ETH
                    poolBalance1 - amountOut
                ],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mint.lowerTick, mint.upperTick],
                    liquidity: liquidity(mint, 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mint, 5000),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );

        mint = wethUNIMints[0];
        assertMany(
            ExpectedMany({
                pool: wethUNI,
                tokens: [weth, uni],
                liquidity: liquidity(mint, 10),
                sqrtPriceX96: 251566706235579008314845847774, // 10.082010831439806
                tick: 23108,
                fees: [
                    uint256(0),
                    13250097234547358482322170106940574 // 0.000038938536117641
                ],
                userBalances: [userBalances[0], userBalances[2] - swapAmount],
                poolBalances: [
                    wethUNIBalance0 - 0.248234183855004779 ether,
                    wethUNIBalance1 + swapAmount
                ],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mint.lowerTick, mint.upperTick],
                    liquidity: liquidity(mint, 10),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mint, 10),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    function testSwapMixed() public {
        (
            IUniswapV3Manager.MintParams[] memory mints,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    wethBalance: 1 ether,
                    usdcBalance: 5000 ether,
                    currentPrice: 5000,
                    mints: mintParams(
                        mintParams(4545, 5500, 1 ether, 5000 ether)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiquidity: true
                })
            );

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

        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity(mints[0], 5000),
                sqrtPriceX96: 5601673842247623244689987477875, // 4998.923254346182
                tick: 85174,
                fees: [
                    uint256(8826635488357160650248135250207), // 0.000000025939150383
                    36310018837669696018223443437652275 // 0.000106705555054829
                ],
                userBalances: [
                    userBalance0Before - ethAmount + amountOut2,
                    userBalance1Before - usdcAmount + amountOut1
                ],
                poolBalances: [
                    poolBalance0 + ethAmount - amountOut2,
                    poolBalance1 + usdcAmount - amountOut1
                ],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [mints[0].lowerTick, mints[0].upperTick],
                    liquidity: liquidity(mints[0], 5000),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(mints[0], 5000),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    function testSwapBuyEthNotEnoughLiquidity() public {
        setupPool(
            PoolParams({
                wethBalance: 1 ether,
                usdcBalance: 5000 ether,
                currentPrice: 5000,
                mints: mintParams(mintParams(4545, 5500, 1 ether, 5000 ether)),
                transferInMintCallback: true,
                transferInSwapCallback: true,
                mintLiquidity: true
            })
        );

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
        setupPool(
            PoolParams({
                wethBalance: 1 ether,
                usdcBalance: 5000 ether,
                currentPrice: 5000,
                mints: mintParams(mintParams(4545, 5500, 1 ether, 5000 ether)),
                transferInMintCallback: true,
                transferInSwapCallback: true,
                mintLiquidity: true
            })
        );

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
        setupPool(
            PoolParams({
                wethBalance: 1 ether,
                usdcBalance: 5000 ether,
                currentPrice: 5000,
                mints: mintParams(mintParams(4545, 5500, 1 ether, 5000 ether)),
                transferInMintCallback: true,
                transferInSwapCallback: false,
                mintLiquidity: true
            })
        );

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

    function testGetPosition() public {
        (IUniswapV3Manager.MintParams[] memory mints, , ) = setupPool(
            PoolParams({
                wethBalance: 1 ether,
                usdcBalance: 5000 ether,
                currentPrice: 5000,
                mints: mintParams(mintParams(4545, 5500, 1 ether, 5000 ether)),
                transferInMintCallback: true,
                transferInSwapCallback: true,
                mintLiquidity: true
            })
        );

        (
            uint128 liquidity_,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = manager.getPosition(
                IUniswapV3Manager.GetPositionParams({
                    tokenA: address(weth),
                    tokenB: address(usdc),
                    fee: 3000,
                    owner: address(this),
                    lowerTick: mints[0].lowerTick,
                    upperTick: mints[0].upperTick
                })
            );

        assertPosition(
            ExpectedPosition({
                owner: address(this),
                pool: pool,
                ticks: [mints[0].lowerTick, mints[0].upperTick],
                liquidity: liquidity_,
                feeGrowth: [feeGrowthInside0LastX128, feeGrowthInside1LastX128],
                tokensOwed: [tokensOwed0, tokensOwed1]
            })
        );
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    struct PoolParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        uint256 currentPrice;
        IUniswapV3Manager.MintParams[] mints;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiquidity;
    }

    struct PoolParamsFull {
        ERC20Mintable token0;
        ERC20Mintable token1;
        uint256 token0Balance;
        uint256 token1Balance;
        uint256 currentPrice;
        IUniswapV3Manager.MintParams[] mints;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiquidity;
    }

    function mintParams(
        ERC20Mintable token0,
        ERC20Mintable token1,
        uint256 lowerPrice,
        uint256 upperPrice,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (IUniswapV3Manager.MintParams memory params) {
        params = mintParams(
            address(token0),
            address(token1),
            lowerPrice,
            upperPrice,
            amount0,
            amount1
        );
    }

    function mintParams(
        uint256 lowerPrice,
        uint256 upperPrice,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (IUniswapV3Manager.MintParams memory params) {
        params = mintParams(
            weth,
            usdc,
            lowerPrice,
            upperPrice,
            amount0,
            amount1
        );
    }

    function mintParams(IUniswapV3Manager.MintParams memory mint)
        internal
        pure
        returns (IUniswapV3Manager.MintParams[] memory mints)
    {
        mints = new IUniswapV3Manager.MintParams[](1);
        mints[0] = mint;
    }

    function mintParams(
        IUniswapV3Manager.MintParams memory mint1,
        IUniswapV3Manager.MintParams memory mint2
    ) internal pure returns (IUniswapV3Manager.MintParams[] memory mints) {
        mints = new IUniswapV3Manager.MintParams[](2);
        mints[0] = mint1;
        mints[1] = mint2;
    }

    function mintParams(
        IUniswapV3Manager.MintParams memory mint1,
        IUniswapV3Manager.MintParams memory mint2,
        IUniswapV3Manager.MintParams memory mint3
    ) internal pure returns (IUniswapV3Manager.MintParams[] memory mints) {
        mints = new IUniswapV3Manager.MintParams[](3);
        mints[0] = mint1;
        mints[1] = mint2;
        mints[2] = mint3;
    }

    function mintParamsToTicks(
        IUniswapV3Manager.MintParams memory mint,
        uint256 currentPrice
    ) internal pure returns (ExpectedTickShort[2] memory ticks) {
        uint128 liq = liquidity(mint, currentPrice);

        ticks[0] = ExpectedTickShort({
            tick: mint.lowerTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: int128(liq)
        });
        ticks[1] = ExpectedTickShort({
            tick: mint.upperTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: -int128(liq)
        });
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

    function setupPool(PoolParamsFull memory params)
        internal
        returns (
            UniswapV3Pool pool_,
            IUniswapV3Manager.MintParams[] memory mints_,
            uint256 poolBalance0,
            uint256 poolBalance1
        )
    {
        params.token0.mint(address(this), params.token0Balance);
        params.token1.mint(address(this), params.token1Balance);

        pool_ = deployPool(
            factory,
            address(params.token0),
            address(params.token1),
            3000,
            params.currentPrice
        );

        if (params.mintLiquidity) {
            params.token0.approve(address(manager), params.token0Balance);
            params.token1.approve(address(manager), params.token1Balance);

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
        mints_ = params.mints;
    }

    function setupPool(PoolParams memory params)
        internal
        returns (
            IUniswapV3Manager.MintParams[] memory mints_,
            uint256 poolBalance0,
            uint256 poolBalance1
        )
    {
        (pool, mints_, poolBalance0, poolBalance1) = setupPool(
            PoolParamsFull({
                token0: weth,
                token1: usdc,
                token0Balance: params.wethBalance,
                token1Balance: params.usdcBalance,
                currentPrice: params.currentPrice,
                mints: params.mints,
                transferInMintCallback: params.transferInMintCallback,
                transferInSwapCallback: params.transferInSwapCallback,
                mintLiquidity: params.mintLiquidity
            })
        );
    }
}
