// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "../src/UniswapV3Pool.sol";

abstract contract TestUtils {
    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function encodeExtra(
        address token0_,
        address token1_,
        address payer
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                UniswapV3Pool.CallbackData({
                    token0: token0_,
                    token1: token1_,
                    payer: payer
                })
            );
    }

    function tickInBitMap(UniswapV3Pool pool, int24 tick)
        internal
        view
        returns (bool initialized)
    {
        int16 wordPos = int16(tick >> 8);
        uint8 bitPos = uint8(uint24(tick % 256));

        uint256 word = pool.tickBitmap(wordPos);

        initialized = (word & (1 << bitPos)) != 0;
    }
}
