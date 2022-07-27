// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3FactoryTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Factory factory;

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
        factory = new UniswapV3Factory();
    }

    function testCreatePool() public {
        address poolAddress = factory.createPool(
            address(token0),
            address(token1),
            1
        );

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        assertEq(
            factory.pools(address(token1), address(token0), 1),
            poolAddress,
            "invalid pool address in the registry"
        );

        assertEq(
            factory.pools(address(token0), address(token1), 1),
            poolAddress,
            "invalid pool address in the registry (reverse order)"
        );

        assertEq(pool.factory(), address(factory), "invalid factory address");
        assertEq(pool.token0(), address(token1), "invalid token0 address");
        assertEq(pool.token1(), address(token0), "invalid token1 address");
        assertEq(pool.tickSpacing(), 1, "invalid tick spacing");

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(sqrtPriceX96, 0, "invalid sqrtPriceX96");
        assertEq(tick, 0, "invalid tick");
    }

    function testCreatePoolIdenticalTokens() public {
        vm.expectRevert(encodeError("TokensMustBeDifferent()"));
        factory.createPool(address(token0), address(token0), 1);
    }

    function testCreateZeroTokenAddress() public {
        vm.expectRevert(encodeError("TokenXCannotBeZero()"));
        factory.createPool(address(token0), address(0), 1);
    }

    function testCreateAlreadyExists() public {
        factory.createPool(address(token0), address(token1), 1);

        vm.expectRevert(encodeError("PoolAlreadyExists()"));
        factory.createPool(address(token0), address(token1), 1);
    }
}
