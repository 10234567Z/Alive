import { create } from "zustand";
import { Creature, EcosystemState, EpochRecord, Phase } from "@/lib/types";

// ── Default empty state (no mock data) ──

const EMPTY_ECOSYSTEM: EcosystemState = {
  totalDeposits: 0,
  currentEpoch: 0,
  creatureCount: 0,
  yieldGenerated: 0,
  phase: Phase.IDLE,
};

const EMPTY_USER = {
  address: "" as string,
  deposited: 0,
  shares: 0,
  shareValue: 0,
};

interface EcosystemStore {
  // State (hydrated from chain)
  ecosystem: EcosystemState;
  creatures: Creature[];
  epochs: EpochRecord[];
  user: typeof EMPTY_USER;
  selectedCreature: Creature | null;
  isInspectorOpen: boolean;
  isLoading: boolean;

  // Setters (called by hooks after reading chain)
  setEcosystem: (e: EcosystemState) => void;
  setCreatures: (c: Creature[]) => void;
  setUser: (u: Partial<typeof EMPTY_USER>) => void;
  setLoading: (l: boolean) => void;
  addEpochRecord: (e: EpochRecord) => void;

  // UI Actions
  selectCreature: (c: Creature | null) => void;
  openInspector: (c: Creature) => void;
  closeInspector: () => void;

  // Write actions (optimistic updates — actual tx goes through wagmi)
  deposit: (amount: number) => void;
  withdraw: (amount: number) => void;
}

export const useEcosystemStore = create<EcosystemStore>((set) => ({
  ecosystem: EMPTY_ECOSYSTEM,
  creatures: [],
  epochs: [],
  user: EMPTY_USER,
  selectedCreature: null,
  isInspectorOpen: false,
  isLoading: true,

  // ── Chain data setters ──
  setEcosystem: (ecosystem) =>
    set({ ecosystem, isLoading: false }),

  setCreatures: (creatures) =>
    set({ creatures }),

  setUser: (partial) =>
    set((state) => ({ user: { ...state.user, ...partial } })),

  setLoading: (isLoading) => set({ isLoading }),

  addEpochRecord: (record) =>
    set((state) => {
      if (state.epochs.some((e) => e.epoch === record.epoch)) return state;
      return { epochs: [...state.epochs, record].sort((a, b) => a.epoch - b.epoch) };
    }),

  // ── UI Actions ──
  selectCreature: (c) => set({ selectedCreature: c }),

  openInspector: (c) =>
    set({ selectedCreature: c, isInspectorOpen: true }),

  closeInspector: () =>
    set({ selectedCreature: null, isInspectorOpen: false }),

  // ── Write actions (optimistic) ──
  deposit: (amount) =>
    set((state) => ({
      ecosystem: {
        ...state.ecosystem,
        totalDeposits: state.ecosystem.totalDeposits + amount,
      },
    })),

  withdraw: (amount) =>
    set((state) => ({
      ecosystem: {
        ...state.ecosystem,
        totalDeposits: Math.max(0, state.ecosystem.totalDeposits - amount),
      },
    })),
}));
