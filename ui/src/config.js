const config = {
  factoryAddress: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
  managerAddress: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
  quoterAddress: '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707',
  ABIs: {
    'ERC20': require('./abi/ERC20.json'),
    'Factory': require('./abi/Factory.json'),
    'Manager': require('./abi/Manager.json'),
    'Pool': require('./abi/Pool.json'),
    'Quoter': require('./abi/Quoter.json')
  }
};

config.tokens = {};
config.tokens['0x5FbDB2315678afecb367f032d93F642f64180aa3'] = { symbol: 'WETH' };
config.tokens['0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'] = { symbol: 'USDC' };
config.tokens['0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'] = { symbol: 'UNI' };

export default config;