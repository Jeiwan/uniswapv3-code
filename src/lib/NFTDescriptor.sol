// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "openzeppelin/utils/Base64.sol";
import "openzeppelin/utils/Strings.sol";

import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV3Pool.sol";

library NFTRenderer {
    struct RenderParams {
        address pool;
        address owner;
        int24 lowerTick;
        int24 upperTick;
        uint24 fee;
    }

    function render(RenderParams memory params)
        internal
        view
        returns (string memory)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(params.pool);
        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());

        string memory dataURI = string.concat(
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 160'>",
            "<style>.tokens { font: bold 10px sans-serif; }",
            ".fee { font: normal 9px sans-serif; }",
            ".tick { font: normal 6px sans-serif; }</style>",
            renderBackground(params.owner, params.lowerTick, params.upperTick),
            renderTop(token0.symbol(), token1.symbol(), params.fee),
            renderBottom(params.lowerTick, params.upperTick),
            "</svg>"
        );

        return
            string.concat(
                "data:application/json;base64,",
                Base64.encode(bytes(dataURI))
            );
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function renderBackground(
        address owner,
        int24 lowerTick,
        int24 upperTick
    ) internal pure returns (string memory background) {
        bytes32 key = keccak256(abi.encodePacked(owner, lowerTick, upperTick));
        uint256 hue = uint256(key) % 360;

        background = string.concat(
            "<rect width=100 height=160 fill='hsl(",
            Strings.toString(hue),
            ",40%,40%)'/>",
            "<rect x=10 y=10 width=80 height=140 rx=5 ry=5 fill='hsl(",
            Strings.toString(hue),
            ",100%,50%)' stroke='#000'/>"
        );
    }

    function renderTop(
        string memory symbol0,
        string memory symbol1,
        uint24 fee
    ) internal pure returns (string memory top) {
        top = string.concat(
            "<rect x=10 y=29 width=80 height=14/>",
            "<text x=13 y=40 class='tokens' fill='#fff'>",
            symbol0,
            "/",
            symbol1,
            "</text>"
            "<rect x=10 y=44 width=80 height=10/>",
            "<text x=13 y=40 dy=12 class='fee' fill='#fff'>",
            feeToText(fee),
            "</text>"
        );
    }

    function renderBottom(int24 lowerTick, int24 upperTick)
        internal
        pure
        returns (string memory bottom)
    {
        bottom = string.concat(
            "<rect x=10 y=114 width=80 height=8/>",
            "<text x=13 y=120 class='tick' fill='#fff'>Lower tick: ",
            tickToText(lowerTick),
            "</text>",
            "<rect x=10 y=124 width=80 height=8/>",
            "<text x=13 y=120 dy=10 class='tick' fill='#fff'>Upper tick: ",
            tickToText(upperTick),
            "</text>"
        );
    }

    function feeToText(uint256 fee)
        internal
        pure
        returns (string memory feeString)
    {
        if (fee == 500) {
            feeString = "0.05%";
        } else if (fee == 3000) {
            feeString = "0.3%";
        }
    }

    function tickToText(int24 tick)
        internal
        pure
        returns (string memory tickString)
    {
        tickString = string.concat(
            tick < 0 ? "-" : "",
            tick < 0
                ? Strings.toString(uint256(uint24(-tick)))
                : Strings.toString(uint256(uint24(tick)))
        );
    }
}
