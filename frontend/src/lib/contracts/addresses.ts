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

// ── Deployed addresses (Polkadot Hub TestNet — 2026-03-19 v4) ──
export const CONTRACTS = {
  stablecoin: "0x8f7E2D2Fbd0a00A54396143f1BF3dB9e604C5f8C" as `0x${string}`,
  xcm: "0xA36B5Fec0E93d24908fAA9966535567E9f888994" as `0x${string}`,
  evolutionEngine: "0x91cc800FfeCd3126cF20e1e15904235d0175b950" as `0x${string}`,
  factory: "0xB7757653FDe43C6c337743647a31bf14Bab7cF83" as `0x${string}`,
  ecosystem: "0xdf422894281A27Aa3d19B0B7D578c59Cb051ABF8" as `0x${string}`,
  genePool: "0x799a5Fd57d09B617e554DaC16A7262EbE3EfF8c3" as `0x${string}`,
} as const;

// ── Active chain — Polkadot Hub TestNet (production) ──
export const ACTIVE_CHAIN = polkadotHubTestnet;
