// ── ALIVE Protocol — Wagmi Config ──

import { http, createConfig } from "wagmi";
import { ACTIVE_CHAIN } from "./addresses";

export const wagmiConfig = createConfig({
  chains: [ACTIVE_CHAIN],
  transports: {
    [ACTIVE_CHAIN.id]: http(),
  },
  ssr: true,
});
