"use client";

import { useEffect } from "react";
import { useEcosystemState, useActiveCreatureAddresses, useCreatures } from "@/hooks/useContracts";
import { useEcosystemStore } from "@/stores/ecosystem";

/**
 * ChainSync — Invisible component that reads on-chain data via wagmi hooks
 * and pushes it into the Zustand store. Must be inside WagmiProvider.
 */
export default function ChainSync() {
  const { ecosystem, isLoading: ecoLoading } = useEcosystemState();
  const { addresses, isLoading: addrLoading } = useActiveCreatureAddresses();
  const { creatures, isLoading: creaturesLoading } = useCreatures(addresses);

  const setEcosystem = useEcosystemStore((s) => s.setEcosystem);
  const setCreatures = useEcosystemStore((s) => s.setCreatures);
  const setLoading = useEcosystemStore((s) => s.setLoading);

  // Push ecosystem state to store
  useEffect(() => {
    if (ecosystem) {
      setEcosystem(ecosystem);
    }
  }, [ecosystem, setEcosystem]);

  // Push creatures to store
  useEffect(() => {
    if (creatures.length > 0) {
      setCreatures(creatures);
    }
  }, [creatures, setCreatures]);

  // Update loading state
  useEffect(() => {
    setLoading(ecoLoading || addrLoading || creaturesLoading);
  }, [ecoLoading, addrLoading, creaturesLoading, setLoading]);

  return null; // invisible sync component
}
