import { ethers } from 'ethers';
import { poolCodeHash } from './constants';

const sortTokens = (tokenA, tokenB) => {
  return tokenA.toLowerCase() < tokenB.toLowerCase ? [tokenA, tokenB] : [tokenB, tokenA];
}

const computePoolAddress = (factory, tokenA, tokenB, fee) => {
  [tokenA, tokenB] = sortTokens(tokenA, tokenB);

  return ethers.utils.getCreate2Address(
    factory,
    ethers.utils.keccak256(
      ethers.utils.solidityPack(
        ['address', 'address', 'uint24'],
        [tokenA, tokenB, fee]
      )),
    poolCodeHash
  );
}

export default computePoolAddress;