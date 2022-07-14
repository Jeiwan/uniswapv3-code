// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {Test, stdError} from "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "./TestUtils.sol";

contract UniswapV3PoolTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiqudity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintInRange() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        assertPoolState(
            ExpectedPoolState({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: 0.998833192822975409 ether,
                amount1: 4999.187247111820044641 ether,
                poolBalance0: poolBalance0,
                poolBalance1: poolBalance1,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                positionLiquidity: params.liquidity,
                currentLiquidity: params.liquidity,
                sqrtPriceX96: 5602277097478614198912276234240
            })
        );
    }

    function testMintRangeBelow() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 10 ether,
            usdcBalance: 10000 ether,
            currentTick: 85176,
            lowerTick: 83268,
            upperTick: 85175,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        assertPoolState(
            ExpectedPoolState({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: 0 ether,
                amount1: 9760.156498980712946278 ether,
                poolBalance0: poolBalance0,
                poolBalance1: poolBalance1,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                positionLiquidity: params.liquidity,
                currentLiquidity: 0,
                sqrtPriceX96: 5602277097478614198912276234240
            })
        );
    }

    function testMintRangeAbove() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 10 ether,
            usdcBalance: 10000 ether,
            currentTick: 85176,
            lowerTick: 85177,
            upperTick: 87084,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        assertPoolState(
            ExpectedPoolState({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: 1.952068472733594637 ether,
                amount1: 0,
                poolBalance0: poolBalance0,
                poolBalance1: poolBalance1,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                positionLiquidity: params.liquidity,
                currentLiquidity: 0,
                sqrtPriceX96: 5602277097478614198912276234240
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
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
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
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
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

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));
        int256 userBalance1Before = int256(token1.balanceOf(address(this)));

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            swapAmount,
            extra
        );

        assertEq(amount0Delta, -0.008396714242162445 ether, "invalid ETH out");
        assertEq(amount1Delta, 42 ether, "invalid USDC in");

        assertEq(
            token0.balanceOf(address(this)),
            uint256(userBalance0Before - amount0Delta),
            "invalid user ETH balance"
        );
        assertEq(
            token1.balanceOf(address(this)),
            uint256(userBalance1Before - amount1Delta),
            "invalid user USDC balance"
        );

        assertEq(
            token0.balanceOf(address(pool)),
            uint256(int256(poolBalance0) + amount0Delta),
            "invalid pool ETH balance"
        );
        assertEq(
            token1.balanceOf(address(pool)),
            uint256(int256(poolBalance1) + amount1Delta),
            "invalid pool USDC balance"
        );

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            5604469350942327889444743441197,
            "invalid current sqrtP"
        );
        assertEq(tick, 85184, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1517882343751509868544,
            "invalid current liquidity"
        );
    }

    function testSwapBuyUSDC() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
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

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));
        int256 userBalance1Before = int256(token1.balanceOf(address(this)));

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            true,
            swapAmount,
            extra
        );

        assertEq(amount0Delta, 0.01337 ether, "invalid ETH in");
        assertEq(
            amount1Delta,
            -66.808388890199406685 ether,
            "invalid USDC out"
        );

        assertEq(
            token0.balanceOf(address(this)),
            uint256(userBalance0Before - amount0Delta),
            "invalid user ETH balance"
        );
        assertEq(
            token1.balanceOf(address(this)),
            uint256(userBalance1Before - amount1Delta),
            "invalid user USDC balance"
        );

        assertEq(
            token0.balanceOf(address(pool)),
            uint256(int256(poolBalance0) + amount0Delta),
            "invalid pool ETH balance"
        );
        assertEq(
            token1.balanceOf(address(pool)),
            uint256(int256(poolBalance1) + amount1Delta),
            "invalid pool USDC balance"
        );

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            5598789932670288701514545755210,
            "invalid current sqrtP"
        );
        assertEq(tick, 85163, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1517882343751509868544,
            "invalid current liquidity"
        );
    }

    function testSwapMixed() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
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

        assertEq(
            token0.balanceOf(address(this)),
            uint256(userBalance0Before - amount0Delta1 - amount0Delta2),
            "invalid user ETH balance"
        );
        assertEq(
            token1.balanceOf(address(this)),
            uint256(userBalance1Before - amount1Delta1 - amount1Delta2),
            "invalid user USDC balance"
        );

        assertEq(
            token0.balanceOf(address(pool)),
            uint256(int256(poolBalance0) + amount0Delta1 + amount0Delta2),
            "invalid pool ETH balance"
        );
        assertEq(
            token1.balanceOf(address(pool)),
            uint256(int256(poolBalance1) + amount1Delta1 + amount1Delta2),
            "invalid pool USDC balance"
        );

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            5601660740777532820068967097654,
            "invalid current sqrtP"
        );
        assertEq(tick, 85173, "invalid current tick");
        assertEq(
            pool.liquidity(),
            1517882343751509868544,
            "invalid current liquidity"
        );
    }

    function testSwapBuyEthNotEnoughLiquidity() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
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
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
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
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
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
