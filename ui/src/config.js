const config = {
  token0Address: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
  token1Address: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
  factoryAddress: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
  poolAddress: '0x150E964b8F01c9BD6746AF2d9467A5aCFd1A8633',
  managerAddress: '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707',
  quoterAddress: '0x0165878A594ca255338adfa4d48449f69242Eb8F',
  ABIs: {
    'ERC20': require('./abi/ERC20.json'),
    'Factory': require('./abi/Factory.json'),
    'Manager': require('./abi/Manager.json'),
    'Pool': require('./abi/Pool.json'),
    'Quoter': require('./abi/Quoter.json')
  }
};

config.tokens = {};
config.tokens[config.token0Address] = { symbol: 'WETH' };
config.tokens[config.token1Address] = { symbol: 'USDC' };

export default config;