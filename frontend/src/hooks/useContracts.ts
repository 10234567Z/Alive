"use client";

import { useReadContract, useReadContracts } from "wagmi";
import { EcosystemABI, CreatureABI, CONTRACTS } from "@/lib/contracts";
import type { Creature, EcosystemState } from "@/lib/types";
import { Phase } from "@/lib/types";

// ── Read ecosystem state ──

export function useEcosystemState() {
  const { data, isLoading, error, refetch } = useReadContract({
    address: CONTRACTS.ecosystem,
    abi: EcosystemABI,
    functionName: "getEcosystemState",
  });

  const state: EcosystemState | null = data
    ? {
        totalDeposits: Number(data[0]),
        currentEpoch: Number(data[1]),
        creatureCount: Number(data[2]),
        yieldGenerated: Number(data[3]),
        phase: Number(data[4]) as Phase,
      }
    : null;

  return { ecosystem: state, isLoading, error, refetch };
}

// ── Read active creature addresses ──

export function useActiveCreatureAddresses() {
  const { data, isLoading, error, refetch } = useReadContract({
    address: CONTRACTS.ecosystem,
    abi: EcosystemABI,
    functionName: "getActiveCreatures",
  });

  return {
    addresses: (data as `0x${string}`[] | undefined) ?? [],
    isLoading,
    error,
    refetch,
  };
}

// ── Read full creature data for a list of addresses ──

export function useCreatures(addresses: `0x${string}`[]) {
  // Build multicall reads for all creatures
  const contracts = addresses.flatMap((addr) => [
    {
      address: addr,
      abi: CreatureABI,
      functionName: "getDNA" as const,
    },
    {
      address: addr,
      abi: CreatureABI,
      functionName: "getPerformance" as const,
    },
    {
      address: addr,
      abi: CreatureABI,
      functionName: "generation" as const,
    },
    {
      address: addr,
      abi: CreatureABI,
      functionName: "parent1" as const,
    },
    {
      address: addr,
      abi: CreatureABI,
      functionName: "parent2" as const,
    },
    {
      address: addr,
      abi: CreatureABI,
      functionName: "isAlive" as const,
    },
    {
      address: addr,
      abi: CreatureABI,
      functionName: "balance" as const,
    },
    {
      address: addr,
      abi: CreatureABI,
      functionName: "birthEpoch" as const,
    },
  ]);

  // Also read fitness scores from ecosystem
  const fitnessContracts = addresses.map((addr) => ({
    address: CONTRACTS.ecosystem,
    abi: EcosystemABI,
    functionName: "latestFitness" as const,
    args: [addr] as const,
  }));

  const { data: creatureData, isLoading: loadingCreatures } = useReadContracts({
    contracts: contracts.length > 0 ? contracts : undefined,
    query: { enabled: addresses.length > 0 },
  });

  const { data: fitnessData, isLoading: loadingFitness } = useReadContracts({
    contracts: fitnessContracts.length > 0 ? fitnessContracts : undefined,
    query: { enabled: addresses.length > 0 },
  });

  const ZERO_ADDR = "0x0000000000000000000000000000000000000000";

  const creatures: Creature[] = [];

  if (creatureData && fitnessData) {
    const FIELDS_PER_CREATURE = 8;

    for (let i = 0; i < addresses.length; i++) {
      const base = i * FIELDS_PER_CREATURE;
      const dnaResult = creatureData[base]?.result;
      const perfResult = creatureData[base + 1]?.result;
      const genResult = creatureData[base + 2]?.result;
      const p1Result = creatureData[base + 3]?.result;
      const p2Result = creatureData[base + 4]?.result;
      const aliveResult = creatureData[base + 5]?.result;
      const balResult = creatureData[base + 6]?.result;
      const birthResult = creatureData[base + 7]?.result;
      const fitResult = fitnessData[i]?.result;

      // Skip if any critical data is missing
      if (!dnaResult || !perfResult) continue;

      // dnaResult is a tuple object
      const dna = dnaResult as {
        targetChainId: number;
        poolType: number;
        allocationRatio: number;
        rebalanceThreshold: number;
        maxSlippage: number;
        yieldFloor: number;
        riskCeiling: number;
        entryTiming: number;
        exitTiming: number;
        hedgeRatio: number;
      };

      // perfResult: [lastReturn, cumulativeReturn, epochsSurvived, maxDrawdown, balance]
      const perf = perfResult as readonly [bigint, bigint, bigint, bigint, bigint];

      const parent1Addr = (p1Result as string) || ZERO_ADDR;
      const parent2Addr = (p2Result as string) || ZERO_ADDR;

      creatures.push({
        address: addresses[i],
        dna: {
          targetChainId: Number(dna.targetChainId),
          poolType: Number(dna.poolType),
          allocationRatio: Number(dna.allocationRatio),
          rebalanceThreshold: Number(dna.rebalanceThreshold),
          maxSlippage: Number(dna.maxSlippage),
          yieldFloor: Number(dna.yieldFloor),
          riskCeiling: Number(dna.riskCeiling),
          entryTiming: Number(dna.entryTiming),
          exitTiming: Number(dna.exitTiming),
          hedgeRatio: Number(dna.hedgeRatio),
        },
        performance: {
          lastReturn: Number(perf[0]),
          cumulativeReturn: Number(perf[1]),
          epochsSurvived: Number(perf[2]),
          maxDrawdown: Number(perf[3]),
        },
        fitnessScore: Number(fitResult ?? BigInt(0)),
        generation: Number(genResult ?? BigInt(1)),
        parent1: parent1Addr === ZERO_ADDR ? null : parent1Addr,
        parent2: parent2Addr === ZERO_ADDR ? null : parent2Addr,
        isAlive: (aliveResult as boolean) ?? true,
        balance: Number(balResult ?? BigInt(0)),
        birthEpoch: Number(birthResult ?? BigInt(0)),
      });
    }
  }

  return {
    creatures,
    isLoading: loadingCreatures || loadingFitness,
  };
}

// ── Read user shares & value ──

export function useUserPosition(userAddress: `0x${string}` | undefined) {
  const { data: sharesData } = useReadContract({
    address: CONTRACTS.ecosystem,
    abi: EcosystemABI,
    functionName: "shares",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress },
  });

  const { data: valueData } = useReadContract({
    address: CONTRACTS.ecosystem,
    abi: EcosystemABI,
    functionName: "shareValue",
    args: userAddress ? [userAddress] : undefined,
    query: { enabled: !!userAddress },
  });

  return {
    shares: Number(sharesData ?? BigInt(0)),
    shareValue: Number(valueData ?? BigInt(0)),
  };
}
