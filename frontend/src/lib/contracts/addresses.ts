// ── ALIVE Protocol — Contract Addresses & Chain Config ──

import { defineChain } from "viem";

// ── Polkadot Hub TestNet (Paseo) ──
export const polkadotHubTestnet = defineChain({
  id: 420420417,
  name: "Polkadot Hub TestNet",
  nativeCurrency: { name: "Paseo", symbol: "PAS", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://eth-rpc-testnet.polkadot.io"] },
  },
  blockExplorers: {
    default: { name: "Blockscout", url: "https://blockscout-testnet.polkadot.io" },
  },
  testnet: true,
});

// ── Polkadot Hub TestNet (localhost dev — same chain ID) ──
export const polkadotHubLocal = defineChain({
  id: 420420417,
  name: "Polkadot Hub TestNet (Local)",
  nativeCurrency: { name: "Paseo", symbol: "PAS", decimals: 18 },
  rpcUrls: {
    default: { http: ["http://localhost:8545"] },
  },
  testnet: true,
});

// ── Deployed addresses (Polkadot Hub TestNet — 2026-03-19) ──
export const CONTRACTS = {
  stablecoin: "0x28d9FC8645f0F09c1ba595E46BAf7f49FF4A1EB4" as `0x${string}`,
  xcm: "0xa5100dFD6C966aC60a8E497a3545B49B12Dd45BC" as `0x${string}`,
  evolutionEngine: "0x3F6514E6bBFFeE6cEDE3d07850F84cDde3D1F825" as `0x${string}`,
  factory: "0x0B2719dd0710170d9cDe15a55C7D459Af3924D44" as `0x${string}`,
  ecosystem: "0xEeC547709EfFBf50760B8A224B9809d520b5Eb3A" as `0x${string}`,
  genePool: "0xAc0650630410d91299968Ee65fdaac74AA27C1c7" as `0x${string}`,
} as const;

// ── Active chain — Polkadot Hub TestNet (production) ──
export const ACTIVE_CHAIN = polkadotHubTestnet;
