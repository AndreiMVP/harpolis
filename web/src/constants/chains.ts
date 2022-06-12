export enum ChainID {
  MAINNET = 1,
  KOVAN = 42,
  ARB_RINKEBY = 421611,
}

export const CHAIN_ID_TO_NAME = {
  [ChainID.ARB_RINKEBY]: "Arbitrum Rinkeby",
  [ChainID.MAINNET]: "mainnet",
  [ChainID.KOVAN]: "kovan",
};

export const SUPPORTED_CHAIN_IDS = [ChainID.ARB_RINKEBY];
