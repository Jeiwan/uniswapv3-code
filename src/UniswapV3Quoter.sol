// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3Pool.sol";

contract UniswapV3Quoter {
    struct QuoteParams {
        address pool;
        uint256 amountIn;
        bool zeroForOne;
    }

    function quote(QuoteParams memory params)
        public
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            int24 tickAfter
        )
    {
        IUniswapV3Pool pool = IUniswapV3Pool(params.pool);

        try
            pool.swap(
                address(this),
                params.zeroForOne,
                params.amountIn,
                abi.encode(params.pool, params.zeroForOne)
            )
        {} catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    function parseRevertReason(bytes memory reason)
        private
        pure
        returns (
            uint256 amount,
            uint160 sqrtPriceX96After,
            int24 tickAfter
        )
    {
        if (reason.length != 96) {
            if (reason.length < 68) revert("Unexpected error");
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256, uint160, int24));
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external view {
        (address pool, bool zeroForOne) = abi.decode(data, (address, bool));

        (
            bool isExactInput,
            uint256 amountToPay,
            uint256 amountReceived
        ) = amount0Delta > 0
                ? (zeroForOne, uint256(amount0Delta), uint256(-amount1Delta))
                : (!zeroForOne, uint256(amount1Delta), uint256(-amount0Delta));

        (uint160 sqrtPriceX96After, int24 tickAfter) = IUniswapV3Pool(pool)
            .slot0();

        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                mstore(add(ptr, 0x20), sqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 96)
            }
        } else {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                mstore(add(ptr, 0x20), sqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 96)
            }
        }
    }
}
