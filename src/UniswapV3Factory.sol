// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./UniswapV3Pool.sol";

contract UniswapV3Factory is IUniswapV3PoolDeployer {
    error NotOwner();
    error TokensMustBeDifferent();
    error TokenXCannotBeZero();
    error PoolAlreadyExists();

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed tickSpacing
    );

    address public owner;
    PoolParameters public parameters;

    mapping(uint24 => bool) public tickSpacings;
    mapping(address => mapping(address => mapping(uint24 => address)))
        public pools;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;

        tickSpacings[10] = true;
        tickSpacings[60] = true;
    }

    function createPool(
        address tokenX,
        address tokenY,
        uint24 tickSpacing
    ) public returns (address pool) {
        if (tokenX == tokenY) revert TokensMustBeDifferent();

        (tokenX, tokenY) = tokenX < tokenY
            ? (tokenX, tokenY)
            : (tokenY, tokenX);

        if (tokenX == address(0)) revert TokenXCannotBeZero();
        if (pools[tokenX][tokenY][tickSpacing] != address(0))
            revert PoolAlreadyExists();

        parameters = PoolParameters({
            factory: address(this),
            token0: tokenX,
            token1: tokenY,
            tickSpacing: tickSpacing
        });

        pool = address(
            new UniswapV3Pool{
                salt: keccak256(abi.encode(tokenX, tokenY, tickSpacing))
            }()
        );

        pools[tokenX][tokenY][tickSpacing] = pool;
        pools[tokenY][tokenX][tickSpacing] = pool;

        delete parameters;
    }
}
