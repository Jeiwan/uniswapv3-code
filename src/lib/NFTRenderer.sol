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
        string memory symbol0 = token0.symbol();
        string memory symbol1 = token1.symbol();

        string memory image = string.concat(
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 480'>",
            "<style>.tokens { font: bold 30px sans-serif; }",
            ".fee { font: normal 26px sans-serif; }",
            ".tick { font: normal 18px sans-serif; }</style>",
            renderBackground(params.owner, params.lowerTick, params.upperTick),
            renderTop(symbol0, symbol1, params.fee),
            renderBottom(params.lowerTick, params.upperTick),
            "</svg>"
        );

        string memory description = renderDescription(
            symbol0,
            symbol1,
            params.fee,
            params.lowerTick,
            params.upperTick
        );

        string memory json = string.concat(
            '{"name":"Uniswap V3 Position",',
            '"description":"',
            description,
            '",',
            '"image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(image)),
            '"}'
        );

        return
            string.concat(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
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
            '<rect width="300" height="480" fill="hsl(',
            Strings.toString(hue),
            ',40%,40%)"/>',
            '<rect x="30" y="30" width="240" height="420" rx="15" ry="15" fill="hsl(',
            Strings.toString(hue),
            ',100%,50%)" stroke="#000"/>'
        );
    }

    function renderTop(
        string memory symbol0,
        string memory symbol1,
        uint24 fee
    ) internal pure returns (string memory top) {
        top = string.concat(
            '<rect x="30" y="87" width="240" height="42"/>',
            '<text x="39" y="120" class="tokens" fill="#fff">',
            symbol0,
            "/",
            symbol1,
            "</text>"
            '<rect x="30" y="132" width="240" height="30"/>',
            '<text x="39" y="120" dy="36" class="fee" fill="#fff">',
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
            '<rect x="30" y="342" width="240" height="24"/>',
            '<text x="39" y="360" class="tick" fill="#fff">Lower tick: ',
            tickToText(lowerTick),
            "</text>",
            '<rect x="30" y="372" width="240" height="24"/>',
            '<text x="39" y="360" dy="30" class="tick" fill="#fff">Upper tick: ',
            tickToText(upperTick),
            "</text>"
        );
    }

    function renderDescription(
        string memory symbol0,
        string memory symbol1,
        uint24 fee,
        int24 lowerTick,
        int24 upperTick
    ) internal pure returns (string memory description) {
        description = string.concat(
            symbol0,
            "/",
            symbol1,
            " ",
            feeToText(fee),
            ", Lower tick: ",
            tickToText(lowerTick),
            ", Upper text: ",
            tickToText(upperTick)
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
