// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./TestUtils.sol";

contract TestUtilsTest is Test, TestUtils {
    function testNearestUsableTick() public {
        assertEq(nearestUsableTick(85176, 60), 85200);
        assertEq(nearestUsableTick(85170, 60), 85200);
        assertEq(nearestUsableTick(85169, 60), 85140);

        assertEq(nearestUsableTick(85200, 60), 85200);
        assertEq(nearestUsableTick(85140, 60), 85140);
    }

    function testTick60() public {
        assertEq(tick60(5000), 85200);
        assertEq(tick60(4545), 84240);
        assertEq(tick60(6250), 87420);
    }

    function testSqrtP60() public {
        assertEq(sqrtP60(5000), 5608950122784459951015918491039);
        assertEq(sqrtP60(4545), 5346092701810166522520541901099);
        assertEq(sqrtP60(6250), 6267377518277060417829549285552);
    }
}
