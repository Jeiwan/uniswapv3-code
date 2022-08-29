// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

import "solmate/tokens/ERC721.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./lib/LiquidityMath.sol";
import "./lib/PoolAddress.sol";
import "./lib/TickMath.sol";

contract UniswapV3NFTManager is ERC721 {
    error NotAuthorized();
    error NotEnoughLiquidity();
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);
    error WrongToken();

    struct TokenPosition {
        address pool;
        int24 lowerTick;
        int24 upperTick;
    }

    uint256 public totalSupply;

    address public immutable factory;

    mapping(uint256 => TokenPosition) public positions;

    modifier isApprovedOrOwner(uint256 tokenId) {
        address owner = ownerOf(tokenId);
        if (
            msg.sender != owner ||
            !isApprovedForAll[owner][msg.sender] ||
            getApproved[tokenId] != msg.sender
        ) revert NotAuthorized();

        _;
    }

    constructor(address factoryAddress)
        ERC721("UnsiwapV3 NFT Positions", "UNIV3")
    {
        factory = factoryAddress;
    }

    struct MintParams {
        address recipient;
        address tokenA;
        address tokenB;
        uint24 fee;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    function mint(MintParams calldata params) public returns (uint256 tokenId) {
        IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);

        _addLiquidity(
            pool,
            params.lowerTick,
            params.upperTick,
            params.amount0Desired,
            params.amount1Desired,
            params.amount0Min,
            params.amount1Min
        );

        tokenId = totalSupply++;
        _mint(params.recipient, tokenId);

        positions[tokenId] = TokenPosition({
            pool: address(pool),
            lowerTick: params.lowerTick,
            upperTick: params.upperTick
        });
    }

    struct AddLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    function addLiquidity(AddLiquidityParams calldata params)
        public
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        TokenPosition memory tokenPosition = positions[params.tokenId];
        if (tokenPosition.pool == address(0x00)) revert WrongToken();

        (liquidity, amount0, amount1) = _addLiquidity(
            IUniswapV3Pool(tokenPosition.pool),
            tokenPosition.lowerTick,
            tokenPosition.upperTick,
            params.amount0Desired,
            params.amount1Desired,
            params.amount0Min,
            params.amount1Min
        );
    }

    struct RemoveLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
    }

    // TODO: add slippage check
    function removeLiquidity(RemoveLiquidityParams memory params)
        public
        isApprovedOrOwner(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        TokenPosition memory tokenPosition = positions[params.tokenId];
        if (tokenPosition.pool == address(0x00)) revert WrongToken();

        IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);

        (uint128 availableLiquidity, , , , ) = pool.positions(
            positionKey(tokenPosition)
        );
        if (params.liquidity > availableLiquidity) revert NotEnoughLiquidity();

        (amount0, amount1) = pool.burn(
            tokenPosition.lowerTick,
            tokenPosition.upperTick,
            params.liquidity
        );
    }

    // function collect()

    // function burn()

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function _addLiquidity(
        IUniswapV3Pool pool,
        int24 lowerTick,
        int24 upperTick,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    )
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (uint160 sqrtPriceX96, , , , ) = pool.slot0();
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(upperTick);

        liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            amount0Desired,
            amount1Desired
        );

        (amount0, amount1) = pool.mint(
            address(this),
            lowerTick,
            upperTick,
            liquidity,
            abi.encode(
                IUniswapV3Pool.CallbackData({
                    token0: pool.token0(),
                    token1: pool.token1(),
                    payer: msg.sender
                })
            )
        );

        if (amount0 < amount0Min || amount1 < amount1Min)
            revert SlippageCheckFailed(amount0, amount1);
    }

    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) internal view returns (IUniswapV3Pool pool) {
        (token0, token1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);
        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, fee)
        );
    }

    function positionKey(TokenPosition memory position)
        internal
        returns (bytes32 key)
    {
        key = keccak256(
            abi.encodePacked(
                address(this),
                position.lowerTick,
                position.upperTick
            )
        );
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        IUniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (IUniswapV3Pool.CallbackData)
        );

        IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
        IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }
}
