import { create } from "zustand";
import { Creature, EcosystemState, EpochRecord } from "@/lib/types";
import {
  MOCK_CREATURES,
  MOCK_ECOSYSTEM,
  MOCK_EPOCHS,
  MOCK_USER,
} from "@/lib/mock-data";

interface EcosystemStore {
  // State
  ecosystem: EcosystemState;
  creatures: Creature[];
  epochs: EpochRecord[];
  user: typeof MOCK_USER;
  selectedCreature: Creature | null;
  isInspectorOpen: boolean;

  // Actions
  selectCreature: (c: Creature | null) => void;
  openInspector: (c: Creature) => void;
  closeInspector: () => void;
  deposit: (amount: number) => void;
  withdraw: (amount: number) => void;
}

export const useEcosystemStore = create<EcosystemStore>((set) => ({
  ecosystem: MOCK_ECOSYSTEM,
  creatures: MOCK_CREATURES,
  epochs: MOCK_EPOCHS,
  user: MOCK_USER,
  selectedCreature: null,
  isInspectorOpen: false,

  selectCreature: (c) => set({ selectedCreature: c }),

  openInspector: (c) =>
    set({ selectedCreature: c, isInspectorOpen: true }),

  closeInspector: () =>
    set({ selectedCreature: null, isInspectorOpen: false }),

  deposit: (amount) =>
    set((state) => ({
      user: {
        ...state.user,
        deposited: state.user.deposited + amount,
        shares: state.user.shares + Math.floor(amount / 1000),
        shareValue: state.user.shareValue + amount,
      },
      ecosystem: {
        ...state.ecosystem,
        totalDeposits: state.ecosystem.totalDeposits + amount,
      },
    })),

  withdraw: (amount) =>
    set((state) => ({
      user: {
        ...state.user,
        deposited: Math.max(0, state.user.deposited - amount),
        shares: Math.max(0, state.user.shares - Math.floor(amount / 1000)),
        shareValue: Math.max(0, state.user.shareValue - amount),
      },
      ecosystem: {
        ...state.ecosystem,
        totalDeposits: Math.max(
          0,
          state.ecosystem.totalDeposits - amount
        ),
      },
    })),
}));
