import './LiquidityForm.css';
import { ethers } from 'ethers';
import { useContext, useEffect, useState } from 'react';
import { feeToSpacing } from '../lib/constants';
import { MetaMaskContext } from '../contexts/MetaMask';
import { TickMath, encodeSqrtRatioX96, nearestUsableTick } from '@uniswap/v3-sdk';
import debounce from '../lib/debounce';
import config from "../config.js";

const priceToSqrtP = (price) => encodeSqrtRatioX96(price, 1);
const priceToTick = (price) => TickMath.getTickAtSqrtRatio(priceToSqrtP(price));

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

const RemoveLiquidityForm = ({ toggle, token0Info, token1Info, fee }) => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === 'connected';
  const account = metamaskContext.account;
  const poolInterface = new ethers.utils.Interface(config.ABIs.Pool);

  const [token0, setToken0] = useState();
  const [token1, setToken1] = useState();
  const [manager, setManager] = useState();
  const [lowerPrice, setLowerPrice] = useState("0");
  const [upperPrice, setUpperPrice] = useState("0");
  const [availableAmount, setAvailableAmount] = useState("0");
  const [amount, setAmount] = useState("0");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setToken0(new ethers.Contract(
      token0Info.address,
      config.ABIs.ERC20,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
    setToken1(new ethers.Contract(
      token1Info.address,
      config.ABIs.ERC20,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
    setManager(new ethers.Contract(
      config.managerAddress,
      config.ABIs.Manager,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
  }, [token0Info, token1Info]);

  const removeLiquidity = (e) => {
    e.preventDefault();

  }

  /**
   * Fetches available liquidity from a position.
   */
  const getAvailableLiquidity = debounce((amount, isLower) => {
    const lowerTick = priceToTick(isLower ? amount : lowerPrice);
    const upperTick = priceToTick(isLower ? upperPrice : amount);

    const params = {
      tokenA: token0.address,
      tokenB: token1.address,
      fee: fee,
      owner: account,
      lowerTick: nearestUsableTick(lowerTick, feeToSpacing[fee]),
      upperTick: nearestUsableTick(upperTick, feeToSpacing[fee]),
    }

    console.log(params);

    manager.getPosition(params)
      .then(position => setAvailableAmount(position.liquidity.toString()))
      .catch(err => console.error(err));
  }, 500);

  const setPriceFn = (setPriceFn, isLower) => {
    return (amount) => {
      setPriceFn(amount);
      getAvailableLiquidity(amount, isLower);
    }
  };

  return (
    <section className="LiquidityWrapper">
      <form className="LiquidityForm">
        <BackButton
          onClick={toggle} />
        <PriceRange
          disabled={!enabled || loading}
          lowerPrice={lowerPrice}
          upperPrice={upperPrice}
          setLowerPrice={setPriceFn(setLowerPrice, true)}
          setUpperPrice={setPriceFn(setUpperPrice, false)} />
        <fieldset>
          <label>Available liquidity</label>
          <label>{availableAmount}</label>
        </fieldset>
        <fieldset>
          <label>Amount to remove</label>
          <input type="number"
            value={amount}
            onChange={ev => setAmount(ev.target.value)}
          />
        </fieldset>
        <button className="removeLiquidity" disabled={!enabled || loading} onClick={removeLiquidity}>Remove liquidity</button>
      </form>
    </section>
  );
}

export default RemoveLiquidityForm;