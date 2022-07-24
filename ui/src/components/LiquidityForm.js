import './LiquidityForm.css';
import { ethers } from 'ethers';
import { useContext, useEffect, useState } from 'react';
import { uint256Max } from '../lib/constants';
import { MetaMaskContext } from '../contexts/MetaMask';
import { sqrt } from '@uniswap/sdk-core';
import { TickMath } from '@uniswap/v3-sdk';
import config from "../config.js";
import JSBI from 'jsbi';

const priceToTick = (price) => {
  const sqrtP = sqrt(
    JSBI.leftShift(JSBI.BigInt(price), JSBI.BigInt(192))
  );
  return TickMath.getTickAtSqrtRatio(sqrtP);
}

const addLiquidity = (account, lowerPrice, upperPrice, amount0, amount1, { token0, token1, manager }) => {
  if (!token0 || !token1) {
    return;
  }

  const amount0Big = ethers.utils.parseEther(amount0);
  const amount1Big = ethers.utils.parseEther(amount1);
  const lowerTick = priceToTick(lowerPrice);
  const upperTick = priceToTick(upperPrice);
  const liquidity = ethers.BigNumber.from("1517882343751509868544");
  const extra = ethers.utils.defaultAbiCoder.encode(
    ["address", "address", "address"],
    [token0.address, token1.address, account]
  );

  Promise.all(
    [
      token0.allowance(account, config.managerAddress),
      token1.allowance(account, config.managerAddress)
    ]
  ).then(([allowance0, allowance1]) => {
    return Promise.resolve()
      .then(() => {
        if (allowance0.lt(amount0Big)) {
          return token0.approve(config.managerAddress, uint256Max).then(tx => tx.wait())
        }
      })
      .then(() => {
        if (allowance1.lt(amount1Big)) {
          return token1.approve(config.managerAddress, uint256Max).then(tx => tx.wait())
        }
      })
      .then(() => {
        return manager.mint(config.poolAddress, lowerTick, upperTick, liquidity, extra)
          .then(tx => tx.wait())
      })
      .then(() => {
        alert('Liquidity added!');
      });
  }).catch((err) => {
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

  const [amount0, setAmount0] = useState(0);
  const [amount1, setAmount1] = useState(0);
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
    addLiquidity(metamaskContext.account, lowerPrice, upperPrice, amount0, amount1, { token0, token1, manager });
  }

  return (
    <section className="LiquidityWrapper">
      <form className="LiquidityForm">
        <BackButton
          onClick={toggle} />
        <PriceRange
          disabled={!enabled}
          lowerPrice={lowerPrice}
          upperPrice={upperPrice}
          setLowerPrice={setLowerPrice}
          setUpperPrice={setUpperPrice} />
        <AmountInput
          amount={amount0}
          disabled={!enabled}
          setAmount={setAmount0}
          token={pair.token0} />
        <AmountInput
          amount={amount1}
          disabled={!enabled}
          setAmount={setAmount1}
          token={pair.token1} />
        <button className="addLiquidity" disabled={!enabled} onClick={addLiquidity_}>Add liquidity</button>
      </form>
    </section>
  );
};

export default LiquidityForm;