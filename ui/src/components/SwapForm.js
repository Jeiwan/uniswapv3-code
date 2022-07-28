import './SwapForm.css';
import { ethers } from 'ethers';
import { useContext, useEffect, useState } from 'react';
import { uint256Max } from '../lib/constants';
import { MetaMaskContext } from '../contexts/MetaMask';
import config from "../config.js";
import debounce from '../lib/debounce';
import LiquidityForm from './LiquidityForm';

const loadPairs = ({ factory }) => {
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
          tickSpacing: event.tickSpacing
        }
      });

      return Promise.resolve(pairs);
    }).catch((err) => {
      console.error(err)
    });
}

const swap = (zeroForOne, amountIn, account, priceAfter, slippage, pair, { tokenIn, manager, token0, token1 }) => {
  const amountInWei = ethers.utils.parseEther(amountIn);
  const limitPrice = priceAfter.mul((100 - parseFloat(slippage)) * 100).div(10000);
  const extra = ethers.utils.defaultAbiCoder.encode(
    ["address", "address", "address"],
    [token0.address, token1.address, account]
  );
  const params = {
    tokenA: pair.token0.address,
    tokenB: pair.token1.address,
    tickSpacing: 1,
    zeroForOne: zeroForOne,
    amountSpecified: amountInWei,
    sqrtPriceLimitX96: limitPrice,
    data: extra
  };

  tokenIn.allowance(account, config.managerAddress)
    .then((allowance) => {
      if (allowance.lt(amountInWei)) {
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

const SwapInput = ({ token, amount, setAmount, disabled, readOnly }) => {
  return (
    <fieldset className="SwapInput" disabled={disabled}>
      <input type="text" id={token + "_amount"} placeholder="0.0" value={amount} onChange={(ev) => setAmount(ev.target.value)} readOnly={readOnly} />
      <label htmlFor={token + "_amount"}>{token}</label>
    </fieldset>
  );
}

const ChangeDirectionButton = ({ zeroForOne, setZeroForOne, disabled }) => {
  return (
    <button className='ChangeDirectionBtn' onClick={(ev) => { ev.preventDefault(); setZeroForOne(!zeroForOne) }} disabled={disabled}>🔄</button>
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

const SwapForm = (props) => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === 'connected';

  const [zeroForOne, setZeroForOne] = useState(true);
  const [amount0, setAmount0] = useState(0);
  const [amount1, setAmount1] = useState(0);
  const [token0, setToken0] = useState();
  const [token1, setToken1] = useState();
  const [manager, setManager] = useState();
  const [quoter, setQuoter] = useState();
  const [factory, setFactory] = useState();
  const [loading, setLoading] = useState(false);
  const [managingLiquidity, setManagingLiquidity] = useState(false);
  const [slippage, setSlippage] = useState(0.1);
  const [priceAfter, setPriceAfter] = useState();
  const [pairs, setPairs] = useState();
  const [pair, setPair] = useState();

  useEffect(() => {
    setToken0(new ethers.Contract(
      config.token0Address,
      config.ABIs.ERC20,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
    setToken1(new ethers.Contract(
      config.token1Address,
      config.ABIs.ERC20,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
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

    const factory = new ethers.Contract(
      config.factoryAddress,
      config.ABIs.Factory,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    );

    setFactory(factory);
    loadPairs({ factory }).then((pairs) => {
      setPairs(pairs);
      setPair(pairs[0]);
    });
  }, []);

  const swap_ = (e) => {
    e.preventDefault();
    swap(zeroForOne, zeroForOne ? amount0 : amount1, metamaskContext.account, priceAfter, slippage, pair, { tokenIn: token1, manager, token0, token1 });
  }

  const updateAmountOut = debounce((amount) => {
    if (amount === 0 || amount === "0") {
      return;
    }

    setLoading(true);

    const params = {
      tokenA: pair.token0.address,
      tokenB: pair.token1.address,
      tickSpacing: 1,
      amountIn: ethers.utils.parseEther(amount),
      sqrtPriceLimitX96: 0,
      zeroForOne: zeroForOne
    };

    quoter.callStatic
      .quote(params)
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

  const setAmount_ = (setAmountFn) => {
    return (amount) => {
      amount = amount || 0;
      setAmountFn(amount);
      updateAmountOut(amount)
    }
  }

  const toggleLiquidityForm = () => {
    setManagingLiquidity(!managingLiquidity);
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
            readOnly={false}
            setAmount={setAmount_(zeroForOne ? setAmount0 : setAmount1)}
            token={zeroForOne ? pair.token0.symbol : pair.token1.symbol} />
          <ChangeDirectionButton zeroForOne={zeroForOne} setZeroForOne={setZeroForOne} disabled={!enabled || loading} />
          <SwapInput
            amount={zeroForOne ? amount1 : amount0}
            disabled={!enabled || loading}
            readOnly={true}
            token={zeroForOne ? pair.token1.symbol : pair.token0.symbol} />
          <SlippageControl
            setSlippage={setSlippage}
            slippage={slippage} />
          <button className='swap' disabled={!enabled || loading} onClick={swap_}>Swap</button>
        </form>
        :
        <span>Loading pairs...</span>}
    </section>
  )
}

export default SwapForm;