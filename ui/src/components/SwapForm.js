import './SwapForm.css';
import { useContext } from 'react';
import { MetaMaskContext } from '../contexts/MetaMask';

const tokens = ["WETH", "USDC"];

const TokensList = (props) => {
  return (
    <select defaultValue={props.selected}>
      {tokens.map((t) => <option key={t}>{t}</option>)}
    </select>
  )
}

const SwapForm = () => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === 'connected';

  const amount0 = 42;
  const amount1 = 0.008396714242162444;

  return (
    <section className="SwapContainer">
      <header>Swap tokens</header>
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