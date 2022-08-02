import './SwapForm.css';
import { ethers } from 'ethers';
import { useContext, useEffect, useState } from 'react';
import { uint256Max } from '../lib/constants';
import { MetaMaskContext } from '../contexts/MetaMask';
import config from "../config.js";
import debounce from '../lib/debounce';
import LiquidityForm from './LiquidityForm';

const pairsToTokens = (pairs) => {
  const tokens = pairs.reduce((acc, pair) => {
    acc[pair.token0.address] = {
      symbol: pair.token0.symbol,
      address: pair.token0.address,
      selected: false
    };
    acc[pair.token1.address] = {
      symbol: pair.token1.symbol,
      address: pair.token1.address,
      selected: false
    };

    return acc;
  }, {});

  return Object.keys(tokens).map(k => tokens[k]);
}

const pairsToMap = (pairs) => {
  return pairs.reduce((acc, pair) => {
    if (!acc[pair.token0.address]) {
      acc[pair.token0.address] = {};

    }

    acc[pair.token0.address][pair.token1.address] = pair;

    return acc;
  }, {});
}

const SwapInput = ({ token, tokens, onChange, amount, setAmount, disabled, readOnly }) => {
  return (
    <fieldset className="SwapInput" disabled={disabled}>
      <input type="text" id={token + "_amount"} placeholder="0.0" value={amount} onChange={(ev) => setAmount(ev.target.value)} readOnly={readOnly} />
      <select name="token" value={token} onChange={onChange}>
        {tokens.map(t => <option key={`${token}_${t.symbol}`}>{t.symbol}</option>)}
      </select>
    </fieldset>
  );
}

const ChangeDirectionButton = ({ onClick, disabled }) => {
  return (
    <button className='ChangeDirectionBtn' onClick={onClick} disabled={disabled}>🔄</button>
  )
}

const SlippageControl = ({ setSlippage, slippage }) => {
  return (
    <fieldset className="SlippageControl">
      <label htmlFor="slippage">Slippage tolerance, %</label>
      <input type="text" value={slippage} onChange={(ev) => setSlippage(ev.target.value)} />
    </fieldset>
  );
}

const SwapForm = ({ pair, setPair }) => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === 'connected';
  const account = metamaskContext.account;

  const [zeroForOne, setZeroForOne] = useState(true);
  const [amount0, setAmount0] = useState(0);
  const [amount1, setAmount1] = useState(0);
  const [tokenIn, setTokenIn] = useState();
  const [manager, setManager] = useState();
  const [quoter, setQuoter] = useState();
  const [loading, setLoading] = useState(false);
  const [managingLiquidity, setManagingLiquidity] = useState(false);
  const [slippage, setSlippage] = useState(0.1);
  const [priceAfter, setPriceAfter] = useState();
  const [pairs, setPairs] = useState();
  const [tokens, setTokens] = useState();

  useEffect(() => {
    setManager(new ethers.Contract(
      config.managerAddress,
      config.ABIs.Manager,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
    setQuoter(new ethers.Contract(
      config.quoterAddress,
      config.ABIs.Quoter,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));

    loadPairs().then((pairs) => {
      setPairs(pairsToMap(pairs));
      setPair(pairs[0]);
      setTokens(pairsToTokens(pairs));

      !tokenIn && setTokenIn(new ethers.Contract(
        pairs[0].token0.address,
        config.ABIs.ERC20,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      ));
    });
  }, [setPair, tokenIn]);

  /**
   * Load pairs from a Factory address by scanning for 'PoolCreated' events.
   * 
   * @returns array of 'pair' objects.
   */
  const loadPairs = () => {
    const factory = new ethers.Contract(
      config.factoryAddress,
      config.ABIs.Factory,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    );

    return factory.queryFilter("PoolCreated", "earliest", "latest")
      .then((events) => {
        const pairs = events.map((event) => {
          return {
            token0: {
              address: event.args.token0,
              symbol: config.tokens[event.args.token0].symbol
            },
            token1: {
              address: event.args.token1,
              symbol: config.tokens[event.args.token1].symbol
            },
            tickSpacing: event.args.tickSpacing,
            address: event.args.pool
          }
        });

        return Promise.resolve(pairs);
      }).catch((err) => {
        console.error(err)
      });
  }


  /**
   * Swaps tokens by calling Manager contract. Before swapping, asks users to approve spending of tokens.
   */
  const swap = (e) => {
    e.preventDefault();

    const amountIn = ethers.utils.parseEther(zeroForOne ? amount0 : amount1);
    const amountOut = ethers.utils.parseEther(zeroForOne ? amount1 : amount0);
    const minAmountOut = amountOut.mul((100 - parseFloat(slippage)) * 100).div(10000);
    const path = ethers.utils.solidityPack(
      ["address", "uint24", "address"],
      [tokenIn.address, 60, zeroForOne ? pair.token1.address : pair.token0.address]
    );
    const params = {
      path: path,
      recipient: account,
      amountIn: amountIn,
      minAmountOut: minAmountOut
    };

    tokenIn.allowance(account, config.managerAddress)
      .then((allowance) => {
        if (allowance.lt(amountIn)) {
          return tokenIn.approve(config.managerAddress, uint256Max).then(tx => tx.wait())
        }
      })
      .then(() => {
        return manager.swap(params).then(tx => tx.wait())
      })
      .then(() => {
        alert('Swap succeeded!');
      }).catch((err) => {
        console.error(err);
        alert('Failed!');
      });
  }

  /**
   * Calculates output amount by querying Quoter contract. Sets 'priceAfter' and 'amountOut'.
   */
  const updateAmountOut = debounce((amount) => {
    if (amount === 0 || amount === "0") {
      return;
    }

    setLoading(true);

    const path = ethers.utils.solidityPack(
      ["address", "uint24", "address"],
      [tokenIn.address, 60, zeroForOne ? pair.token1.address : pair.token0.address]
    );
    const amountIn = ethers.utils.parseEther(amount);

    quoter.callStatic
      .quote(path, amountIn)
      .then(({ amountOut, sqrtPriceX96After }) => {
        zeroForOne ? setAmount1(ethers.utils.formatEther(amountOut)) : setAmount0(ethers.utils.formatEther(amountOut));
        setPriceAfter(sqrtPriceX96After);
        setLoading(false);
      })
      .catch((err) => {
        zeroForOne ? setAmount1(0) : setAmount0(0);
        setLoading(false);
        console.error(err);
      })
  })

  /**
   *  Wraps 'setAmount', ensures amount is correct, and calls 'updateAmountOut'.
   */
  const setAmountFn = (setAmountFn) => {
    return (amount) => {
      amount = amount || 0;
      setAmountFn(amount);
      updateAmountOut(amount)
    }
  }

  const toggleLiquidityForm = () => setManagingLiquidity(!managingLiquidity);

  /**
   * Set currently selected pair based on selected tokens.
   * 
   * @param {symbol} selected token symbol
   * @param {index} token index
   */
  const selectToken = (symbol, index) => {
    let token0, token1;

    if (index === 0) {
      token0 = tokens.filter(t => t.symbol === symbol)[0];
      token1 = zeroForOne ? pair.token1 : pair.token0;
    }

    if (index === 1) {
      token0 = zeroForOne ? pair.token0 : pair.token1;
      token1 = tokens.filter(t => t.symbol === symbol)[0];
    }

    [token0, token1] = zeroForOne ? [token0, token1] : [token1, token0];

    if (token0.symbol === token1.symbol) {
      return false;
    }

    try {
      const newPair = pairs[token0.address][token1.address];
      setPair(newPair);
      setAmount0(0);
      setAmount1(0);
    } catch {
      alert(`${token0.symbol}/${token1.symbol} pair doesn't exist!`);
    }
  }

  /**
   * Toggles swap direction.
   */
  const toggleDirection = (e) => {
    e.preventDefault();

    setZeroForOne(!zeroForOne);
    setTokenIn(tokenIn.attach(
      pair.token0.address === tokenIn.address
        ? pair.token1.address
        : pair.token0.address
    ));
  }

  return (
    <section className="SwapContainer">
      {managingLiquidity && <LiquidityForm pair={pair} toggle={toggleLiquidityForm} />}
      <header>
        <h1>Swap tokens</h1>
        <button disabled={!enabled || loading} onClick={toggleLiquidityForm}>Add liquidity</button>
      </header>
      {pair ?
        <form className="SwapForm">
          <SwapInput
            amount={zeroForOne ? amount0 : amount1}
            disabled={!enabled || loading}
            onChange={(ev) => selectToken(ev.target.value, 0)}
            readOnly={false}
            setAmount={setAmountFn(zeroForOne ? setAmount0 : setAmount1)}
            token={zeroForOne ? pair.token0.symbol : pair.token1.symbol}
            tokens={tokens} />
          <ChangeDirectionButton zeroForOne={zeroForOne} onClick={toggleDirection} disabled={!enabled || loading} />
          <SwapInput
            amount={zeroForOne ? amount1 : amount0}
            disabled={!enabled || loading}
            onChange={(ev) => selectToken(ev.target.value, 1)}
            readOnly={true}
            token={zeroForOne ? pair.token1.symbol : pair.token0.symbol}
            tokens={tokens.filter(t => t.address !== tokenIn.address)} />
          <SlippageControl
            setSlippage={setSlippage}
            slippage={slippage} />
          <button className='swap' disabled={!enabled || loading} onClick={swap}>Swap</button>
        </form>
        :
        <span>Loading pairs...</span>}
    </section>
  )
}

export default SwapForm;