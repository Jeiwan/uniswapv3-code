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
        uint256 uniBalance = 100000 ether;

        // DEPLOYING STARGED
        vm.startBroadcast();

        ERC20Mintable weth = new ERC20Mintable("Wrapped Ether", "WETH", 18);
        ERC20Mintable usdc = new ERC20Mintable("USD Coin", "USDC", 18);
        ERC20Mintable uni = new ERC20Mintable("Uniswap Coin", "UNI", 18);

        UniswapV3Factory factory = new UniswapV3Factory();
        UniswapV3Manager manager = new UniswapV3Manager(address(factory));
        UniswapV3Quoter quoter = new UniswapV3Quoter(address(factory));

        UniswapV3Pool wethUsdc = UniswapV3Pool(
            factory.createPool(address(weth), address(usdc), 60)
        );
        wethUsdc.initialize(sqrtP(5000));

        UniswapV3Pool wethUni = UniswapV3Pool(
            factory.createPool(address(weth), address(uni), 60)
        );
        wethUni.initialize(sqrtP(13));

        weth.mint(msg.sender, wethBalance);
        usdc.mint(msg.sender, usdcBalance);
        uni.mint(msg.sender, uniBalance);

        vm.stopBroadcast();
        // DEPLOYING DONE

        console.log("WETH address", address(weth));
        console.log("USDC address", address(usdc));
        console.log("UNI address", address(uni));
        console.log("Factory address", address(factory));
        console.log("Manager address", address(manager));
        console.log("Quoter address", address(quoter));
        console.log("WETH/USDC address", address(wethUsdc));
        console.log("WETH/UNI address", address(wethUni));
    }
}
