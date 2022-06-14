// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

library Math {
    function divRoundingUp(uint256 a, uint256 b)
        internal
        pure
        returns (uint256 c)
    {
        unchecked {
            c = a / b + (a % b > 0 ? 1 : 0);
        }
    }

    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256 r) {
        r = (a * b) / c;
    }

    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256 r) {
        r = mulDiv(a, b, c);
        if (mulmod(a, b, c) > 0) {
            require(r < type(uint256).max);
            r++;
        }
    }
}
