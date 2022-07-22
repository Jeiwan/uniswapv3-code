// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "prb-math/PRBMathUD60x18.sol";

import "../src/UniswapV3Pool.sol";
import "../src/lib/FixedPoint96.sol";

import "./ERC20Mintable.sol";

abstract contract TestUtils is Test {
    struct LiquidityRange {
        int24 lowerTick;
        int24 upperTick;
        uint128 amount;
    }

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        uint160 currentSqrtP;
        LiquidityRange[] liquidity;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiqudity;
    }

    struct ExpectedStateAfterMint {
        UniswapV3Pool pool;
        ERC20Mintable token0;
        ERC20Mintable token1;
        uint256 amount0;
        uint256 amount1;
        int24 lowerTick;
        int24 upperTick;
        uint128 positionLiquidity;
        uint128 currentLiquidity;
        uint160 sqrtPriceX96;
    }

    function tick(uint256 price) internal pure returns (int24) {
        return
            TickMath.getTickAtSqrtRatio(
                uint160(
                    PRBMathUD60x18.toUint(
                        PRBMathUD60x18.sqrt(price * PRBMathUD60x18.SCALE)
                    ) << FixedPoint96.RESOLUTION
                )
            );
    }

    function sqrtP(uint256 price) internal pure returns (uint160) {
        return TickMath.getSqrtRatioAtTick(tick(price));
    }

    function assertMintState(ExpectedStateAfterMint memory expected) internal {
        assertEq(
            expected.token0.balanceOf(address(expected.pool)),
            expected.amount0,
            "incorrect token0 balance of pool"
        );
        assertEq(
            expected.token1.balanceOf(address(expected.pool)),
            expected.amount1,
            "incorrect token1 balance of pool"
        );

        bytes32 positionKey = keccak256(
            abi.encodePacked(
                address(this),
                expected.lowerTick,
                expected.upperTick
            )
        );
        uint128 posLiquidity = expected.pool.positions(positionKey);
        assertEq(
            posLiquidity,
            expected.positionLiquidity,
            "incorrect position liquidity"
        );

        (
            bool tickInitialized,
            uint128 tickLiquidityGross,
            int128 tickLiquidityNet
        ) = expected.pool.ticks(expected.lowerTick);
        assertTrue(tickInitialized);
        assertEq(
            tickLiquidityGross,
            expected.positionLiquidity,
            "incorrect lower tick gross liquidity"
        );
        assertEq(
            tickLiquidityNet,
            int128(expected.positionLiquidity),
            "incorrect lower tick net liquidity"
        );

        (tickInitialized, tickLiquidityGross, tickLiquidityNet) = expected
            .pool
            .ticks(expected.upperTick);
        assertTrue(tickInitialized);
        assertEq(
            tickLiquidityGross,
            expected.positionLiquidity,
            "incorrect upper tick gross liquidity"
        );
        assertEq(
            tickLiquidityNet,
            -int128(expected.positionLiquidity),
            "incorrect upper tick net liquidity"
        );

        assertTrue(tickInBitMap(expected.pool, expected.lowerTick));
        assertTrue(tickInBitMap(expected.pool, expected.upperTick));

        (uint160 sqrtPriceX96, int24 currentTick) = expected.pool.slot0();
        assertEq(sqrtPriceX96, expected.sqrtPriceX96, "invalid current sqrtP");
        assertEq(currentTick, 85176, "invalid current tick");
        assertEq(
            expected.pool.liquidity(),
            expected.currentLiquidity,
            "invalid current liquidity"
        );
    }

    struct ExpectedStateAfterSwap {
        UniswapV3Pool pool;
        ERC20Mintable token0;
        ERC20Mintable token1;
        uint256 userBalance0;
        uint256 userBalance1;
        uint256 poolBalance0;
        uint256 poolBalance1;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 currentLiquidity;
    }

    function assertSwapState(ExpectedStateAfterSwap memory expected) internal {
        assertEq(
            expected.token0.balanceOf(address(this)),
            uint256(expected.userBalance0),
            "invalid user ETH balance"
        );
        assertEq(
            expected.token1.balanceOf(address(this)),
            uint256(expected.userBalance1),
            "invalid user USDC balance"
        );

        assertEq(
            expected.token0.balanceOf(address(expected.pool)),
            uint256(expected.poolBalance0),
            "invalid pool ETH balance"
        );
        assertEq(
            expected.token1.balanceOf(address(expected.pool)),
            uint256(expected.poolBalance1),
            "invalid pool USDC balance"
        );

        (uint160 sqrtPriceX96, int24 currentTick) = expected.pool.slot0();
        assertEq(sqrtPriceX96, expected.sqrtPriceX96, "invalid current sqrtP");
        assertEq(currentTick, expected.tick, "invalid current tick");
        assertEq(
            expected.pool.liquidity(),
            expected.currentLiquidity,
            "invalid current liquidity"
        );
    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function encodeExtra(
        address token0_,
        address token1_,
        address payer
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                UniswapV3Pool.CallbackData({
                    token0: token0_,
                    token1: token1_,
                    payer: payer
                })
            );
    }

    function tickInBitMap(UniswapV3Pool pool, int24 tick_)
        internal
        view
        returns (bool initialized)
    {
        int16 wordPos = int16(tick_ >> 8);
        uint8 bitPos = uint8(uint24(tick_ % 256));

        uint256 word = pool.tickBitmap(wordPos);

        initialized = (word & (1 << bitPos)) != 0;
    }
}
