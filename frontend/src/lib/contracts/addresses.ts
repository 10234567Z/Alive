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
  stablecoin: "0x115686C5B6256B7b8Aa426d75fC4DEa6354A59De" as `0x${string}`,
  xcm: "0x2948dcd1B5537E3C0a596716b908AE23ab06CDa9" as `0x${string}`,
  evolutionEngine: "0x1f9f7A61d5d8A2CbcAe46ce67ADb5b11D244B24F" as `0x${string}`,
  factory: "0x4182AE5ebCf3703AD3ADB95df08a1FaDF2dFeB62" as `0x${string}`,
  ecosystem: "0x5c381F8Fb58622beD71119dEA591e7aeF5Bc52F0" as `0x${string}`,
  genePool: "0x8525A10eeBF11E689F4a456A2AE172eaC9DaD6C9" as `0x${string}`,
} as const;

// ── Active chain (switch between dev and testnet) ──
export const ACTIVE_CHAIN = anvilLocal;
