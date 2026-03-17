"use client";

import { useEffect, useState } from "react";
import { Zap, Clock, Activity, Loader2 } from "lucide-react";
import { useAccount, useReadContract, useBlockNumber } from "wagmi";
import { EcosystemABI, CONTRACTS } from "@/lib/contracts";
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
  const [prevEpoch, setPrevEpoch] = useState(0);
  const [flash, setFlash] = useState(false);

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
  const progress = duration > 0 ? Math.min(100, ((duration - blocksUntilNext) / duration) * 100) : 0;

  // Flash animation when epoch changes
  useEffect(() => {
    if (ecosystem.currentEpoch > prevEpoch && prevEpoch > 0) {
      setFlash(true);
      setTimeout(() => setFlash(false), 1500);
    }
    setPrevEpoch(ecosystem.currentEpoch);
  }, [ecosystem.currentEpoch, prevEpoch]);

  if (!isConnected) return null;

  const isProcessing = ecosystem.phase !== Phase.IDLE;

  return (
    <div className={`nb-card p-5 transition-all ${flash ? "ring-2 ring-nb-accent shadow-lg" : ""}`}>
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-display font-bold text-lg flex items-center gap-2">
          <Zap size={20} /> Epoch Status
        </h3>
        <span className="nb-badge bg-nb-accent/20 font-mono text-sm">
          Epoch #{ecosystem.currentEpoch}
        </span>
      </div>

      {/* Phase progress */}
      <div className="flex items-center gap-2 mb-5">
        {PHASE_FLOW.map((p, i) => {
          const isActive = i === ecosystem.phase;
          const isDone = i < ecosystem.phase || (ecosystem.phase === Phase.IDLE && i === 0 && ecosystem.currentEpoch > 0);
          return (
            <div
              key={p.label}
              className={`flex-1 h-9 flex items-center justify-center text-[11px] font-mono border-2 border-nb-ink rounded-lg transition-all ${
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

      {/* Status info */}
      {isProcessing ? (
        <div className="flex items-center gap-2 text-sm font-mono text-nb-accent">
          <Loader2 size={14} className="animate-spin" />
          <span>Processing {PHASE_FLOW[ecosystem.phase]?.label ?? "..."}...</span>
        </div>
      ) : blocksUntilNext > 0 ? (
        <div className="space-y-2">
          <div className="flex items-center gap-2 text-sm text-nb-ink/60 font-mono">
            <Clock size={14} />
            <span>{blocksUntilNext} blocks until next epoch</span>
          </div>
          <div className="flex-1 bg-nb-ink/10 rounded-full h-2 border border-nb-ink/20">
            <div
              className="bg-nb-accent h-full rounded-full transition-all"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>
      ) : (
        <div className="flex items-center gap-2 text-sm font-mono text-green-600">
          <Activity size={14} />
          <span>Ready — keeper will advance shortly</span>
        </div>
      )}
    </div>
  );
}
