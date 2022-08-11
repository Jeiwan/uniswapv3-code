import { ethers } from 'ethers';

const uint256Max = ethers.constants.MaxUint256;

const feeToSpacing = {
  3000: 60,
  500: 10
}

// forge inspect UniswapV3Pool bytecode| xargs cast keccak
const poolCodeHash = "0x25e8f76b6ab9c18a8cdea3c355e7db914118000b3839068f21083ce884a4d24c";

export { uint256Max, feeToSpacing, poolCodeHash };