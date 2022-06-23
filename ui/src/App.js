import './App.css';
import SwapForm from './components/SwapForm.js';
import MetaMask from './components/MetaMask.js';

function App() {
  return (
    <div className="App flex flex-col justify-between items-center w-full h-full">
      <MetaMask/>
      <SwapForm/>
      <footer></footer>
    </div>
  );
}

export default App;
