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

contract UniswapV3PoolTest is Test, UniswapV3PoolUtils {
    ERC20Mintable weth;
    ERC20Mintable usdc;
    UniswapV3Factory factory;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool flashCallbackCalled = false;

    function setUp() public {
        usdc = new ERC20Mintable("USDC", "USDC", 18);
        weth = new ERC20Mintable("Ether", "ETH", 18);
        factory = new UniswapV3Factory();
    }

    function testInitialize() public {
        pool = UniswapV3Pool(
            factory.createPool(address(weth), address(usdc), 3000)
        );

        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext
        ) = pool.slot0();
        assertEq(sqrtPriceX96, 0, "invalid sqrtPriceX96");
        assertEq(tick, 0, "invalid tick");
        assertEq(observationIndex, 0, "invalid observation index");
        assertEq(observationCardinality, 0, "invalid observation cardinality");
        assertEq(
            observationCardinalityNext,
            0,
            "invalid next observation cardinality"
        );

        pool.initialize(sqrtP(31337));

        (
            sqrtPriceX96,
            tick,
            observationIndex,
            observationCardinality,
            observationCardinalityNext
        ) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            14025175117687921942002399182848,
            "invalid sqrtPriceX96"
        );
        assertEq(tick, 103530, "invalid tick");
        assertEq(observationIndex, 0, "invalid observation index");
        assertEq(observationCardinality, 1, "invalid observation cardinality");
        assertEq(
            observationCardinalityNext,
            1,
            "invalid next observation cardinality"
        );

        vm.expectRevert(encodeError("AlreadyInitialized()"));
        pool.initialize(sqrtP(42));
    }

    function testMintInRange() public {
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
                liquidity: liquidity[0].amount,
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
                    ticks: [liquidity[0].lowerTick, liquidity[0].upperTick],
                    liquidity: liquidity[0].amount,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: rangeToTicks(liquidity[0]),
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
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(1 ether), 5000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4000, 4996, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
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
                    ticks: [liquidity[0].lowerTick, liquidity[0].upperTick],
                    liquidity: liquidity[0].amount,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: rangeToTicks(liquidity[0]),
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
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(1 ether), 5000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(5001, 6250, 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
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
                    ticks: [liquidity[0].lowerTick, liquidity[0].upperTick],
                    liquidity: liquidity[0].amount,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: rangeToTicks(liquidity[0]),
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
        (LiquidityRange[] memory liquidity, , ) = setupPool(
            PoolParams({
                balances: [uint256(3 ether), 15000 ether],
                currentPrice: 5000,
                liquidity: liquidityRanges(
                    liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000),
                    liquidityRange(4000, 6250, 0.8 ether, 4000 ether, 5000)
                ),
                transferInMintCallback: true,
                transferInSwapCallback: true,
                mintLiqudity: true
            })
        );

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            1.782930003452677700 ether,
            8999.999999999999999997 ether
        );

        assertMany(
            ExpectedPoolAndBalances({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity[0].amount + liquidity[1].amount,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000),
                fees: [uint256(0), 0],
                userBalances: [
                    3 ether - expectedAmount0,
                    15000 ether - expectedAmount1
                ],
                poolBalances: [expectedAmount0, expectedAmount1]
            })
        );

        assertMany(
            ExpectedPositionAndTicks({
                pool: pool,
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [liquidity[0].lowerTick, liquidity[0].upperTick],
                    liquidity: liquidity[0].amount,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: rangeToTicks(liquidity[0])
            })
        );

        assertMany(
            ExpectedPositionAndTicks({
                pool: pool,
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [liquidity[1].lowerTick, liquidity[1].upperTick],
                    liquidity: liquidity[1].amount,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: rangeToTicks(liquidity[1])
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

    function testBurn() public {
        (LiquidityRange[] memory liquidity, , ) = setupPool(
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

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.987078348444137444 ether,
            4999.999999999999999999 ether
        );

        (uint256 burnAmount0, uint256 burnAmount1) = pool.burn(
            liquidity[0].lowerTick,
            liquidity[0].upperTick,
            liquidity[0].amount
        );

        assertEq(burnAmount0, expectedAmount0, "incorrect weth burned amount");
        assertEq(burnAmount1, expectedAmount1, "incorrect usdc burned amount");

        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000),
                fees: [uint256(0), 0],
                userBalances: [
                    1 ether - expectedAmount0 - 1,
                    5000 ether - expectedAmount1 - 1
                ],
                poolBalances: [expectedAmount0 + 1, expectedAmount1 + 1],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [liquidity[0].lowerTick, liquidity[0].upperTick],
                    liquidity: 0,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [
                        uint128(expectedAmount0),
                        uint128(expectedAmount1)
                    ]
                }),
                ticks: [
                    ExpectedTickShort({
                        tick: liquidity[0].lowerTick,
                        initialized: true, // TODO: fix, must be false
                        liquidityGross: 0,
                        liquidityNet: 0
                    }),
                    ExpectedTickShort({
                        tick: liquidity[0].upperTick,
                        initialized: true, // TODO: fix, must be false
                        liquidityGross: 0,
                        liquidityNet: 0
                    })
                ],
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    function testBurnPartially() public {
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

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.493539174222068722 ether,
            2499.999999999999999997 ether
        );

        (uint256 burnAmount0, uint256 burnAmount1) = pool.burn(
            liquidity[0].lowerTick,
            liquidity[0].upperTick,
            liquidity[0].amount / 2
        );

        assertEq(burnAmount0, expectedAmount0, "incorrect weth burned amount");
        assertEq(burnAmount1, expectedAmount1, "incorrect usdc burned amount");

        assertMany(
            ExpectedMany({
                pool: pool,
                tokens: [weth, usdc],
                liquidity: liquidity[0].amount / 2 + 1,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000),
                fees: [uint256(0), 0],
                userBalances: [
                    1 ether - poolBalance0,
                    5000 ether - poolBalance1
                ],
                poolBalances: [poolBalance0, poolBalance1],
                position: ExpectedPositionShort({
                    owner: address(this),
                    ticks: [liquidity[0].lowerTick, liquidity[0].upperTick],
                    liquidity: liquidity[0].amount / 2 + 1,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [
                        uint128(expectedAmount0),
                        uint128(expectedAmount1)
                    ]
                }),
                ticks: [
                    ExpectedTickShort({
                        tick: liquidity[0].lowerTick,
                        initialized: true,
                        liquidityGross: liquidity[0].amount / 2 + 1,
                        liquidityNet: int128(liquidity[0].amount / 2 + 1)
                    }),
                    ExpectedTickShort({
                        tick: liquidity[0].upperTick,
                        initialized: true,
                        liquidityGross: liquidity[0].amount / 2 + 1,
                        liquidityNet: -int128(liquidity[0].amount / 2 + 1)
                    })
                ],
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );
    }

    function testCollect() public {
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
        LiquidityRange memory liq = liquidity[0];

        uint256 swapAmount = 42 ether; // 42 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        (int256 swapAmount0, int256 swapAmount1) = pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(5004),
            encodeExtra(address(weth), address(usdc), address(this))
        );

        pool.burn(liq.lowerTick, liq.upperTick, liq.amount);

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), liq.lowerTick, liq.upperTick)
        );

        (, , , uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(
            positionKey
        );

        assertEq(
            tokensOwed0,
            uint256(int256(poolBalance0) + swapAmount0 - 1),
            "incorrect tokens owed for token0"
        );
        assertEq(
            tokensOwed1,
            uint256(int256(poolBalance1) + swapAmount1 - 2), // swap fee 0.003%
            "incorrect tokens owed for token1"
        );

        (uint128 amountCollected0, uint128 amountCollected1) = pool.collect(
            address(this),
            liq.lowerTick,
            liq.upperTick,
            tokensOwed0,
            tokensOwed1
        );
        assertEq(
            amountCollected0,
            tokensOwed0,
            "incorrect collected amount for token 0"
        );
        assertEq(
            amountCollected1,
            tokensOwed1,
            "incorrect collected amount for token 1"
        );

        assertEq(
            weth.balanceOf(address(pool)),
            1,
            "incorrect pool balance of token0 after collect"
        );
        assertEq(
            usdc.balanceOf(address(pool)),
            2,
            "incorrect pool balance of token1 after collect"
        );

        (, , , tokensOwed0, tokensOwed1) = pool.positions(positionKey);

        assertEq(
            tokensOwed0,
            0,
            "incorrect owed amount for token 0 after collect"
        );
        assertEq(
            tokensOwed1,
            0,
            "incorrect owed amount for token 1 after collect"
        );
    }

    function testCollectAfterZeroBurn() public {
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
        LiquidityRange memory liq = liquidity[0];

        uint256 swapAmount = 42 ether; // 42 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        (int256 swapAmount0, int256 swapAmount1) = pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(5004),
            encodeExtra(address(weth), address(usdc), address(this))
        );

        pool.burn(liq.lowerTick, liq.upperTick, 0);

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), liq.lowerTick, liq.upperTick)
        );

        (, , , uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(
            positionKey
        );

        assertEq(tokensOwed0, 0, "incorrect tokens owed for token0");
        assertEq(
            tokensOwed1,
            uint256((swapAmount1 * 3000) / 1e6) - 1, // - 0.03% - rounding
            "incorrect tokens owed for token1"
        );

        (uint128 amountCollected0, uint128 amountCollected1) = pool.collect(
            address(this),
            liq.lowerTick,
            liq.upperTick,
            tokensOwed0,
            tokensOwed1
        );
        assertEq(
            amountCollected0,
            tokensOwed0,
            "incorrect collected amount for token 0"
        );
        assertEq(
            amountCollected1,
            tokensOwed1,
            "incorrect collected amount for token 1"
        );

        assertEq(
            weth.balanceOf(address(pool)),
            poolBalance0 - uint256(-swapAmount0) - amountCollected0,
            "incorrect pool balance of token0 after collect"
        );
        assertEq(
            usdc.balanceOf(address(pool)),
            poolBalance1 + uint256(swapAmount1) - amountCollected1,
            "incorrect pool balance of token1 after collect"
        );
    }

    function testCollectMoreThanAvailable() public {
        (LiquidityRange[] memory liquidity, , ) = setupPool(
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
        LiquidityRange memory liq = liquidity[0];

        uint256 swapAmount = 42 ether; // 42 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(5004),
            encodeExtra(address(weth), address(usdc), address(this))
        );

        pool.burn(liq.lowerTick, liq.upperTick, liq.amount);

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), liq.lowerTick, liq.upperTick)
        );

        (, , , uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(
            positionKey
        );

        (uint128 amountCollected0, uint128 amountCollected1) = pool.collect(
            address(this),
            liq.lowerTick,
            liq.upperTick,
            999_999_999 ether,
            999_999_999 ether
        );
        assertEq(
            amountCollected0,
            tokensOwed0,
            "incorrect collected amount for token 0"
        );
        assertEq(
            amountCollected1,
            tokensOwed1,
            "incorrect collected amount for token 1"
        );
    }

    function testCollectPartially() public {
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
        LiquidityRange memory liq = liquidity[0];

        uint256 swapAmount = 42 ether; // 42 USDC
        usdc.mint(address(this), swapAmount);
        usdc.approve(address(this), swapAmount);

        int256[] memory swapAmounts = new int256[](2);
        (swapAmounts[0], swapAmounts[1]) = pool.swap(
            address(this),
            false,
            swapAmount,
            sqrtP(5004),
            encodeExtra(address(weth), address(usdc), address(this))
        );

        pool.burn(liq.lowerTick, liq.upperTick, liq.amount / 2);

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), liq.lowerTick, liq.upperTick)
        );

        uint128[] memory tokensOwed = new uint128[](2);
        (, , , tokensOwed[0], tokensOwed[1]) = pool.positions(positionKey);

        uint128[] memory expectedTokensOwed = new uint128[](2);
        (expectedTokensOwed[0], expectedTokensOwed[1]) = (
            0.489353377248529488 ether,
            2521.062999999999999996 ether
        );

        assertEq(
            tokensOwed[0],
            expectedTokensOwed[0],
            "incorrect tokens owed for token0"
        );
        assertEq(
            tokensOwed[1],
            expectedTokensOwed[1],
            "incorrect tokens owed for token1"
        );

        uint128[] memory collectedAmounts = new uint128[](2);
        (collectedAmounts[0], collectedAmounts[1]) = pool.collect(
            address(this),
            liq.lowerTick,
            liq.upperTick,
            tokensOwed[0],
            tokensOwed[1]
        );
        assertEq(
            collectedAmounts[0],
            tokensOwed[0],
            "incorrect collected amount for token 0"
        );
        assertEq(
            collectedAmounts[1],
            tokensOwed[1],
            "incorrect collected amount for token 1"
        );

        assertEq(
            weth.balanceOf(address(pool)),
            uint256(int256(poolBalance0) + swapAmounts[0]) - tokensOwed[0],
            "incorrect pool balance of token0 after collect"
        );
        assertEq(
            usdc.balanceOf(address(pool)),
            uint256(int256(poolBalance1) + swapAmounts[1]) - tokensOwed[1],
            "incorrect pool balance of token1 after collect"
        );
    }

    function testMintInvalidTickRangeLower() public {
        pool = deployPool(factory, address(weth), address(usdc), 3000, 1);

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), -887273, 0, 0, "");
    }

    function testMintInvalidTickRangeUpper() public {
        pool = deployPool(factory, address(weth), address(usdc), 3000, 1);

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), 0, 887273, 0, "");
    }

    function testMintZeroLiquidity() public {
        pool = deployPool(factory, address(weth), address(usdc), 3000, 1);

        vm.expectRevert(encodeError("ZeroLiquidity()"));
        pool.mint(address(this), 0, 1, 0, "");
    }

    function testMintInsufficientTokenBalance() public {
        (LiquidityRange[] memory liquidity, , ) = setupPool(
            PoolParams({
                balances: [uint256(0), 0],
                currentPrice: 5000,
                liquidity: liquidityRanges(
                    liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000)
                ),
                transferInMintCallback: false,
                transferInSwapCallback: true,
                mintLiqudity: false
            })
        );

        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.mint(
            address(this),
            liquidity[0].lowerTick,
            liquidity[0].upperTick,
            liquidity[0].amount,
            ""
        );
    }

    function testFlash() public {
        setupPool(
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

        // flash loan fee, 3 USDC
        usdc.mint(address(this), 3 ether);

        pool.flash(
            0.1 ether,
            1000 ether,
            abi.encodePacked(uint256(0.1 ether), uint256(1000 ether))
        );

        assertTrue(flashCallbackCalled, "flash callback wasn't called");
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // CALLBACKS
    //
    ////////////////////////////////////////////////////////////////////////////
    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        if (transferInMintCallback) {
            IUniswapV3Pool.CallbackData memory extra = abi.decode(
                data,
                (IUniswapV3Pool.CallbackData)
            );

            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
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

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) public {
        (uint256 amount0, uint256 amount1) = abi.decode(
            data,
            (uint256, uint256)
        );

        if (amount0 > 0) weth.transfer(msg.sender, amount0 + fee0);
        if (amount1 > 0) usdc.transfer(msg.sender, amount1 + fee1);

        flashCallbackCalled = true;
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

            bytes memory extra = encodeExtra(
                address(weth),
                address(usdc),
                address(this)
            );

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
        liquidity = params.liquidity;
    }
}
