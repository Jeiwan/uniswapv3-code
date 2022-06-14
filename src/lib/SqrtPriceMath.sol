// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./FixedPoint96.sol";
import "./Math.sol";

library SqrtPriceMath {
    function getAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256) {
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtPriceBX96 - sqrtPriceAX96;

        require(sqrtPriceAX96 > 0);

        return
            roundUp
                ? Math.divRoundingUp(
                    Math.mulDivRoundingUp(
                        numerator1,
                        numerator1,
                        sqrtPriceBX96
                    ),
                    sqrtPriceAX96
                )
                : Math.mulDiv(numerator1, numerator2, sqrtPriceBX96) /
                    sqrtPriceAX96;
    }

    function getAmount1Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256) {
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        return
            roundUp
                ? Math.mulDivRoundingUp(
                    liquidity,
                    sqrtPriceBX96 - sqrtPriceAX96,
                    FixedPoint96.Q96
                )
                : Math.mulDiv(
                    liquidity,
                    sqrtPriceBX96 - sqrtPriceAX96,
                    FixedPoint96.Q96
                );
    }

    function getAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        int128 liquidity
    ) internal pure returns (uint256) {
        return
            liquidity < 0
                ? 0 // TODO: implement removal of liquditiy
                : getAmount0Delta(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(liquidity),
                    true
                );
    }

    function getAmount1Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        int128 liquidity
    ) internal pure returns (uint256) {
        return
            liquidity < 0
                ? 0 // TODO: implement removal of liquditiy
                : getAmount0Delta(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(liquidity),
                    true
                );
    }
}
