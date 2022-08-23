// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3FactoryTest is Test, TestUtils {
    ERC20Mintable weth;
    ERC20Mintable usdc;
    UniswapV3Factory factory;

    function setUp() public {
        weth = new ERC20Mintable("Ether", "ETH", 18);
        usdc = new ERC20Mintable("USDC", "USDC", 18);
        factory = new UniswapV3Factory();
    }

    function testCreatePool() public {
        address poolAddress = factory.createPool(
            address(weth),
            address(usdc),
            500
        );

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        assertEq(
            factory.pools(address(usdc), address(weth), 500),
            poolAddress,
            "invalid pool address in the registry"
        );

        assertEq(
            factory.pools(address(weth), address(usdc), 500),
            poolAddress,
            "invalid pool address in the registry (reverse order)"
        );

        assertEq(pool.factory(), address(factory), "invalid factory address");
        assertEq(pool.token0(), address(usdc), "invalid weth address");
        assertEq(pool.token1(), address(weth), "invalid usdc address");
        assertEq(pool.tickSpacing(), 10, "invalid tick spacing");
        assertEq(pool.fee(), 500, "invalid fee");

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
    }

    function testCreatePoolUnsupportedFee() public {
        vm.expectRevert(encodeError("UnsupportedFee()"));
        factory.createPool(address(weth), address(usdc), 300);
    }

    function testCreatePoolIdenticalTokens() public {
        vm.expectRevert(encodeError("TokensMustBeDifferent()"));
        factory.createPool(address(weth), address(weth), 500);
    }

    function testCreateZeroTokenAddress() public {
        vm.expectRevert(encodeError("ZeroAddressNotAllowed()"));
        factory.createPool(address(weth), address(0), 500);
    }

    function testCreateAlreadyExists() public {
        factory.createPool(address(weth), address(usdc), 500);

        vm.expectRevert(encodeError("PoolAlreadyExists()"));
        factory.createPool(address(weth), address(usdc), 500);
    }
}
