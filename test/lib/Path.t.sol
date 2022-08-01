// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../../src/lib/Path.sol";

import "forge-std/console.sol";

contract PathTest is Test {
    function testHasMultiplePools() public {
        bytes memory path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1))
        );
        assertFalse(Path.hasMultiplePools(path));

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2))
        );
        assertTrue(Path.hasMultiplePools(path));

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2)),
            bytes20(address(0x3)),
            bytes3(uint24(3))
        );
        assertTrue(Path.hasMultiplePools(path));
    }

    function testGetFirstPool() public {
        bytes memory path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1))
        );
        assertEq(
            Path.getFirstPool(path),
            bytes.concat(bytes20(address(0x1)), bytes3(uint24(1)))
        );

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2))
        );
        assertEq(
            Path.getFirstPool(path),
            bytes.concat(bytes20(address(0x1)), bytes3(uint24(1)))
        );
    }

    function testSkipToken() public {
        bytes memory path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1))
        );
        assertEq(Path.skipToken(path), "");

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2))
        );
        assertEq(
            Path.skipToken(path),
            bytes.concat(bytes20(address(0x2)), bytes3(uint24(2)))
        );
    }
}
