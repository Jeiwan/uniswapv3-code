// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "../src/lib/Position.sol";

contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool shouldTransferInCallback = true;

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMint() public {
        token0.mint(address(this), 1 ether);
        token1.mint(address(this), 5_000 ether);

        int24 currentTick = 85176;
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(5602277097478614198912276234240), // current price, sqrt(5000) * 2**96
            currentTick
        );

        (uint256 amount0, uint256 amount1) = pool.mint(
            address(this),
            lowerTick,
            upperTick,
            liquidity
        );

        uint256 expectedAmount0 = 0.998976618347425280 ether;
        uint256 expectedAmount1 = 5000 ether;
        assertEq(amount0, expectedAmount0, "incorrect amount0");
        assertEq(amount1, expectedAmount1, "incorrect amount1");
        assertEq(token0.balanceOf(address(pool)), expectedAmount0);
        assertEq(token1.balanceOf(address(pool)), expectedAmount1);

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), lowerTick, upperTick)
        );
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(posLiquidity, liquidity);

        (bool initialized, uint128 tickLiquidity) = pool.ticks(lowerTick);
        assertTrue(initialized);
        assertEq(tickLiquidity, liquidity);

        (initialized, tickLiquidity) = pool.ticks(upperTick);
        assertTrue(initialized);
        assertEq(tickLiquidity, liquidity);
    }

    function testMintInvalidTickRangeLower() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), -887273, 0, 0);
    }

    function testMintInvalidTickRangeUpper() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("InvalidTickRange()"));
        pool.mint(address(this), 0, 887273, 0);
    }

    function testMintZeroLiquidity() public {
        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(1),
            0
        );

        vm.expectRevert(encodeError("ZeroLiquidity()"));
        pool.mint(address(this), 0, 1, 0);
    }

    function testMintInsufficientTokenBalance() public {
        shouldTransferInCallback = false;

        int24 currentTick = 85176;
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(5602277097478614198912276234240), // current price, sqrt(5000) * 2**96
            currentTick
        );

        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.mint(address(this), lowerTick, upperTick, liquidity);
    }

    function testSwapBuyEth() public {
        token0.mint(address(this), 1 ether);
        token1.mint(address(this), 5_000 ether);

        int24 currentTick = 85176;
        int24 lowerTick = 84222;
        int24 upperTick = 86129;
        uint128 liquidity = 1517882343751509868544;

        pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            uint160(5602277097478614198912276234240), // current price, sqrt(5000) * 2**96
            currentTick
        );

        (uint256 balance0, uint256 balance1) = pool.mint(
            address(this),
            lowerTick,
            upperTick,
            liquidity
        );

        token1.mint(address(this), 42 ether);

        int256 userBalance0Before = int256(token0.balanceOf(address(this)));

        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            42 ether
        );

        assertEq(amount0Delta, -0.008396714242162444 ether, "invalut ETH out");
        assertEq(amount1Delta, 42 ether, "invalut USDC in");

        assertEq(
            token0.balanceOf(address(this)),
            uint256(userBalance0Before - amount0Delta),
            "invalid user ETH balance"
        );
        assertEq(
            token1.balanceOf(address(this)),
            0,
            "invalid user USDC balance"
        );

        assertEq(
            token0.balanceOf(address(pool)),
            uint256(int256(balance0) + amount0Delta),
            "invalid pool ETH balance"
        );
        assertEq(
            token1.balanceOf(address(pool)),
            uint256(int256(balance1) + amount1Delta),
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

    function uniswapV3SwapCallback(int256 amount0, int256 amount1) public {
        if (amount0 > 0) {
            token0.transfer(msg.sender, uint256(amount0));
        }

        if (amount1 > 0) {
            token1.transfer(msg.sender, uint256(amount1));
        }
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1) public {
        if (shouldTransferInCallback) {
            token0.transfer(msg.sender, amount0);
            token1.transfer(msg.sender, amount1);
        }
    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }
}
