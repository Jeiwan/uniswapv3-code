// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {Test, stdError} from "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./TestUtils.sol";

import "../src/lib/LiquidityMath.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3NFTManager.sol";

contract UniswapV3NFTManagerTest is Test, TestUtils {
    uint24 constant FEE = 3000;
    uint24 constant STABLE_FEE = 500;
    uint256 constant INIT_PRICE = 5000;
    uint256 constant STABLE_PRICE = 1;
    uint256 constant UNI_PRICE = 10;
    uint256 constant USER_WETH_BALANCE = 10_000 ether;
    uint256 constant USER_USDC_BALANCE = 1_000_000 ether;
    uint256 constant USER_DAI_BALANCE = 1_000_000 ether;
    uint256 constant USER_UNI_BALANCE = 10_000 ether;

    ERC20Mintable weth;
    ERC20Mintable usdc;
    ERC20Mintable dai;
    ERC20Mintable uni;
    UniswapV3Factory factory;
    UniswapV3Pool wethUSDC;
    UniswapV3Pool usdcDAI;
    UniswapV3Pool wethUNI;
    UniswapV3NFTManager nft;

    bytes extra;

    function setUp() public {
        usdc = new ERC20Mintable("USDC", "USDC", 18);
        weth = new ERC20Mintable("Ether", "WETH", 18);
        dai = new ERC20Mintable("DAI", "DAI", 18);
        uni = new ERC20Mintable("Uniswap Token", "UNI", 18);

        factory = new UniswapV3Factory();
        nft = new UniswapV3NFTManager(address(factory));
        wethUSDC = deployPool(
            factory,
            address(weth),
            address(usdc),
            FEE,
            INIT_PRICE
        );
        usdcDAI = deployPool(
            factory,
            address(usdc),
            address(dai),
            STABLE_FEE,
            STABLE_PRICE
        );
        wethUNI = deployPool(
            factory,
            address(weth),
            address(uni),
            FEE,
            UNI_PRICE
        );

        weth.mint(address(this), USER_WETH_BALANCE);
        usdc.mint(address(this), USER_USDC_BALANCE);
        dai.mint(address(this), USER_DAI_BALANCE);
        uni.mint(address(this), USER_UNI_BALANCE);
        weth.approve(address(nft), type(uint256).max);
        usdc.approve(address(nft), type(uint256).max);
        dai.approve(address(nft), type(uint256).max);
        uni.approve(address(nft), type(uint256).max);

        extra = encodeExtra(address(weth), address(usdc), address(this));
    }

    function testMint() public {
        UniswapV3NFTManager.MintParams memory params = UniswapV3NFTManager
            .MintParams({
                recipient: address(this),
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: FEE,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: 1 ether,
                amount1Desired: 5000 ether,
                amount0Min: 0,
                amount1Min: 0
            });
        uint256 tokenId = nft.mint(params);

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.987078348444137445 ether,
            5000 ether
        );

        assertEq(tokenId, 0, "invalid token id");

        assertMany(
            ExpectedMany({
                pool: wethUSDC,
                tokens: [weth, usdc],
                liquidity: liquidity(params, INIT_PRICE),
                sqrtPriceX96: sqrtP(INIT_PRICE),
                tick: tick(INIT_PRICE),
                fees: [uint256(0), 0],
                userBalances: [
                    USER_WETH_BALANCE - expectedAmount0,
                    USER_USDC_BALANCE - expectedAmount1
                ],
                poolBalances: [expectedAmount0, expectedAmount1],
                position: ExpectedPositionShort({
                    owner: address(nft),
                    ticks: [params.lowerTick, params.upperTick],
                    liquidity: liquidity(params, INIT_PRICE),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintParamsToTicks(params, INIT_PRICE),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );

        assertNFTs(
            ExpectedNFTs({
                nft: nft,
                owner: address(this),
                tokens: nfts(
                    ExpectedNFT({
                        id: tokenId,
                        pool: address(wethUSDC),
                        lowerTick: params.lowerTick,
                        upperTick: params.upperTick
                    })
                )
            })
        );
    }

    function testMintMultiple() public {
        uint256 tokenId0 = nft.mint(
            UniswapV3NFTManager.MintParams({
                recipient: address(this),
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: FEE,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: 1 ether,
                amount1Desired: 5000 ether,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        uint256 tokenId1 = nft.mint(
            UniswapV3NFTManager.MintParams({
                recipient: address(this),
                tokenA: address(usdc),
                tokenB: address(dai),
                fee: STABLE_FEE,
                lowerTick: -520, // 0.95
                upperTick: 490, // 1.05
                amount0Desired: 100_000 ether,
                amount1Desired: 100_000 ether,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertEq(tokenId0, 0, "invalid token id");
        assertEq(tokenId1, 1, "invalid token id");

        assertNFTs(
            ExpectedNFTs({
                nft: nft,
                owner: address(this),
                tokens: nfts(
                    ExpectedNFT({
                        id: tokenId0,
                        pool: address(wethUSDC),
                        lowerTick: tick60(4545),
                        upperTick: tick60(5500)
                    }),
                    ExpectedNFT({
                        id: tokenId1,
                        pool: address(usdcDAI),
                        lowerTick: -520,
                        upperTick: 490
                    })
                )
            })
        );
    }

    function testAddLiquidity() public {
        UniswapV3NFTManager.MintParams memory mintParams = UniswapV3NFTManager
            .MintParams({
                recipient: address(this),
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: FEE,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: 1 ether,
                amount1Desired: 5000 ether,
                amount0Min: 0,
                amount1Min: 0
            });
        uint256 tokenId = nft.mint(mintParams);

        UniswapV3NFTManager.AddLiquidityParams
            memory addParams = UniswapV3NFTManager.AddLiquidityParams({
                tokenId: tokenId,
                amount0Desired: 0.5 ether,
                amount1Desired: 2500 ether,
                amount0Min: 0.4 ether,
                amount1Min: 2000 ether
            });

        (
            uint128 liquidityAdded,
            uint256 amount0Added,
            uint256 amount1Added
        ) = nft.addLiquidity(addParams);

        assertEq(tokenId, 0, "invalid token id");
        assertEq(
            liquidityAdded,
            liquidity(addParams, INIT_PRICE),
            "invalid added liquidity"
        );
        assertEq(
            amount0Added,
            0.493539174222068723 ether,
            "invalid added token0 amount"
        );
        assertEq(
            amount1Added,
            2499.999999999999999998 ether,
            "invalid added token1 amount"
        );

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            1.480617522666206168 ether,
            7499.999999999999999998 ether
        );

        assertMany(
            ExpectedMany({
                pool: wethUSDC,
                tokens: [weth, usdc],
                liquidity: liquidity(mintParams, INIT_PRICE) +
                    liquidity(addParams, INIT_PRICE),
                sqrtPriceX96: sqrtP(INIT_PRICE),
                tick: tick(INIT_PRICE),
                fees: [uint256(0), 0],
                userBalances: [
                    USER_WETH_BALANCE - expectedAmount0,
                    USER_USDC_BALANCE - expectedAmount1
                ],
                poolBalances: [expectedAmount0, expectedAmount1],
                position: ExpectedPositionShort({
                    owner: address(nft),
                    ticks: [mintParams.lowerTick, mintParams.upperTick],
                    liquidity: liquidity(mintParams, INIT_PRICE) +
                        liquidity(addParams, INIT_PRICE),
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintAndAddParamsToTicks(
                    mintParams,
                    addParams,
                    INIT_PRICE
                ),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );

        assertNFTs(
            ExpectedNFTs({
                nft: nft,
                owner: address(this),
                tokens: nfts(
                    ExpectedNFT({
                        id: tokenId,
                        pool: address(wethUSDC),
                        lowerTick: mintParams.lowerTick,
                        upperTick: mintParams.upperTick
                    })
                )
            })
        );
    }

    function testRemoveLiquidity() public {
        UniswapV3NFTManager.MintParams memory mintParams = UniswapV3NFTManager
            .MintParams({
                recipient: address(this),
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: FEE,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: 1 ether,
                amount1Desired: 5000 ether,
                amount0Min: 0,
                amount1Min: 0
            });
        uint256 tokenId = nft.mint(mintParams);

        UniswapV3NFTManager.RemoveLiquidityParams
            memory removeParams = UniswapV3NFTManager.RemoveLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity(mintParams, INIT_PRICE) / 2
            });

        (uint256 amount0Removed, uint256 amount1Removed) = nft.removeLiquidity(
            removeParams
        );

        assertEq(tokenId, 0, "invalid token id");
        assertEq(
            amount0Removed,
            0.493539174222068722 ether,
            "invalid removed token0 amount"
        );
        assertEq(
            amount1Removed,
            2499.999999999999999997 ether,
            "invalid removed token1 amount"
        );

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.987078348444137445 ether,
            5000 ether
        );

        assertMany(
            ExpectedMany({
                pool: wethUSDC,
                tokens: [weth, usdc],
                liquidity: liquidity(mintParams, INIT_PRICE) -
                    removeParams.liquidity,
                sqrtPriceX96: sqrtP(INIT_PRICE),
                tick: tick(INIT_PRICE),
                fees: [uint256(0), 0],
                userBalances: [
                    USER_WETH_BALANCE - expectedAmount0,
                    USER_USDC_BALANCE - expectedAmount1
                ],
                poolBalances: [expectedAmount0, expectedAmount1],
                position: ExpectedPositionShort({
                    owner: address(nft),
                    ticks: [mintParams.lowerTick, mintParams.upperTick],
                    liquidity: liquidity(mintParams, INIT_PRICE) -
                        removeParams.liquidity,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [
                        uint128(amount0Removed),
                        uint128(amount1Removed)
                    ]
                }),
                ticks: mintAndRemoveParamsToTicks(
                    mintParams,
                    removeParams,
                    INIT_PRICE
                ),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );

        assertNFTs(
            ExpectedNFTs({
                nft: nft,
                owner: address(this),
                tokens: nfts(
                    ExpectedNFT({
                        id: tokenId,
                        pool: address(wethUSDC),
                        lowerTick: mintParams.lowerTick,
                        upperTick: mintParams.upperTick
                    })
                )
            })
        );
    }

    function testCollect() public {
        UniswapV3NFTManager.MintParams memory mintParams = UniswapV3NFTManager
            .MintParams({
                recipient: address(this),
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: FEE,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: 1 ether,
                amount1Desired: 5000 ether,
                amount0Min: 0,
                amount1Min: 0
            });
        uint256 tokenId = nft.mint(mintParams);

        UniswapV3NFTManager.RemoveLiquidityParams
            memory removeParams = UniswapV3NFTManager.RemoveLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity(mintParams, INIT_PRICE) / 2
            });

        (uint256 amount0Removed, uint256 amount1Removed) = nft.removeLiquidity(
            removeParams
        );

        (uint128 amount0Collected, uint128 amount1Collected) = nft.collect(
            UniswapV3NFTManager.CollectParams({
                tokenId: tokenId,
                amount0: uint128(amount0Removed),
                amount1: uint128(amount1Removed)
            })
        );

        assertEq(tokenId, 0, "invalid token id");
        assertEq(
            amount0Collected,
            0.493539174222068722 ether,
            "invalid removed token0 amount"
        );
        assertEq(
            amount1Collected,
            2499.999999999999999997 ether,
            "invalid removed token1 amount"
        );

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.987078348444137445 ether,
            5000 ether
        );

        assertMany(
            ExpectedMany({
                pool: wethUSDC,
                tokens: [weth, usdc],
                liquidity: liquidity(mintParams, INIT_PRICE) -
                    removeParams.liquidity,
                sqrtPriceX96: sqrtP(INIT_PRICE),
                tick: tick(INIT_PRICE),
                fees: [uint256(0), 0],
                userBalances: [
                    USER_WETH_BALANCE - expectedAmount0 + amount0Collected,
                    USER_USDC_BALANCE - expectedAmount1 + amount1Collected
                ],
                poolBalances: [
                    expectedAmount0 - amount0Collected,
                    expectedAmount1 - amount1Collected
                ],
                position: ExpectedPositionShort({
                    owner: address(nft),
                    ticks: [mintParams.lowerTick, mintParams.upperTick],
                    liquidity: liquidity(mintParams, INIT_PRICE) -
                        removeParams.liquidity,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintAndRemoveParamsToTicks(
                    mintParams,
                    removeParams,
                    INIT_PRICE
                ),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );

        assertNFTs(
            ExpectedNFTs({
                nft: nft,
                owner: address(this),
                tokens: nfts(
                    ExpectedNFT({
                        id: tokenId,
                        pool: address(wethUSDC),
                        lowerTick: mintParams.lowerTick,
                        upperTick: mintParams.upperTick
                    })
                )
            })
        );
    }

    function testBurn() public {
        UniswapV3NFTManager.MintParams memory mintParams = UniswapV3NFTManager
            .MintParams({
                recipient: address(this),
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: FEE,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: 1 ether,
                amount1Desired: 5000 ether,
                amount0Min: 0,
                amount1Min: 0
            });
        uint256 tokenId = nft.mint(mintParams);

        UniswapV3NFTManager.RemoveLiquidityParams
            memory removeParams = UniswapV3NFTManager.RemoveLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity(mintParams, INIT_PRICE)
            });
        (uint256 amount0Removed, uint256 amount1Removed) = nft.removeLiquidity(
            removeParams
        );

        nft.collect(
            UniswapV3NFTManager.CollectParams({
                tokenId: tokenId,
                amount0: uint128(amount0Removed),
                amount1: uint128(amount1Removed)
            })
        );

        nft.burn(tokenId);

        assertEq(tokenId, 0, "invalid token id");

        assertMany(
            ExpectedMany({
                pool: wethUSDC,
                tokens: [weth, usdc],
                liquidity: 0,
                sqrtPriceX96: sqrtP(INIT_PRICE),
                tick: tick(INIT_PRICE),
                fees: [uint256(0), 0],
                userBalances: [USER_WETH_BALANCE - 1, USER_USDC_BALANCE - 1],
                poolBalances: [uint256(1), 1],
                position: ExpectedPositionShort({
                    owner: address(nft),
                    ticks: [mintParams.lowerTick, mintParams.upperTick],
                    liquidity: 0,
                    feeGrowth: [uint256(0), 0],
                    tokensOwed: [uint128(0), 0]
                }),
                ticks: mintAndRemoveParamsToTicks(
                    mintParams,
                    removeParams,
                    INIT_PRICE
                ),
                observation: ExpectedObservationShort({
                    index: 0,
                    timestamp: 1,
                    tickCumulative: 0,
                    initialized: true
                })
            })
        );

        assertEq(nft.balanceOf(address(this)), 0);
        assertEq(nft.totalSupply(), 0);

        vm.expectRevert("NOT_MINTED");
        nft.ownerOf(tokenId);
    }

    function testTokenURI() public {
        uint256 tokenId0 = nft.mint(
            UniswapV3NFTManager.MintParams({
                recipient: address(this),
                tokenA: address(weth),
                tokenB: address(usdc),
                fee: FEE,
                lowerTick: tick60(4545),
                upperTick: tick60(5500),
                amount0Desired: 1 ether,
                amount1Desired: 5000 ether,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        uint256 tokenId1 = nft.mint(
            UniswapV3NFTManager.MintParams({
                recipient: address(this),
                tokenA: address(usdc),
                tokenB: address(dai),
                fee: STABLE_FEE,
                lowerTick: -520, // 0.95
                upperTick: 490, // 1.05
                amount0Desired: 100_000 ether,
                amount1Desired: 100_000 ether,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        uint256 tokenId2 = nft.mint(
            UniswapV3NFTManager.MintParams({
                recipient: address(this),
                tokenA: address(weth),
                tokenB: address(uni),
                fee: FEE,
                lowerTick: tick60(7),
                upperTick: tick60(13),
                amount0Desired: 1_000 ether,
                amount1Desired: 10_000 ether,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        assertTokenURI(
            nft.tokenURI(tokenId0),
            "tokenuri0",
            "invalid token URI"
        );
        assertTokenURI(
            nft.tokenURI(tokenId1),
            "tokenuri1",
            "invalid token URI"
        );
        assertTokenURI(
            nft.tokenURI(tokenId2),
            "tokenuri2",
            "invalid token URI"
        );
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function mintParamsToTicks(
        UniswapV3NFTManager.MintParams memory mint,
        uint256 currentPrice
    ) internal pure returns (ExpectedTickShort[2] memory ticks) {
        uint128 liq = liquidity(mint, currentPrice);

        ticks[0] = ExpectedTickShort({
            tick: mint.lowerTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: int128(liq)
        });
        ticks[1] = ExpectedTickShort({
            tick: mint.upperTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: -int128(liq)
        });
    }

    function mintAndAddParamsToTicks(
        UniswapV3NFTManager.MintParams memory mint,
        UniswapV3NFTManager.AddLiquidityParams memory add,
        uint256 currentPrice
    ) internal view returns (ExpectedTickShort[2] memory ticks) {
        uint128 liqMint = liquidity(mint, currentPrice);
        uint128 liqAdd = liquidity(add, currentPrice);
        uint128 liq = liqMint + liqAdd;

        ticks[0] = ExpectedTickShort({
            tick: mint.lowerTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: int128(liq)
        });
        ticks[1] = ExpectedTickShort({
            tick: mint.upperTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: -int128(liq)
        });
    }

    function mintAndRemoveParamsToTicks(
        UniswapV3NFTManager.MintParams memory mint,
        UniswapV3NFTManager.RemoveLiquidityParams memory remove,
        uint256 currentPrice
    ) internal pure returns (ExpectedTickShort[2] memory ticks) {
        uint128 liqMint = liquidity(mint, currentPrice);
        uint128 liq = liqMint - remove.liquidity;

        ticks[0] = ExpectedTickShort({
            tick: mint.lowerTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: int128(liq)
        });
        ticks[1] = ExpectedTickShort({
            tick: mint.upperTick,
            initialized: true,
            liquidityGross: liq,
            liquidityNet: -int128(liq)
        });
    }

    function liquidity(
        UniswapV3NFTManager.MintParams memory params,
        uint256 currentPrice
    ) internal pure returns (uint128 liquidity_) {
        liquidity_ = LiquidityMath.getLiquidityForAmounts(
            sqrtP(currentPrice),
            sqrtP60FromTick(params.lowerTick),
            sqrtP60FromTick(params.upperTick),
            params.amount0Desired,
            params.amount1Desired
        );
    }

    function liquidity(
        UniswapV3NFTManager.AddLiquidityParams memory params,
        uint256 currentPrice
    ) internal view returns (uint128 liquidity_) {
        (, int24 lowerTick, int24 upperTick) = nft.positions(params.tokenId);

        liquidity_ = LiquidityMath.getLiquidityForAmounts(
            sqrtP(currentPrice),
            sqrtP60FromTick(lowerTick),
            sqrtP60FromTick(upperTick),
            params.amount0Desired,
            params.amount1Desired
        );
    }

    function nfts(ExpectedNFT memory nft_)
        internal
        pure
        returns (ExpectedNFT[] memory nfts_)
    {
        nfts_ = new ExpectedNFT[](1);
        nfts_[0] = nft_;
    }

    function nfts(ExpectedNFT memory nft0, ExpectedNFT memory nft1)
        internal
        pure
        returns (ExpectedNFT[] memory nfts_)
    {
        nfts_ = new ExpectedNFT[](2);
        nfts_[0] = nft0;
        nfts_[1] = nft1;
    }
}
