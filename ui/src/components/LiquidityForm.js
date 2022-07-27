import './LiquidityForm.css';
import { ethers } from 'ethers';
import { useContext, useEffect, useState } from 'react';
import { uint256Max } from '../lib/constants';
import { MetaMaskContext } from '../contexts/MetaMask';
import { sqrt } from '@uniswap/sdk-core';
import { TickMath } from '@uniswap/v3-sdk';
import config from "../config.js";
import JSBI from 'jsbi';

const slippage = 0.1;

const formatAmount = ethers.utils.formatUnits

const priceToSqrtP = (price) => {
  return sqrt(
    JSBI.leftShift(JSBI.BigInt(price), JSBI.BigInt(192))
  );
}

const priceToTick = (price) => {
  return TickMath.getTickAtSqrtRatio(priceToSqrtP(price));
}

const addLiquidity = (account, lowerPrice, upperPrice, amount0, amount1, { token0, token1, manager }) => {
  if (!token0 || !token1) {
    return;
  }

  const amount0Desired = ethers.utils.parseEther(amount0);
  const amount1Desired = ethers.utils.parseEther(amount1);
  const amount0Min = amount0Desired.mul((100 - slippage) * 100).div(10000);
  const amount1Min = amount1Desired.mul((100 - slippage) * 100).div(10000);

  const lowerTick = priceToTick(lowerPrice);
  const upperTick = priceToTick(upperPrice);

  const mintParams = {
    poolAddress: config.poolAddress,
    lowerTick, upperTick, amount0Desired, amount1Desired, amount0Min, amount1Min
  }

  return Promise.all(
    [
      token0.allowance(account, config.managerAddress),
      token1.allowance(account, config.managerAddress)
    ]
  ).then(([allowance0, allowance1]) => {
    return Promise.resolve()
      .then(() => {
        if (allowance0.lt(amount0Desired)) {
          return token0.approve(config.managerAddress, uint256Max).then(tx => tx.wait())
        }
      })
      .then(() => {
        if (allowance1.lt(amount1Desired)) {
          return token1.approve(config.managerAddress, uint256Max).then(tx => tx.wait())
        }
      })
      .then(() => {
        return manager.mint(mintParams)
          .then(tx => tx.wait())
      })
      .then(() => {
        alert('Liquidity added!');
      });
  }).catch((err) => {
    if (err.error && err.error.data && err.error.data.data) {
      const error = manager.interface.parseError(err.error.data.data);
      switch (error.name) {
        case "SlippageCheckFailed":
          alert(`Slippage check failed (amount0: ${formatAmount(error.args.amount0)}, amount1: ${formatAmount(error.args.amount1)})`)
          return;

        default:
          console.error(err);
          alert('Failed!');

          return;
      }
    }

    console.error(err);
    alert('Failed!');
  });
}

const BackButton = ({ onClick }) => {
  return (
    <button className="BackButton" onClick={onClick}>← Back</button>
  );
}

const PriceRange = ({ lowerPrice, upperPrice, setLowerPrice, setUpperPrice, disabled }) => {
  return (
    <fieldset>
      <label htmlFor="upperPrice">Price range</label>
      <div className="PriceRangeInputs">
        <input
          type="text"
          id="lowerPrice"
          placeholder="0.0"
          readOnly={disabled}
          value={lowerPrice}
          onChange={(ev) => setLowerPrice(ev.target.value)}
        />
        <span>&nbsp;–&nbsp;</span>
        <input
          type="text"
          id="upperPrice"
          placeholder="0.0"
          readOnly={disabled}
          value={upperPrice}
          onChange={(ev) => setUpperPrice(ev.target.value)}
        />
      </div>
    </fieldset>
  );
}

const AmountInput = ({ amount, disabled, setAmount, token }) => {
  return (
    <fieldset>
      <label htmlFor={token + "_liquidity"}>{token} amount</label>
      <input
        id={token + "_liquidity"}
        onChange={(ev) => setAmount(ev.target.value)}
        placeholder="0.0"
        readOnly={disabled}
        type="text"
        value={amount} />
    </fieldset>
  );
}

const LiquidityForm = ({ pair, toggle }) => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === 'connected';

  const [token0, setToken0] = useState();
  const [token1, setToken1] = useState();
  const [manager, setManager] = useState();

  const [amount0, setAmount0] = useState("0");
  const [amount1, setAmount1] = useState("0");
  const [lowerPrice, setLowerPrice] = useState(0);
  const [upperPrice, setUpperPrice] = useState(0);
  const [loading, setLoading] = useState(false);

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
  }, []);

  const addLiquidity_ = (e) => {
    e.preventDefault();
    setLoading(true);
    addLiquidity(metamaskContext.account, lowerPrice, upperPrice, amount0, amount1, { token0, token1, manager })
      .then(() => setLoading(false));
  }

  return (
    <section className="LiquidityWrapper">
      <form className="LiquidityForm">
        <BackButton
          onClick={toggle} />
        <PriceRange
          disabled={!enabled || loading}
          lowerPrice={lowerPrice}
          upperPrice={upperPrice}
          setLowerPrice={setLowerPrice}
          setUpperPrice={setUpperPrice} />
        <AmountInput
          amount={amount0}
          disabled={!enabled || loading}
          setAmount={setAmount0}
          token={pair.token0} />
        <AmountInput
          amount={amount1}
          disabled={!enabled || loading}
          setAmount={setAmount1}
          token={pair.token1} />
        <button className="addLiquidity" disabled={!enabled || loading} onClick={addLiquidity_}>Add liquidity</button>
      </form>
    </section>
  );
};

export default LiquidityForm;