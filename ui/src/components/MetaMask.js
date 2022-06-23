import { useState } from 'react';
import './MetaMask.css';

function shortAddress(address) {
  return address.slice(0, 6) + "..." + address.slice(-4);
}

function connect(setStatus, setAccount, setChain) {
  if (typeof (window.ethereum) === 'undefined') {
    return setStatus('not_installed');
  }

  Promise.all([
    window.ethereum.request({ method: 'eth_requestAccounts' }),
    window.ethereum.request({ method: 'eth_chainId' }),
  ]).then(function ([accounts, chainId]) {
    setAccount(accounts[0]);
    setChain(chainId);
    setStatus('connected');
  })
    .catch(function (error) {
      console.error(error)
    });
}

function renderChain(chainId) {
  if (!chainId) {
    return <span>unknown</span>
  }

  return (
    <span>chain {chainId}</span>
  )
}

function statusConnected(account, chain) {
  return (
    <span>Connected to {renderChain(chain)} as {shortAddress(account)}</span>
  );
}

function statusNotConnected(setStatus, setAccount, setChain) {
  return (
    <span>
      MetaMask is not connected. <button onClick={connect(setStatus, setAccount, setChain)}>Connect</button>
    </span>
  )
}

function renderStatus(status, account, chain, setStatus, setAccount, setChain) {
  switch (status) {
    case 'connected':
      return statusConnected(account, chain)

    case 'not_connected':
      return statusNotConnected(setStatus, setAccount, setChain)

    case 'not_installed':
      return <span>MetaMask is not installed.</span>
  }
}

function MetaMask() {
  const [status, setStatus] = useState('not_connected');
  const [account, setAccount] = useState(null);
  const [chain, setChain] = useState(null);

  return (
    <section className="MetaMaskContainer">
      {renderStatus(status, account, chain, setStatus, setAccount, setChain)}
    </section>
  );
}

export default MetaMask;