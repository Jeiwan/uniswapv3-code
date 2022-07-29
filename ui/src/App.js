import './App.css';
import { useState } from 'react';
import SwapForm from './components/SwapForm.js';
import MetaMask from './components/MetaMask.js';
import EventsFeed from './components/EventsFeed.js';
import { MetaMaskProvider } from './contexts/MetaMask';

const App = () => {
  const [pair, setPair] = useState();

  return (
    <MetaMaskProvider>
      <div className="App flex flex-col justify-between items-center w-full h-full">
        <MetaMask />
        <SwapForm pair={pair} setPair={setPair} />
        <footer>
          <EventsFeed pair={pair} />
        </footer>
      </div>
    </MetaMaskProvider>
  );
}

export default App;
