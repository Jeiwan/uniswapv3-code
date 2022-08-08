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

    function setUp() public {
        usdc = new ERC20Mintable("USDC", "USDC", 18);
        weth = new ERC20Mintable("Ether", "ETH", 18);
        factory = new UniswapV3Factory();
    }

    function testInitialize() public {
        pool = UniswapV3Pool(
            factory.createPool(address(weth), address(usdc), 3000)
        );

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(sqrtPriceX96, 0, "invalid sqrtPriceX96");
        assertEq(tick, 0, "invalid tick");

        pool.initialize(sqrtP(31337));

        (sqrtPriceX96, tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            14025175117687921942002399182848,
            "invalid sqrtPriceX96"
        );
        assertEq(tick, 103530, "invalid tick");

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

        assertPoolState(
            ExpectedPoolState({
                pool: pool,
                liquidity: liquidity[0].amount,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );

        assertBalances(
            ExpectedBalances({
                pool: pool,
                tokens: [weth, usdc],
                userBalance0: 1 ether - expectedAmount0,
                userBalance1: 5000 ether - expectedAmount1,
                poolBalance0: expectedAmount0,
                poolBalance1: expectedAmount1
            })
        );

        assertPosition(
            ExpectedPosition({
                pool: pool,
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                position: Position.Info({
                    liquidity: liquidity[0].amount,
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                })
            })
        );

        assertTick(
            ExpectedTick({
                pool: pool,
                tick: liquidity[0].lowerTick,
                initialized: true,
                liquidityGross: liquidity[0].amount,
                liquidityNet: int128(liquidity[0].amount)
            })
        );

        assertTick(
            ExpectedTick({
                pool: pool,
                tick: liquidity[0].upperTick,
                initialized: true,
                liquidityGross: liquidity[0].amount,
                liquidityNet: -int128(liquidity[0].amount)
            })
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                position: Position.Info({
                    liquidity: liquidity[0].amount,
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity[0].amount,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
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

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                position: Position.Info({
                    liquidity: liquidity[0].amount,
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

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                position: Position.Info({
                    liquidity: liquidity[0].amount,
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

        (uint256 amount0, uint256 amount1) = (
            1.783209628932229704 ether,
            8998.601885914465050207 ether
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
                    liquidity: liquidity[0].amount,
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity[0].amount + liquidity[1].amount,
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
                    liquidity: liquidity[1].amount,
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: 0,
                    tokensOwed1: 0
                }),
                currentLiquidity: liquidity[0].amount + liquidity[1].amount,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testBurn() public {
        (LiquidityRange[] memory liquidity, , ) = setupPool(
            PoolParams({
                balances: [uint256(3 ether), 15000 ether],
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
            0.987286567250950169 ether,
            4998.958915878679752571 ether
        );

        (uint256 burnAmount0, uint256 burnAmount1) = pool.burn(
            liquidity[0].lowerTick,
            liquidity[0].upperTick,
            liquidity[0].amount
        );

        assertEq(burnAmount0, expectedAmount0, "incorrect weth burned amount");
        assertEq(burnAmount1, expectedAmount1, "incorrect usdc burned amount");

        assertBurnState(
            ExpectedStateAfterBurn({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: expectedAmount0 + 1,
                amount1: expectedAmount1 + 1,
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                position: Position.Info({
                    liquidity: 0,
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: uint128(expectedAmount0),
                    tokensOwed1: uint128(expectedAmount1)
                }),
                currentLiquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testBurnPartially() public {
        (LiquidityRange[] memory liquidity, , ) = setupPool(
            PoolParams({
                balances: [uint256(3 ether), 15000 ether],
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
            0.493643283625475084 ether,
            2499.479457939339876284 ether
        );

        (uint256 burnAmount0, uint256 burnAmount1) = pool.burn(
            liquidity[0].lowerTick,
            liquidity[0].upperTick,
            liquidity[0].amount / 2
        );

        assertEq(burnAmount0, expectedAmount0, "incorrect weth burned amount");
        assertEq(burnAmount1, expectedAmount1, "incorrect usdc burned amount");

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: weth,
                token1: usdc,
                amount0: 0.987286567250950170 ether,
                amount1: 4998.958915878679752572 ether,
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                position: Position.Info({
                    liquidity: liquidity[0].amount / 2 + 1,
                    feeGrowthInside0LastX128: 0,
                    feeGrowthInside1LastX128: 0,
                    tokensOwed0: uint128(expectedAmount0),
                    tokensOwed1: uint128(expectedAmount1)
                }),
                currentLiquidity: liquidity[0].amount / 2 + 1,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
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
