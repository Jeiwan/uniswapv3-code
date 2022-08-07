// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./UniswapV3Pool.sol";

contract UniswapV3Factory is IUniswapV3PoolDeployer {
    error PoolAlreadyExists();
    error ZeroAddressNotAllowed();
    error TokensMustBeDifferent();
    error UnsupportedTickSpacing();

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        address pool
    );

    PoolParameters public parameters;

    mapping(uint24 => uint24) public tickSpacings;
    mapping(address => mapping(address => mapping(uint24 => address)))
        public pools;

    constructor() {
        tickSpacings[500] = 10;
        tickSpacings[3000] = 60;
    }

    function createPool(
        address tokenX,
        address tokenY,
        uint24 fee
    ) public returns (address pool) {
        if (tokenX == tokenY) revert TokensMustBeDifferent();
        if (tickSpacings[fee] == 0) revert UnsupportedTickSpacing();

        (tokenX, tokenY) = tokenX < tokenY
            ? (tokenX, tokenY)
            : (tokenY, tokenX);

        if (tokenX == address(0)) revert ZeroAddressNotAllowed();
        if (pools[tokenX][tokenY][fee] != address(0))
            revert PoolAlreadyExists();

        parameters = PoolParameters({
            factory: address(this),
            token0: tokenX,
            token1: tokenY,
            tickSpacing: tickSpacings[fee],
            fee: fee
        });

        pool = address(
            new UniswapV3Pool{
                salt: keccak256(abi.encodePacked(tokenX, tokenY, fee))
            }()
        );

        delete parameters;

        pools[tokenX][tokenY][fee] = pool;
        pools[tokenY][tokenX][fee] = pool;

        emit PoolCreated(tokenX, tokenY, fee, pool);
    }
}
