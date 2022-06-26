import './App.css';
import SwapForm from './components/SwapForm.js';
import MetaMask from './components/MetaMask.js';
import EventsFeed from './components/EventsFeed.js';
import { MetaMaskProvider } from './contexts/MetaMask';

const contracts = {
  poolAddress: '0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0'
};

const App = () => {
  return (
    <div className="App flex flex-col justify-between items-center w-full h-full">
      <MetaMaskProvider>
        <MetaMask />
        <SwapForm />
        <footer>
          <EventsFeed />
        </footer>
      </MetaMaskProvider>
    </div>
  );
}

export default App;
