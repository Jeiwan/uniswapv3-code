import { ethers } from 'ethers';

const uint256Max = ethers.constants.MaxUint256;

const feeToSpacing = {
  3000: 60,
  500: 10
}

export { uint256Max, feeToSpacing };