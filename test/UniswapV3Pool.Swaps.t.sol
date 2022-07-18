// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {Test, stdError} from "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

import "../src/UniswapV3Pool.sol";
import "../src/lib/LiquidityMath.sol";
import "../src/lib/TickMath.sol";

contract UniswapV3PoolSwapsTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    int24 tick4000 = 82994;
    int24 tick4545 = 84222;
    int24 tick5000 = 85176;
    int24 tick5000Minus1 = 85175;
    int24 tick5000Plus1 = 85177;
    int24 tick5500 = 86129;
    int24 tick6250 = 87407;

    uint160 sqrtP4000 = TickMath.getSqrtRatioAtTick(tick4000);
    uint160 sqrtP4545 = TickMath.getSqrtRatioAtTick(tick4545);
    uint160 sqrtP5000 = TickMath.getSqrtRatioAtTick(tick5000);
    uint160 sqrtP5000Minus1 = TickMath.getSqrtRatioAtTick(tick5000Minus1);
    uint160 sqrtP5000Plus1 = TickMath.getSqrtRatioAtTick(tick5000Plus1);
    uint160 sqrtP5500 = TickMath.getSqrtRatioAtTick(tick5500);
    uint160 sqrtP6250 = TickMath.getSqrtRatioAtTick(tick6250);

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    //  One price range
    //
    //          5000
    //  4545 -----|----- 5500
    //
    function testBuyETHOnePriceRange() public {
        LiquidityRange[] memory liquidity = new LiquidityRange[](1);
        liquidity[0] = LiquidityRange({
            lowerTick: tick4545,
            upperTick: tick5500,
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            )
        });
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            currentSqrtP: sqrtP5000,
            liquidity: liquidity,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 swapAmount = 42 ether; // 42 USDC
        token1.mint(address(this), swapAmount);
        token1.approve(address(this), swapAmount);

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(token0.balanceOf(address(this))),
            int256(token1.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            swapAmount,
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            -0.008396874645169943 ether,
            42 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: token0,
                token1: token1,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5604415652688968742392013927525,
                tick: 85183,
                currentLiquidity: liquidity[0].amount
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
        LiquidityRange[] memory liquidity = new LiquidityRange[](2);
        liquidity[0] = LiquidityRange({
            lowerTick: tick4545,
            upperTick: tick5500,
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            )
        });
        liquidity[1] = LiquidityRange({
            lowerTick: tick4545,
            upperTick: tick5500,
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            )
        });
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 2 ether,
            usdcBalance: 10000 ether,
            currentTick: tick5000,
            currentSqrtP: sqrtP5000,
            liquidity: liquidity,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 swapAmount = 42 ether; // 42 USDC
        token1.mint(address(this), swapAmount);
        token1.approve(address(this), swapAmount);

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        (int256 userBalance0Before, int256 userBalance1Before) = (
            int256(token0.balanceOf(address(this))),
            int256(token1.balanceOf(address(this)))
        );

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            swapAmount,
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            -0.008398516982770993 ether,
            42 ether
        );

        assertEq(amount0Delta, expectedAmount0Delta, "invalid ETH out");
        assertEq(amount1Delta, expectedAmount1Delta, "invalid USDC in");

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: token0,
                token1: token1,
                userBalance0: uint256(userBalance0Before - amount0Delta),
                userBalance1: uint256(userBalance1Before - amount1Delta),
                poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
                poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
                sqrtPriceX96: 5603319704133145322707074461607,
                tick: 85179,
                currentLiquidity: liquidity[0].amount + liquidity[1].amount
            })
        );
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
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount0)
            );
        }

        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount1)
            );
        }
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
        IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );

        if (params.mintLiqudity) {
            token0.approve(address(this), params.wethBalance);
            token1.approve(address(this), params.usdcBalance);

            bytes memory extra = encodeExtra(
                address(token0),
                address(token1),
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
    }
}
