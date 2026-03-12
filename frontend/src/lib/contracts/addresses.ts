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
  stablecoin: "0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397" as `0x${string}`,
  xcm: "0xc96304e3c037f81dA488ed9dEa1D8F2a48278a75" as `0x${string}`,
  evolutionEngine: "0x34B40BA116d5Dec75548a9e9A8f15411461E8c70" as `0x${string}`,
  factory: "0xD0141E899a65C95a556fE2B27e5982A6DE7fDD7A" as `0x${string}`,
  ecosystem: "0x07882Ae1ecB7429a84f1D53048d35c4bB2056877" as `0x${string}`,
  genePool: "0x22753E4264FDDc6181dc7cce468904A80a363E44" as `0x${string}`,
} as const;

// ── Active chain (switch between dev and testnet) ──
export const ACTIVE_CHAIN = anvilLocal;
