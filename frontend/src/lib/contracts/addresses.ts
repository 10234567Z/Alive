// ── ALIVE Protocol — Contract Addresses & Chain Config ──

import { defineChain } from "viem";

// ── Westend Asset Hub Fork (Anvil forking Westend, localhost) ──
// We fork Westend Asset Hub so the real XCM precompile (0x0...0A0000)
// is available. Anvil preserves the chain ID from the fork.
export const westendFork = defineChain({
  id: 420420421, // Westend Asset Hub EVM chain ID (preserved by Anvil fork)
  name: "Westend Asset Hub (Fork)",
  nativeCurrency: { name: "Westend", symbol: "WND", decimals: 18 },
  rpcUrls: {
    default: { http: ["http://localhost:8545"] },
  },
  testnet: true,
});

// ── Westend Asset Hub EVM (production — direct deploy) ──
export const westendAssetHub = defineChain({
  id: 420420421,
  name: "Westend Asset Hub",
  nativeCurrency: { name: "Westend", symbol: "WND", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://westend-asset-hub-eth-rpc.polkadot.io"] },
  },
  testnet: true,
});

// ── Deployed addresses (updated after forge script deploy) ──
export const CONTRACTS = {
  stablecoin: "0xfbC22278A96299D91d41C453234d97b4F5Eb9B2d" as `0x${string}`,
  xcm: "0xC9a43158891282A2B1475592D5719c001986Aaec" as `0x${string}`,
  evolutionEngine: "0x367761085BF3C12e5DA2Df99AC6E1a824612b8fb" as `0x${string}`,
  factory: "0x4C2F7092C2aE51D986bEFEe378e50BD4dB99C901" as `0x${string}`,
  ecosystem: "0x7A9Ec1d04904907De0ED7b6839CcdD59c3716AC9" as `0x${string}`,
  genePool: "0x49fd2BE640DB2910c2fAb69bB8531Ab6E76127ff" as `0x${string}`,
} as const;

// ── Active chain — fork of Westend Asset Hub via Anvil ──
export const ACTIVE_CHAIN = westendFork;
