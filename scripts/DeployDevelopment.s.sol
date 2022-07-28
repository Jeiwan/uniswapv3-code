// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/console.sol";
import "forge-std/Script.sol";

import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Manager.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Quoter.sol";
import "../test/ERC20Mintable.sol";
import "../test/TestUtils.sol";

contract DeployDevelopment is Script, TestUtils {
    function run() public {
        uint256 wethBalance = 10 ether;
        uint256 usdcBalance = 100000 ether;
        uint160 currentSqrtP = sqrtP(5000);

        // DEPLOYING
        vm.startBroadcast();

        ERC20Mintable token0 = new ERC20Mintable("Wrapped Ether", "WETH", 18);
        ERC20Mintable token1 = new ERC20Mintable("USD Coin", "USDC", 18);

        UniswapV3Factory factory = new UniswapV3Factory();
        UniswapV3Pool pool = UniswapV3Pool(
            factory.createPool(address(token0), address(token1), 1)
        );
        pool.initialize(currentSqrtP);

        UniswapV3Manager manager = new UniswapV3Manager(address(factory));
        UniswapV3Quoter quoter = new UniswapV3Quoter(address(factory));

        token0.mint(msg.sender, wethBalance);
        token1.mint(msg.sender, usdcBalance);

        vm.stopBroadcast();
        // DONE

        console.log("WETH address", address(token0));
        console.log("USDC address", address(token1));
        console.log("Factory address", address(factory));
        console.log("Pool address", address(pool));
        console.log("Manager address", address(manager));
        console.log("Quoter address", address(quoter));
    }
}
