// ── ALIVE Protocol — Contract Addresses & Chain Config ──

import { defineChain } from "viem";

// ── Local Anvil chain (dev) ──
export const anvilLocal = defineChain({
  id: 31337,
  name: "Anvil Local",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: ["http://localhost:8545"] },
  },
  testnet: true,
});

// ── Westend Asset Hub EVM (production testnet) ──
export const westendAssetHub = defineChain({
  id: 420420421, // Westend Asset Hub EVM chain ID
  name: "Westend Asset Hub",
  nativeCurrency: { name: "Westend", symbol: "WND", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://westend-asset-hub-eth-rpc.polkadot.io"] },
  },
  testnet: true,
});

// ── Deployed addresses (filled from deployments/local.json) ──
// When deploying to testnet, update these with real addresses.
export const CONTRACTS = {
  stablecoin: "0x5FbDB2315678afecb367f032d93F642f64180aa3" as `0x${string}`,
  xcm: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0" as `0x${string}`,
  evolutionEngine: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9" as `0x${string}`,
  factory: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707" as `0x${string}`,
  ecosystem: "0x0165878A594ca255338adfa4d48449f69242Eb8F" as `0x${string}`,
  genePool: "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853" as `0x${string}`,
} as const;

// ── Active chain (switch between dev and testnet) ──
export const ACTIVE_CHAIN = anvilLocal;
