import './SwapForm.css';
import { ethers } from 'ethers';
import { useContext, useEffect, useState } from 'react';
import { MetaMaskContext } from '../contexts/MetaMask';
import debounce from '../lib/debounce';

const pairs = [["WETH", "USDC"]];

const addLiquidity = (account, { token0, token1, manager }, { managerAddress, poolAddress }) => {
  if (!token0 || !token1) {
    return;
  }

  const amount0 = ethers.utils.parseEther("0.998976618347425280");
  const amount1 = ethers.utils.parseEther("5000"); // 5000 USDC
  const lowerTick = 84222;
  const upperTick = 86129;
  const liquidity = ethers.BigNumber.from("1517882343751509868544");
  const extra = ethers.utils.defaultAbiCoder.encode(
    ["address", "address", "address"],
    [token0.address, token1.address, account]
  );

  Promise.all(
    [
      token0.allowance(account, managerAddress),
      token1.allowance(account, managerAddress)
    ]
  ).then(([allowance0, allowance1]) => {
    return Promise.resolve()
      .then(() => {
        if (allowance0.lt(amount0)) {
          return token0.approve(managerAddress, amount0).then(tx => tx.wait())
        }
      })
      .then(() => {
        if (allowance1.lt(amount1)) {
          return token1.approve(managerAddress, amount1).then(tx => tx.wait())
        }
      })
      .then(() => {
        return manager.mint(poolAddress, lowerTick, upperTick, liquidity, extra)
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

const swap = (zeroForOne, amountIn, account, { tokenIn, manager, token0, token1 }, { managerAddress, poolAddress }) => {
  const amountInWei = ethers.utils.parseEther(amountIn);
  const extra = ethers.utils.defaultAbiCoder.encode(
    ["address", "address", "address"],
    [token0.address, token1.address, account]
  );

  tokenIn.allowance(account, managerAddress)
    .then((allowance) => {
      if (allowance.lt(amountInWei)) {
        return tokenIn.approve(managerAddress, amountInWei).then(tx => tx.wait())
      }
    })
    .then(() => {
      return manager.swap(poolAddress, zeroForOne, amountInWei, extra).then(tx => tx.wait())
    })
    .then(() => {
      alert('Swap succeeded!');
    }).catch((err) => {
      console.error(err);
      alert('Failed!');
    });
}

const SwapInput = ({ token, amount, setAmount, disabled }) => {
  return (
    <fieldset disabled={disabled}>
      <input type="text" id={token + "_amount"} placeholder="0.0" value={amount} onChange={(ev) => setAmount(ev.target.value)} />
      <label htmlFor={token + "_amount"}>{token}</label>
    </fieldset>
  );
}

const ChangeDirectionButton = ({ zeroForOne, setZeroForOne, disabled }) => {
  return (
    <button className='ChangeDirectionBtn' onClick={(ev) => { ev.preventDefault(); setZeroForOne(!zeroForOne) }} disabled={disabled}>🔄</button>
  )
}

const SwapForm = (props) => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === 'connected';

  const [pair, _] = useState(pairs[0]);
  const [zeroForOne, setZeroForOne] = useState(true);
  const [amount0, setAmount0] = useState(0);
  const [amount1, setAmount1] = useState(0);
  const [token0, setToken0] = useState();
  const [token1, setToken1] = useState();
  const [manager, setManager] = useState();
  const [quoter, setQuoter] = useState();
  const [loading, setLoading] = useState(false);

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
    setQuoter(new ethers.Contract(
      props.config.quoterAddress,
      props.config.ABIs.Quoter,
      new ethers.providers.Web3Provider(window.ethereum).getSigner()
    ));
  }, []);

  const addLiquidity_ = () => {
    addLiquidity(metamaskContext.account, { token0, token1, manager }, props.config);
  }

  const swap_ = (e) => {
    e.preventDefault();
    swap(zeroForOne, zeroForOne ? amount0 : amount1, metamaskContext.account, { tokenIn: token1, manager, token0, token1 }, props.config);
  }

  const updateAmountOut = debounce((amount) => {
    if (amount === 0 || amount === "0") {
      return;
    }

    setLoading(true);

    quoter.callStatic
      .quote({ pool: props.config.poolAddress, amountIn: ethers.utils.parseEther(amount), zeroForOne: zeroForOne })
      .then(({ amountOut }) => {
        zeroForOne ? setAmount1(ethers.utils.formatEther(amountOut)) : setAmount0(ethers.utils.formatEther(amountOut));
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

  return (
    <section className="SwapContainer">
      <header>
        <h1>Swap tokens</h1>
        <button disabled={!enabled || loading} onClick={addLiquidity_}>Add liquidity</button>
      </header>
      <form className="SwapForm">
        <SwapInput token={zeroForOne ? pair[0] : pair[1]} amount={zeroForOne ? amount0 : amount1} setAmount={setAmount_(zeroForOne ? setAmount0 : setAmount1, zeroForOne)} disabled={!enabled || loading} />
        <ChangeDirectionButton zeroForOne={zeroForOne} setZeroForOne={setZeroForOne} disabled={!enabled || loading} />
        <SwapInput token={zeroForOne ? pair[1] : pair[0]} amount={zeroForOne ? amount1 : amount0} setAmount={setAmount_(zeroForOne ? setAmount1 : setAmount0, zeroForOne)} disabled={!enabled || loading} />
        <button className='swap' disabled={!enabled || loading} onClick={swap_}>Swap</button>
      </form>
    </section>
  )
}

export default SwapForm;