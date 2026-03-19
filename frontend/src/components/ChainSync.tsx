"use client";

import { useEffect, useCallback, useRef } from "react";
import { usePublicClient } from "wagmi";
import {
  useEcosystemState,
  useActiveCreatureAddresses,
  useCreatures,
} from "@/hooks/useContracts";
import { useEcosystemStore } from "@/stores/ecosystem";
import { GenePoolABI, CONTRACTS } from "@/lib/contracts";
import type { EpochRecord } from "@/lib/types";

/**
 * ChainSync — Invisible component that reads on-chain data via wagmi hooks
 * and pushes it into the Zustand store. Must be inside WagmiProvider.
 *
 * Also fetches EvolutionRun events from the GenePool contract to populate
 * the Evolution History charts (fitness, population, births/deaths).
 */
export default function ChainSync() {
  const { ecosystem, isLoading: ecoLoading, refetch: refetchEco } = useEcosystemState();
  const { addresses, isLoading: addrLoading, refetch: refetchAddr } = useActiveCreatureAddresses();
  const { creatures, isLoading: creaturesLoading } = useCreatures(addresses);

  const setEcosystem = useEcosystemStore((s) => s.setEcosystem);
  const setCreatures = useEcosystemStore((s) => s.setCreatures);
  const setLoading = useEcosystemStore((s) => s.setLoading);
  const addEpochRecord = useEcosystemStore((s) => s.addEpochRecord);
  const epochsInStore = useEcosystemStore((s) => s.epochs);

  const publicClient = usePublicClient();
  const fetchedRef = useRef(false);

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

  // ── Fetch EvolutionRun events from GenePool to build epoch history ──
  const fetchEpochHistory = useCallback(async () => {
    if (!publicClient) return;

    try {
      const logs = await publicClient.getContractEvents({
        address: CONTRACTS.genePool,
        abi: GenePoolABI,
        eventName: "EvolutionRun",
        fromBlock: BigInt(0),
        toBlock: "latest",
      });

      for (const log of logs) {
        const args = log.args as {
          epoch?: bigint;
          totalCreatures?: bigint;
          killed?: bigint;
          bred?: bigint;
        };

        if (args.epoch === undefined) continue;

        const epochNum = Number(args.epoch);
        const births = Number(args.bred ?? BigInt(0));
        const deaths = Number(args.killed ?? BigInt(0));
        const populationSize = Number(args.totalCreatures ?? BigInt(0));

        // For topFitness, compute from current creature fitness scores
        // (best approximation without per-epoch historical fitness storage)
        let topFitness = 0;
        if (creatures.length > 0) {
          const scores = creatures.map((c) => c.fitnessScore).filter((s) => s > 0);
          topFitness = scores.length > 0 ? Math.max(...scores) : 0;
        }

        // For avgYield, compute from ecosystem totalYieldGenerated
        // divided by epoch count (rough approximation)
        let avgYield = 0;
        if (ecosystem && ecosystem.currentEpoch > 0) {
          const totalYieldUSDC = Math.abs(ecosystem.yieldGenerated) / 1e6;
          avgYield = parseFloat(
            (totalYieldUSDC / ecosystem.currentEpoch).toFixed(2)
          );
        }

        const record: EpochRecord = {
          epoch: epochNum,
          births,
          deaths,
          topFitness,
          avgYield,
          populationSize,
        };

        addEpochRecord(record);
      }
    } catch (err) {
      console.error("[ChainSync] Failed to fetch EvolutionRun events:", err);
    }
  }, [publicClient, creatures, ecosystem, addEpochRecord]);

  // Fetch epoch history on mount and when ecosystem epoch changes
  useEffect(() => {
    if (!publicClient) return;
    // Fetch whenever the ecosystem epoch changes (new epoch completed)
    if (ecosystem && ecosystem.currentEpoch > 0) {
      fetchEpochHistory();
    }
  }, [publicClient, ecosystem?.currentEpoch, fetchEpochHistory]);

  // ── Poll for updates every 5 seconds (Anvil block-time = 1s) ──
  useEffect(() => {
    const interval = setInterval(() => {
      refetchEco();
      refetchAddr();
    }, 5_000);

    return () => clearInterval(interval);
  }, [refetchEco, refetchAddr]);

  return null; // invisible sync component
}
