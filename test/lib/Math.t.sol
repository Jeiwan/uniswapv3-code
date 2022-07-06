// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../../src/lib/Math.sol";

contract MathTest is Test {
    function testCalcAmount0Delta() public {
        uint256 amount0 = Math.calcAmount0Delta(
            5602277097478614198912276234240,
            5875717789736564987741329162240,
            1517882343751509868544
        );

        assertEq(0, amount0);
    }
}
