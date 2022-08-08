// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";

import "../src/UniswapV3Pool.sol";

import "./ERC20Mintable.sol";

abstract contract Assertions is Test {
    struct ExpectedPoolState {
        UniswapV3Pool pool;
        uint128 liquidity;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    function assertPoolState(ExpectedPoolState memory expected) internal {
        (uint160 sqrtPriceX96, int24 currentTick) = expected.pool.slot0();
        assertEq(sqrtPriceX96, expected.sqrtPriceX96, "invalid current sqrtP");
        assertEq(currentTick, expected.tick, "invalid current tick");
        assertEq(
            expected.pool.liquidity(),
            expected.liquidity,
            "invalid current liquidity"
        );
    }

    struct ExpectedBalances {
        UniswapV3Pool pool;
        ERC20Mintable[2] tokens;
        uint256 userBalance0;
        uint256 userBalance1;
        uint256 poolBalance0;
        uint256 poolBalance1;
    }

    function assertBalances(ExpectedBalances memory expected) internal {
        assertEq(
            expected.tokens[0].balanceOf(address(this)),
            expected.userBalance0,
            "incorrect token0 balance of user"
        );
        assertEq(
            expected.tokens[1].balanceOf(address(this)),
            expected.userBalance1,
            "incorrect token0 balance of user"
        );

        assertEq(
            expected.tokens[0].balanceOf(address(expected.pool)),
            expected.poolBalance0,
            "incorrect token0 balance of pool"
        );
        assertEq(
            expected.tokens[1].balanceOf(address(expected.pool)),
            expected.poolBalance1,
            "incorrect token0 balance of pool"
        );
    }

    struct ExpectedTick {
        UniswapV3Pool pool;
        int24 tick;
        bool initialized;
        uint128 liquidityGross;
        int128 liquidityNet;
    }

    function assertTick(ExpectedTick memory expected) internal {
        (
            bool initialized,
            uint128 liquidityGross,
            int128 liquidityNet,
            ,

        ) = expected.pool.ticks(expected.tick);
        assertEq(initialized, expected.initialized);
        assertEq(
            liquidityGross,
            expected.liquidityGross,
            "incorrect lower tick gross liquidity"
        );
        assertEq(
            liquidityNet,
            expected.liquidityNet,
            "incorrect lower tick net liquidity"
        );

        assertEq(
            tickInBitMap(expected.pool, expected.tick),
            expected.initialized
        );
    }

    struct ExpectedStateAfterMint {
        UniswapV3Pool pool;
        ERC20Mintable token0;
        ERC20Mintable token1;
        uint256 amount0;
        uint256 amount1;
        int24 lowerTick;
        int24 upperTick;
        Position.Info position;
        uint128 currentLiquidity;
        uint160 sqrtPriceX96;
        int24 tick;
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
        (
            uint128 posLiquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = expected.pool.positions(positionKey);
        assertEq(
            posLiquidity,
            expected.position.liquidity,
            "incorrect position liquidity"
        );
        assertEq(
            feeGrowthInside0LastX128,
            expected.position.feeGrowthInside0LastX128,
            "incorrect position fee growth for token0"
        );
        assertEq(
            feeGrowthInside1LastX128,
            expected.position.feeGrowthInside1LastX128,
            "incorrect position fee growth for token1"
        );
        assertEq(
            tokensOwed0,
            expected.position.tokensOwed0,
            "incorrect position tokens owed for token0"
        );
        assertEq(
            tokensOwed1,
            expected.position.tokensOwed1,
            "incorrect position tokens owed for token1"
        );

        (
            bool tickInitialized,
            uint128 tickLiquidityGross,
            int128 tickLiquidityNet,
            ,

        ) = expected.pool.ticks(expected.lowerTick);
        assertTrue(tickInitialized);
        assertEq(
            tickLiquidityGross,
            expected.position.liquidity,
            "incorrect lower tick gross liquidity"
        );
        assertEq(
            tickLiquidityNet,
            int128(expected.position.liquidity),
            "incorrect lower tick net liquidity"
        );

        (tickInitialized, tickLiquidityGross, tickLiquidityNet, , ) = expected
            .pool
            .ticks(expected.upperTick);
        assertTrue(tickInitialized);
        assertEq(
            tickLiquidityGross,
            expected.position.liquidity,
            "incorrect upper tick gross liquidity"
        );
        assertEq(
            tickLiquidityNet,
            -int128(expected.position.liquidity),
            "incorrect upper tick net liquidity"
        );

        assertTrue(tickInBitMap(expected.pool, expected.lowerTick));
        assertTrue(tickInBitMap(expected.pool, expected.upperTick));

        (uint160 sqrtPriceX96, int24 currentTick) = expected.pool.slot0();
        assertEq(sqrtPriceX96, expected.sqrtPriceX96, "invalid current sqrtP");
        assertEq(currentTick, expected.tick, "invalid current tick");
        assertEq(
            expected.pool.liquidity(),
            expected.currentLiquidity,
            "invalid current liquidity"
        );
    }

    struct ExpectedStateAfterBurn {
        UniswapV3Pool pool;
        ERC20Mintable token0;
        ERC20Mintable token1;
        uint256 amount0;
        uint256 amount1;
        int24 lowerTick;
        int24 upperTick;
        Position.Info position;
        uint128 currentLiquidity;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    function assertBurnState(ExpectedStateAfterBurn memory expected) internal {
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
        (
            uint128 posLiquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = expected.pool.positions(positionKey);
        assertEq(
            posLiquidity,
            expected.position.liquidity,
            "incorrect position liquidity"
        );
        assertEq(
            feeGrowthInside0LastX128,
            expected.position.feeGrowthInside0LastX128,
            "incorrect position fee growth for token0"
        );
        assertEq(
            feeGrowthInside1LastX128,
            expected.position.feeGrowthInside1LastX128,
            "incorrect position fee growth for token1"
        );
        assertEq(
            tokensOwed0,
            expected.position.tokensOwed0,
            "incorrect position tokens owed for token0"
        );
        assertEq(
            tokensOwed1,
            expected.position.tokensOwed1,
            "incorrect position tokens owed for token1"
        );

        (
            bool tickInitialized,
            uint128 tickLiquidityGross,
            int128 tickLiquidityNet,
            ,

        ) = expected.pool.ticks(expected.lowerTick);
        assertTrue(tickInitialized);
        assertEq(
            tickLiquidityGross,
            expected.position.liquidity,
            "incorrect lower tick gross liquidity"
        );
        assertEq(
            tickLiquidityNet,
            int128(expected.position.liquidity),
            "incorrect lower tick net liquidity"
        );

        (tickInitialized, tickLiquidityGross, tickLiquidityNet, , ) = expected
            .pool
            .ticks(expected.upperTick);
        assertTrue(tickInitialized);
        assertEq(
            tickLiquidityGross,
            expected.position.liquidity,
            "incorrect upper tick gross liquidity"
        );
        assertEq(
            tickLiquidityNet,
            -int128(expected.position.liquidity),
            "incorrect upper tick net liquidity"
        );

        assertFalse(tickInBitMap(expected.pool, expected.lowerTick));
        assertFalse(tickInBitMap(expected.pool, expected.upperTick));

        (uint160 sqrtPriceX96, int24 currentTick) = expected.pool.slot0();
        assertEq(sqrtPriceX96, expected.sqrtPriceX96, "invalid current sqrtP");
        assertEq(currentTick, expected.tick, "invalid current tick");
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
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
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

        assertEq(
            expected.pool.feeGrowthGlobal0X128(),
            expected.feeGrowthGlobal0X128,
            "invalid fee growth for token0"
        );
        assertEq(
            expected.pool.feeGrowthGlobal1X128(),
            expected.feeGrowthGlobal1X128,
            "invalid fee growth for token1"
        );
    }

    struct ExpectedPosition {
        UniswapV3Pool pool;
        int24 lowerTick;
        int24 upperTick;
        Position.Info position;
    }

    function assertPosition(ExpectedPosition memory params) public {
        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), params.lowerTick, params.upperTick)
        );
        (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = params.pool.positions(positionKey);

        assertEq(
            liquidity,
            params.position.liquidity,
            "incorrect position liquidity"
        );
        assertEq(
            feeGrowthInside0LastX128,
            params.position.feeGrowthInside0LastX128,
            "incorrect position fee growth for token0"
        );
        assertEq(
            feeGrowthInside1LastX128,
            params.position.feeGrowthInside1LastX128,
            "incorrect position fee growth for token1"
        );
        assertEq(
            tokensOwed0,
            params.position.tokensOwed0,
            "incorrect position tokens owed for token0"
        );
        assertEq(
            tokensOwed1,
            params.position.tokensOwed1,
            "incorrect position tokens owed for token1"
        );
    }

    function tickInBitMap(UniswapV3Pool pool, int24 tick_)
        internal
        view
        returns (bool initialized)
    {
        tick_ /= int24(pool.tickSpacing());

        int16 wordPos = int16(tick_ >> 8);
        uint8 bitPos = uint8(uint24(tick_ % 256));

        uint256 word = pool.tickBitmap(wordPos);

        initialized = (word & (1 << bitPos)) != 0;
    }
}
