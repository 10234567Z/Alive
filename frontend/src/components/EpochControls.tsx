"use client";

import { useState, useCallback, useEffect, useRef } from "react";
import { Play, Pause, SkipForward, Zap, Clock, Loader2, CheckCircle2, AlertCircle } from "lucide-react";
import { useAccount, useWriteContract, useReadContract, useBlockNumber } from "wagmi";
import { waitForTransactionReceipt } from "@wagmi/core";
import { useQueryClient } from "@tanstack/react-query";
import { EcosystemABI, CONTRACTS, wagmiConfig } from "@/lib/contracts";
import { useEcosystemStore } from "@/stores/ecosystem";
import { Phase } from "@/lib/types";

const PHASE_FLOW: { label: string; color: string; icon: string }[] = [
  { label: "IDLE", color: "bg-nb-card", icon: "⏸" },
  { label: "FEEDING", color: "bg-nb-accent", icon: "🍽" },
  { label: "HARVESTING", color: "bg-nb-warn", icon: "🌾" },
  { label: "EVOLVING", color: "bg-nb-purple", icon: "🧬" },
  { label: "ALLOCATING", color: "bg-nb-accent-2", icon: "💰" },
];

export default function EpochControls() {
  const { isConnected } = useAccount();
  const { ecosystem } = useEcosystemStore();
  const queryClient = useQueryClient();
  const { writeContractAsync } = useWriteContract();

  const [status, setStatus] = useState("");
  const [isPending, setIsPending] = useState(false);
  const [autoRunning, setAutoRunning] = useState(false);
  const autoRef = useRef(false);

  // Read epoch timing info
  const { data: epochDuration } = useReadContract({
    address: CONTRACTS.ecosystem,
    abi: EcosystemABI,
    functionName: "epochDuration",
  });

  const { data: lastEpochBlock } = useReadContract({
    address: CONTRACTS.ecosystem,
    abi: EcosystemABI,
    functionName: "lastEpochBlock",
  });

  const { data: currentBlock } = useBlockNumber({ watch: true });

  const duration = Number(epochDuration ?? BigInt(100));
  const lastBlock = Number(lastEpochBlock ?? BigInt(0));
  const block = Number(currentBlock ?? BigInt(0));
  const blocksUntilNext = Math.max(0, lastBlock + duration - block);
  const canAdvance = ecosystem.phase !== Phase.IDLE || blocksUntilNext === 0;

  const advanceEpoch = useCallback(async () => {
    if (isPending) return;
    setIsPending(true);
    setStatus("Advancing epoch...");

    try {
      const hash = await writeContractAsync({
        address: CONTRACTS.ecosystem,
        abi: EcosystemABI,
        functionName: "advanceEpoch",
      });

      await waitForTransactionReceipt(wagmiConfig, { hash });
      setStatus("Phase advanced!");
      queryClient.invalidateQueries();

      setTimeout(() => setStatus(""), 2000);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed";
      if (msg.includes("epoch not elapsed")) {
        setStatus("Waiting for epoch duration...");
      } else {
        setStatus(msg.slice(0, 60));
      }
      setTimeout(() => setStatus(""), 3000);
    } finally {
      setIsPending(false);
    }
  }, [isPending, writeContractAsync, queryClient]);

  // Run full epoch cycle (all 4 phases)
  const runFullCycle = useCallback(async () => {
    if (isPending) return;
    setIsPending(true);

    const phases = ["FEEDING", "HARVESTING", "EVOLVING", "ALLOCATING"];
    const startPhase = ecosystem.phase;

    // If IDLE, we need to go through all 4.
    // If mid-cycle, finish remaining phases.
    const remaining = startPhase === Phase.IDLE ? 4 : (4 - startPhase);

    for (let i = 0; i < remaining; i++) {
      const phaseIdx = startPhase === Phase.IDLE ? i : (startPhase + i - 1);
      setStatus(`${phases[Math.min(phaseIdx, 3)]}...`);
      try {
        const hash = await writeContractAsync({
          address: CONTRACTS.ecosystem,
          abi: EcosystemABI,
          functionName: "advanceEpoch",
        });
        await waitForTransactionReceipt(wagmiConfig, { hash });
        queryClient.invalidateQueries();
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : "Failed";
        setStatus(`Error: ${msg.slice(0, 40)}`);
        setIsPending(false);
        setTimeout(() => setStatus(""), 3000);
        return;
      }
    }

    setStatus("Epoch cycle complete!");
    setIsPending(false);
    setTimeout(() => setStatus(""), 2000);
  }, [isPending, ecosystem.phase, writeContractAsync, queryClient]);

  // Auto-run effect
  useEffect(() => {
    autoRef.current = autoRunning;
  }, [autoRunning]);

  useEffect(() => {
    if (!autoRunning) return;

    const interval = setInterval(async () => {
      if (!autoRef.current || isPending) return;
      // Only auto-advance if we can
      try {
        await advanceEpoch();
      } catch {
        // Ignore — will retry
      }
    }, 5000);

    return () => clearInterval(interval);
  }, [autoRunning, isPending, advanceEpoch]);

  if (!isConnected) return null;

  return (
    <div className="nb-card p-5">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-display font-bold text-lg flex items-center gap-2">
          <Zap size={20} /> Epoch Controls
        </h3>
        <span className="nb-badge bg-nb-accent/20 font-mono text-sm">
          Epoch #{ecosystem.currentEpoch}
        </span>
      </div>

      {/* Phase progress */}
      <div className="flex items-center gap-1 mb-4">
        {PHASE_FLOW.map((p, i) => {
          const isActive = i === ecosystem.phase;
          const isDone = i < ecosystem.phase || (ecosystem.phase === Phase.IDLE && i === 0 && ecosystem.currentEpoch > 0);
          return (
            <div
              key={p.label}
              className={`flex-1 h-8 flex items-center justify-center text-xs font-mono border-2 border-nb-ink rounded-md transition-all ${
                isActive
                  ? `${p.color} font-bold scale-105 shadow-nb-sm`
                  : isDone
                    ? "bg-nb-ink/10"
                    : "bg-nb-bg"
              }`}
            >
              <span className="hidden sm:inline">{p.icon} {p.label}</span>
              <span className="sm:hidden">{p.icon}</span>
            </div>
          );
        })}
      </div>

      {/* Block countdown */}
      {ecosystem.phase === Phase.IDLE && blocksUntilNext > 0 && (
        <div className="flex items-center gap-2 text-sm text-nb-ink/60 mb-4 font-mono">
          <Clock size={14} />
          <span>{blocksUntilNext} blocks until next epoch</span>
          <div className="flex-1 bg-nb-ink/10 rounded-full h-2 border border-nb-ink/20">
            <div
              className="bg-nb-accent h-full rounded-full transition-all"
              style={{ width: `${Math.min(100, ((duration - blocksUntilNext) / duration) * 100)}%` }}
            />
          </div>
        </div>
      )}

      {/* Action buttons */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={advanceEpoch}
          disabled={isPending || !canAdvance}
          className="nb-btn flex-1 flex items-center justify-center gap-2 disabled:opacity-50"
        >
          {isPending ? (
            <Loader2 size={16} className="animate-spin" />
          ) : (
            <SkipForward size={16} />
          )}
          Next Phase
        </button>

        <button
          onClick={runFullCycle}
          disabled={isPending || (ecosystem.phase === Phase.IDLE && blocksUntilNext > 0)}
          className="nb-btn bg-nb-accent flex-1 flex items-center justify-center gap-2 disabled:opacity-50"
        >
          {isPending ? (
            <Loader2 size={16} className="animate-spin" />
          ) : (
            <Play size={16} />
          )}
          Run Full Cycle
        </button>

        <button
          onClick={() => setAutoRunning(!autoRunning)}
          className={`nb-btn flex items-center gap-2 ${
            autoRunning ? "bg-nb-warn" : "bg-nb-purple/20"
          }`}
        >
          {autoRunning ? <Pause size={16} /> : <Play size={16} />}
          {autoRunning ? "Stop" : "Auto"}
        </button>
      </div>

      {/* Status */}
      {status && (
        <div className={`mt-3 flex items-center gap-2 text-sm font-mono ${
          status.includes("Error") || status.includes("Failed")
            ? "text-red-600"
            : status.includes("complete") || status.includes("advanced")
              ? "text-green-600"
              : "text-nb-ink/60"
        }`}>
          {status.includes("Error") ? (
            <AlertCircle size={14} />
          ) : status.includes("complete") ? (
            <CheckCircle2 size={14} />
          ) : (
            <Loader2 size={14} className="animate-spin" />
          )}
          {status}
        </div>
      )}
    </div>
  );
}
