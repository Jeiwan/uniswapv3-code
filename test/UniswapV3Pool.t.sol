// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/lib/LiquidityMath.sol";
import "../src/lib/TickMath.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3PoolTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintInRange() public {
        LiquidityRange[] memory liquidity = new LiquidityRange[](1);
        liquidity[0] = LiquidityRange({
            lowerTick: tick(4545),
            upperTick: tick(5500),
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP(5000),
                sqrtP(4545),
                sqrtP(5500),
                1 ether,
                5000 ether
            )
        });
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick(5000),
            currentSqrtP: sqrtP(5000),
            liquidity: liquidity,
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
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                positionLiquidity: liquidity[0].amount,
                currentLiquidity: liquidity[0].amount,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintRangeBelow() public {
        LiquidityRange[] memory liquidity = new LiquidityRange[](1);
        liquidity[0] = LiquidityRange({
            lowerTick: tick(4000),
            upperTick: tick(4999),
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP(5000),
                sqrtP(4000),
                sqrtP(4999),
                1 ether,
                5000 ether
            )
        });
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: tick(5000),
            currentSqrtP: sqrtP(5000),
            liquidity: liquidity,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0 ether,
            4999.999999999999999997 ether
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
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                positionLiquidity: liquidity[0].amount,
                currentLiquidity: 0,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
    }

    function testMintRangeAbove() public {
        LiquidityRange[] memory liquidity = new LiquidityRange[](1);
        liquidity[0] = LiquidityRange({
            lowerTick: tick(5001),
            upperTick: tick(6250),
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP(5000),
                sqrtP(5001),
                sqrtP(6250),
                1 ether,
                5000 ether
            )
        });
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 10 ether,
            usdcBalance: 5000 ether,
            currentTick: tick(5000),
            currentSqrtP: sqrtP(5000),
            liquidity: liquidity,
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
                lowerTick: liquidity[0].lowerTick,
                upperTick: liquidity[0].upperTick,
                positionLiquidity: liquidity[0].amount,
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
        LiquidityRange[] memory liquidity = new LiquidityRange[](2);
        liquidity[0] = LiquidityRange({
            lowerTick: tick(4545),
            upperTick: tick(5500),
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP(5000),
                sqrtP(4545),
                sqrtP(5500),
                1 ether,
                5000 ether
            )
        });
        liquidity[1] = LiquidityRange({
            lowerTick: tick(4000),
            upperTick: tick(6250),
            amount: (liquidity[0].amount * 75) / 100
        });
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 3 ether,
            usdcBalance: 15000 ether,
            currentTick: tick(5000),
            currentSqrtP: sqrtP(5000),
            liquidity: liquidity,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });
        setupTestCase(params);

        (uint256 amount0, uint256 amount1) = (
            2.698571339742487358 ether,
            13501.317327786998874075 ether
        );

        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick(4545),
                upperTick: tick(5500),
                positionLiquidity: liquidity[0].amount,
                currentLiquidity: liquidity[0].amount + liquidity[1].amount,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
            })
        );
        assertMintState(
            ExpectedStateAfterMint({
                pool: pool,
                token0: token0,
                token1: token1,
                amount0: amount0,
                amount1: amount1,
                lowerTick: tick(4000),
                upperTick: tick(6250),
                positionLiquidity: liquidity[1].amount,
                currentLiquidity: liquidity[0].amount + liquidity[1].amount,
                sqrtPriceX96: sqrtP(5000),
                tick: tick(5000)
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
        LiquidityRange[] memory liquidity = new LiquidityRange[](1);
        liquidity[0] = LiquidityRange({
            lowerTick: tick(4545),
            upperTick: tick(5500),
            amount: LiquidityMath.getLiquidityForAmounts(
                sqrtP(5000),
                sqrtP(4545),
                sqrtP(5500),
                1 ether,
                5000 ether
            )
        });
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 0,
            usdcBalance: 0,
            currentTick: tick(5000),
            currentSqrtP: sqrtP(5000),
            liquidity: liquidity,
            transferInMintCallback: false,
            transferInSwapCallback: true,
            mintLiqudity: false
        });
        setupTestCase(params);

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

        transferInMintCallback = params.transferInMintCallback;
    }
}
