import './SwapForm.css';

const tokens = ["WETH", "USDC"];

const TokensList = (props) => {
  return (
    <select defaultValue={props.selected}>
      {tokens.map((t) => <option key={t}>{t}</option>)}
    </select>
  )
}

const SwapForm = () => {
  return (
    <section className="SwapContainer">
      <header>Swap tokens</header>
      <form className="SwapForm">
        <fieldset>
          <input type="text" placeholder="0.0" />
          <TokensList selected="USDC" />
        </fieldset>
        <fieldset>
          <input type="text" name="to_amount" placeholder="0.0" />
          <TokensList selected="WETH" />
        </fieldset>
        <button>Swap</button>
      </form>
    </section>
  )
}

export default SwapForm;