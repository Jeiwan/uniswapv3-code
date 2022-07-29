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
}
