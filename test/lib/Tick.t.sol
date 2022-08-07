// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../../src/lib/Tick.sol";

contract TickTest is Test {
    using Tick for mapping(int24 => Tick.Info);
    mapping(int24 => Tick.Info) ticks;

    function testGetFeeGrowthInsideUninitialized() public {
        // current tick is inside the range
        (uint256 fee0, uint256 fee1) = ticks.getFeeGrowthInside(
            -2,
            2,
            0,
            15,
            15
        );
        assertEq(fee0, 15);
        assertEq(fee1, 15);

        // current tick is above the range
        (fee0, fee1) = ticks.getFeeGrowthInside(-2, 2, 3, 15, 15);
        assertEq(fee0, 0);
        assertEq(fee1, 0);

        // current tick is below the range
        (fee0, fee1) = ticks.getFeeGrowthInside(-2, 2, -3, 15, 15);
        assertEq(fee0, 0);
        assertEq(fee1, 0);
    }

    function testGetFeeGrowthInsideInitialized() public {
        // subtracts upper tick when below
        ticks[2] = Tick.Info({
            initialized: true,
            liquidityGross: 0,
            liquidityNet: 0,
            feeGrowthOutside0X128: 2,
            feeGrowthOutside1X128: 3
        });
        (uint256 fee0, uint256 fee1) = ticks.getFeeGrowthInside(
            -2,
            2,
            0,
            15,
            15
        );
        assertEq(fee0, 13);
        assertEq(fee1, 12);

        delete ticks[2];
        // subtracts lower tick when above
        ticks[-2] = Tick.Info({
            initialized: true,
            liquidityGross: 0,
            liquidityNet: 0,
            feeGrowthOutside0X128: 2,
            feeGrowthOutside1X128: 3
        });
        (fee0, fee1) = ticks.getFeeGrowthInside(-2, 2, 0, 15, 15);
        assertEq(fee0, 13);
        assertEq(fee1, 12);

        // subtracts upper and lower when inside
        ticks[2] = Tick.Info({
            initialized: true,
            liquidityGross: 0,
            liquidityNet: 0,
            feeGrowthOutside0X128: 4,
            feeGrowthOutside1X128: 1
        });
        (fee0, fee1) = ticks.getFeeGrowthInside(-2, 2, 0, 15, 15);
        assertEq(fee0, 9);
        assertEq(fee1, 11);
    }
}
