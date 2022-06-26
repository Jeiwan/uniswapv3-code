import './SwapForm.css';
import { ethers } from 'ethers';
import { useContext, useEffect, useState } from 'react';
import { MetaMaskContext } from '../contexts/MetaMask';

const tokens = ["WETH", "USDC"];

const TokensList = (props) => {
  return (
    <select defaultValue={props.selected}>
      {tokens.map((t) => <option key={t}>{t}</option>)}
    </select>
  )
}

const addLiquidity = (account, { token0, token1, manager }, config) => {
  if (!token0 || !token1) {
    return;
  }

  const amount0 = ethers.BigNumber.from("1000000000000000000"); // 1 WETH
  const amount1 = ethers.BigNumber.from("5000000000000000000000"); // 5000 USDC
  const lowerTick = 84222;
  const upperTick = 86129;
  const liquidity = ethers.BigNumber.from("1517882343751509868544");

  Promise.all(
    [
      token0.allowance(account, config.managerAddress),
      token1.allowance(account, config.managerAddress)
    ]
  ).then(([allowance0, allowance1]) => {
    return Promise.resolve()
      .then(() => {
        if (allowance0.lt(amount0)) {
          return token0.approve(config.managerAddress, amount0).then(tx => tx.wait())
        }
      })
      .then(() => {
        if (allowance1.lt(amount1)) {
          return token1.approve(config.managerAddress, amount1).then(tx => tx.wait())
        }
      })
      .then(() => {
        return manager.mint(config.poolAddress, lowerTick, upperTick, liquidity)
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

const SwapForm = (props) => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === 'connected';

  const amount0 = 42;
  const amount1 = 0.008396714242162444;

  const [token0, setToken0] = useState();
  const [token1, setToken1] = useState();
  const [manager, setManager] = useState();

  useEffect(() => {
    setToken0(new ethers.Contract(
      props.config.token0Address,
      props.config.ABIs.ERC20,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
    setToken1(new ethers.Contract(
      props.config.token1Address,
      props.config.ABIs.ERC20,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
    setManager(new ethers.Contract(
      props.config.managerAddress,
      props.config.ABIs.Manager,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
  }, []);

  const addLiquidity_ = () => {
    addLiquidity(metamaskContext.account, { token0, token1, manager }, props.config);
  }

  return (
    <section className="SwapContainer">
      <header>
        <h1>Swap tokens</h1>
        <button onClick={addLiquidity_}>Add liquidity</button>
      </header>
      <form className="SwapForm">
        <fieldset>
          <input type="text" placeholder="0.0" value={amount0} readOnly />
          <TokensList selected="USDC" />
        </fieldset>
        <fieldset>
          <input type="text" placeholder="0.0" value={amount1} readOnly />
          <TokensList selected="WETH" />
        </fieldset>
        <button disabled={!enabled}>Swap</button>
      </form>
    </section>
  )
}

export default SwapForm;