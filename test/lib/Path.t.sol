// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../../src/lib/Path.sol";

contract PathTest is Test {
    function testHasMultiplePools() public {
        bytes memory path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2))
        );
        assertFalse(Path.hasMultiplePools(path));

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2)),
            bytes20(address(0x3))
        );
        assertTrue(Path.hasMultiplePools(path));

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2)),
            bytes20(address(0x3)),
            bytes3(uint24(3)),
            bytes20(address(0x4))
        );
        assertTrue(Path.hasMultiplePools(path));
    }

    function testGetFirstPool() public {
        bytes memory path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2))
        );
        assertEq(
            Path.getFirstPool(path),
            bytes.concat(
                bytes20(address(0x1)),
                bytes3(uint24(1)),
                bytes20(address(0x2))
            )
        );

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2)),
            bytes20(address(0x3))
        );
        assertEq(
            Path.getFirstPool(path),
            bytes.concat(
                bytes20(address(0x1)),
                bytes3(uint24(1)),
                bytes20(address(0x2))
            )
        );
    }

    function testSkipToken() public {
        bytes memory path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2))
        );
        assertEq(Path.skipToken(path), bytes.concat(bytes20(address(0x2))));

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2)),
            bytes20(address(0x3))
        );
        assertEq(
            Path.skipToken(path),
            bytes.concat(
                bytes20(address(0x2)),
                bytes3(uint24(2)),
                bytes20(address(0x3))
            )
        );
    }

    function testDecodeFirstPool() public {
        bytes memory path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2))
        );

        (address tokenIn, address tokenOut, uint24 tickSpacing) = Path
            .decodeFirstPool(path);
        assertEq(tokenIn, address(0x1));
        assertEq(tokenOut, address(0x2));
        assertEq(tickSpacing, uint24(1));
    }

    function testNumPools() public {
        bytes memory path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2))
        );

        assertEq(Path.numPools(path), 1);

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2)),
            bytes20(address(0x3))
        );

        assertEq(Path.numPools(path), 2);

        path = bytes.concat(
            bytes20(address(0x1)),
            bytes3(uint24(1)),
            bytes20(address(0x2)),
            bytes3(uint24(2)),
            bytes20(address(0x3)),
            bytes3(uint24(3)),
            bytes20(address(0x4))
        );

        assertEq(Path.numPools(path), 3);
    }
}
