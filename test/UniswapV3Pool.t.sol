// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {Test, stdError} from "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

import "../src/UniswapV3Pool.sol";
import "../src/lib/LiquidityMath.sol";
import "../src/lib/TickMath.sol";

contract UniswapV3PoolTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;

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

    function testMintInRange() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick4545,
            upperTick: tick5500,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.998995580131581600 ether,
            4999.999999999999999999 ether
        );

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect token0 deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect token1 deposited amount"
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                positionLiquidity: params.liquidity,
                currentLiquidity: params.liquidity,
                sqrtPriceX96: sqrtP5000
            })
        );
    }

    function testMintRangeBelow() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick4000,
            upperTick: tick5000 - 1,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4000,
                sqrtP5000Minus1,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0 ether,
            4999.999999999999999995 ether
        );

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect token0 deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect token1 deposited amount"
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                positionLiquidity: params.liquidity,
                currentLiquidity: 0,
                sqrtPriceX96: sqrtP5000
            })
        );
    }

    function testMintRangeAbove() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 10 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick5000 + 1,
            upperTick: tick6250,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP5000Plus1,
                sqrtP6250,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        (uint256 expectedAmount0, uint256 expectedAmount1) = (1 ether, 0);

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect token0 deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect token1 deposited amount"
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: expectedAmount0,
                amount1: expectedAmount1,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                positionLiquidity: params.liquidity,
                currentLiquidity: 0,
                sqrtPriceX96: sqrtP5000
            })
        );
    }

    //
    //          5000
    //   4545 ----|---- 5500
    // 4000 ------|------ 6250
    //
    function testMintOverlappingRanges() public {
        (uint256 wethAmount, uint256 usdcAmount) = (3 ether, 20000 ether);

        token0.mint(address(this), wethAmount);
        token1.mint(address(this), usdcAmount);
        token0.approve(address(this), wethAmount);
        token1.approve(address(this), usdcAmount);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            sqrtP5000,
            tick5000
        );

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        (uint256 amount0, uint256 amount1) = (
            2.698571339742487358 ether,
            13321.078959050882134353 ether
        );
        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtP5000,
            sqrtP4545,
            sqrtP5500,
            1 ether,
            5000 ether
        );
        uint128 liquidity2 = (liquidity * 75) / 100;
        pool.mint(address(this), tick4545, tick5500, liquidity, extra);
        pool.mint(address(this), tick4000, tick6250, liquidity2, extra);

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick4545,
                upperTick: tick5500,
                positionLiquidity: liquidity,
                currentLiquidity: liquidity + liquidity2,
                sqrtPriceX96: sqrtP5000
            })
        );
        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick4000,
                upperTick: tick6250,
                positionLiquidity: liquidity2,
                currentLiquidity: liquidity + liquidity2,
                sqrtPriceX96: sqrtP5000
            })
        );
    }

    //
    //          5000
    //   4545 ----|---- 5500
    // 4000 ------ ------ 6250
    //      5000-1 5000+1
    function testMintPartiallyOverlappingRanges() public {
        (uint256 wethAmount, uint256 usdcAmount) = (3 ether, 20000 ether);

        token0.mint(address(this), wethAmount);
        token1.mint(address(this), usdcAmount);
        token0.approve(address(this), wethAmount);
        token1.approve(address(this), usdcAmount);

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            sqrtP5000,
            tick5000
        );

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        (uint256 amount0, uint256 amount1) = (
            2.131509381984257132 ether,
            13317.053751544282360878 ether
        );
        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtP5000,
            sqrtP4545,
            sqrtP5500,
            1 ether,
            5000 ether
        );
        uint128 liquidity2 = (liquidity * 75) / 100;
        uint128 liquidity3 = (liquidity * 50) / 100;
        pool.mint(address(this), tick4545, tick5500, liquidity, extra);
        pool.mint(address(this), tick4000, tick5000Minus1, liquidity2, extra);
        pool.mint(address(this), tick5000Plus1, tick6250, liquidity3, extra);

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick4545,
                upperTick: tick5500,
                positionLiquidity: liquidity,
                currentLiquidity: liquidity,
                sqrtPriceX96: sqrtP5000
            })
        );
        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick4000,
                upperTick: tick5000Minus1,
                positionLiquidity: liquidity2,
                currentLiquidity: liquidity,
                sqrtPriceX96: sqrtP5000
            })
        );
        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick5000Plus1,
                upperTick: tick6250,
                positionLiquidity: liquidity3,
                currentLiquidity: liquidity,
                sqrtPriceX96: sqrtP5000
            })
        );
    }

    function testMintInvalidTickRangeLower() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), -887273, 0, 0, "");
    }

    function testMintInvalidTickRangeUpper() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), 0, 887273, 0, "");
    }

    function testMintZeroLiquidity() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("ZeroLiquidity()"));
        pool.mint(address(this), 0, 1, 0, "");
    }

    function testMintInsufficientTokenBalance() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 0,
            usdcBalance: 0,
            currentTick: tick5000,
            lowerTick: tick4545,
            upperTick: tick5500,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: false,
            transferInSwapCallback: true,
            mintLiqudity: false
        });
        setupTestCase(params);

        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.mint(
            address(this),
            params.lowerTick,
            params.upperTick,
            params.liquidity,
            ""
        );
    }

    function testSwapBuyEth() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick4545,
            upperTick: tick5500,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
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
                currentLiquidity: 1518129116516325614066
            })
        );
    }

    function testSwapBuyUSDC() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick4545,
            upperTick: tick5500,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 swapAmount = 0.01337 ether;
        token0.mint(address(this), swapAmount);
        token0.approve(address(this), swapAmount);

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
            true,
            swapAmount,
            extra
        );

        (int256 expectedAmount0Delta, int256 expectedAmount1Delta) = (
            0.01337 ether,
            -66.807123823853842027 ether
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
                sqrtPriceX96: 5598737223630966236662554421688,
                tick: 85163,
                currentLiquidity: 1518129116516325614066
            })
        );
    }

    function testSwapMixed() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick4545,
            upperTick: tick5500,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        uint256 ethAmount = 0.01337 ether;
        token0.mint(address(this), ethAmount);
        token0.approve(address(this), ethAmount);

        uint256 usdcAmount = 55 ether;
        token1.mint(address(this), usdcAmount);
        token1.approve(address(this), usdcAmount);

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));
        int256 userBalance1Before = int256(token1.balanceOf(address(this)));

        (int256 amount0Delta1, int256 amount1Delta1) = pool.swap(
            address(this),
            true,
            ethAmount,
            extra
        );

        (int256 amount0Delta2, int256 amount1Delta2) = pool.swap(
            address(this),
            false,
            usdcAmount,
            extra
        );

        assertSwapState(
            ExpectedStateAfterSwap({
                pool: pool,
                token0: token0,
                token1: token1,
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
                sqrtPriceX96: 5601607565086694240599300641950,
                tick: 85173,
                currentLiquidity: 1518129116516325614066
            })
        );
    }

    function testSwapBuyEthNotEnoughLiquidity() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick4545,
            upperTick: tick5500,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupTestCase(params);

        uint256 swapAmount = 5300 ether;
        token1.mint(address(this), swapAmount);
        token1.approve(address(this), swapAmount);

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        vm.expectRevert(encodeError("NotEnoughLiquidity()"));
        pool.swap(address(this), false, swapAmount, extra);
    }

    function testSwapBuyUSDCNotEnoughLiquidity() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick4545,
            upperTick: tick5500,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupTestCase(params);

        uint256 swapAmount = 1.1 ether;
        token0.mint(address(this), swapAmount);
        token0.approve(address(this), swapAmount);

        bytes memory extra = encodeExtra(
            address(token0),
            address(token1),
            address(this)
        );

        vm.expectRevert(encodeError("NotEnoughLiquidity()"));
        pool.swap(address(this), true, swapAmount, extra);
    }

    function testSwapInsufficientInputAmount() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick5000,
            lowerTick: tick4545,
            upperTick: tick5500,
            liquidity: LiquidityMath.getLiquidityForAmounts(
                sqrtP5000,
                sqrtP4545,
                sqrtP5500,
                1 ether,
                5000 ether
            ),
            currentSqrtP: sqrtP5000,
            transferInMintCallback: true,
            transferInSwapCallback: false,
            mintLiqudity: true
        });
        setupTestCase(params);

        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.swap(address(this), false, 42 ether, "");
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
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        if (transferInMintCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(
                data,
                (UniswapV3Pool.CallbackData)
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

            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity,
                extra
            );
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
    }
}
