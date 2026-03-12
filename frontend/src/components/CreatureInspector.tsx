"use client";

import { motion, AnimatePresence } from "framer-motion";
import { X, Dna, Activity, Clock, GitBranch, Target, Shield, Zap } from "lucide-react";
import { useEcosystemStore } from "@/stores/ecosystem";
import { POOL_TYPE_NAMES, POOL_TYPE_COLORS, CHAIN_NAMES, type Creature } from "@/lib/types";

const DNA_FIELDS: {
  key: keyof Creature["dna"];
  label: string;
  icon: typeof Dna;
  format: (v: number) => string;
}[] = [
  { key: "targetChainId", label: "Target Chain", icon: Target, format: (v) => CHAIN_NAMES[v] || `Chain ${v}` },
  { key: "poolType", label: "Pool Type", icon: Zap, format: (v) => POOL_TYPE_NAMES[v] || `Type ${v}` },
  { key: "allocationRatio", label: "Allocation %", icon: Activity, format: (v) => `${(v / 100).toFixed(1)}%` },
  { key: "rebalanceThreshold", label: "Rebalance Thr.", icon: Activity, format: (v) => `${(v / 100).toFixed(1)}%` },
  { key: "maxSlippage", label: "Max Slippage", icon: Shield, format: (v) => `${(v / 100).toFixed(2)}%` },
  { key: "yieldFloor", label: "Yield Floor", icon: Activity, format: (v) => `${(v / 100).toFixed(1)}%` },
  { key: "riskCeiling", label: "Risk Ceiling", icon: Shield, format: (v) => `${v}/10` },
  { key: "entryTiming", label: "Entry Timing", icon: Clock, format: (v) => ["Immediate", "Gradual", "DCA", "Momentum", "Mean Rev.", "Contrarian"][v] || `${v}` },
  { key: "exitTiming", label: "Exit Timing", icon: Clock, format: (v) => ["Immediate", "Gradual", "Trailing", "Target", "Time-based", "Panic"][v] || `${v}` },
  { key: "hedgeRatio", label: "Hedge Ratio", icon: Shield, format: (v) => `${(v / 100).toFixed(1)}%` },
];

export default function CreatureInspector() {
  const { selectedCreature: creature, isInspectorOpen, closeInspector } = useEcosystemStore();

  return (
    <AnimatePresence>
      {isInspectorOpen && creature && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={closeInspector}
            className="fixed inset-0 bg-nb-ink/40 backdrop-blur-sm z-50"
          />

          {/* Panel */}
          <motion.div
            initial={{ x: "100%", opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: "100%", opacity: 0 }}
            transition={{ type: "spring", damping: 25, stiffness: 300 }}
            className="fixed right-0 top-0 bottom-0 w-full max-w-md z-50 overflow-y-auto bg-nb-bg border-l-3 border-nb-ink shadow-2xl"
          >
            <div className="p-6 space-y-6">
              {/* Header */}
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div
                    className="w-14 h-14 border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center font-display font-bold text-xl"
                    style={{ backgroundColor: POOL_TYPE_COLORS[creature.dna.poolType] || "#6EE7B7" }}
                  >
                    G{creature.generation}
                  </div>
                  <div>
                    <h2 className="font-display font-bold text-xl">
                      Creature #{creature.address.slice(2, 8)}
                    </h2>
                    <div className="flex items-center gap-2 mt-1">
                      <span
                        className={`nb-badge ${creature.isAlive ? "bg-nb-ok/20 text-nb-ok" : "bg-nb-error/20 text-nb-error"}`}
                      >
                        {creature.isAlive ? "ALIVE" : "DEAD"}
                      </span>
                      <span className="nb-badge bg-nb-purple/20 text-nb-purple">
                        Gen {creature.generation}
                      </span>
                    </div>
                  </div>
                </div>
                <button
                  onClick={closeInspector}
                  className="w-10 h-10 border-3 border-nb-ink rounded-nb bg-nb-card hover:bg-nb-error hover:text-white transition-colors flex items-center justify-center"
                >
                  <X size={18} />
                </button>
              </div>

              {/* Address */}
              <div className="bg-nb-card border-3 border-nb-ink rounded-nb p-3">
                <p className="text-xs font-mono text-nb-ink/50 uppercase mb-1">Address</p>
                <p className="font-mono text-sm break-all">{creature.address}</p>
              </div>

              {/* Fitness Score */}
              <div className="bg-nb-accent/20 border-3 border-nb-ink rounded-nb p-4">
                <p className="text-xs font-mono text-nb-ink/60 uppercase mb-1">Fitness Score</p>
                <div className="flex items-end gap-2">
                  <span className="font-display font-bold text-4xl">
                    {(creature.fitnessScore / 1000).toFixed(1)}
                  </span>
                  <span className="text-sm font-mono text-nb-ink/50 pb-1">/ 100</span>
                </div>
                <div className="mt-2 w-full h-3 bg-nb-bg border-2 border-nb-ink rounded-full overflow-hidden">
                  <div
                    className="h-full bg-nb-accent transition-all"
                    style={{ width: `${Math.min(100, creature.fitnessScore / 1000)}%` }}
                  />
                </div>
              </div>

              {/* Performance Stats */}
              <div>
                <h3 className="font-display font-semibold text-sm uppercase tracking-wider mb-3 flex items-center gap-2">
                  <Activity size={16} /> Performance
                </h3>
                <div className="grid grid-cols-2 gap-3">
                  <Stat
                    label="Last Return"
                    value={`${creature.performance.lastReturn >= 0 ? "+" : ""}${(creature.performance.lastReturn / 1000).toFixed(1)}%`}
                    positive={creature.performance.lastReturn >= 0}
                  />
                  <Stat
                    label="Cumulative"
                    value={`${creature.performance.cumulativeReturn >= 0 ? "+" : ""}${(creature.performance.cumulativeReturn / 1000).toFixed(1)}%`}
                    positive={creature.performance.cumulativeReturn >= 0}
                  />
                  <Stat
                    label="Epochs Survived"
                    value={creature.performance.epochsSurvived.toString()}
                  />
                  <Stat
                    label="Max Drawdown"
                    value={`${(creature.performance.maxDrawdown / 1000).toFixed(1)}%`}
                    positive={false}
                  />
                </div>
              </div>

              {/* Balance */}
              <div className="bg-nb-card border-3 border-nb-ink rounded-nb p-4">
                <p className="text-xs font-mono text-nb-ink/60 uppercase mb-1">Balance</p>
                <p className="font-display font-bold text-2xl">
                  ${(creature.balance / 1e6).toLocaleString("en-US", { minimumFractionDigits: 0 })}
                  <span className="text-sm font-normal text-nb-ink/50 ml-1">USDC</span>
                </p>
              </div>

              {/* DNA Genome */}
              <div>
                <h3 className="font-display font-semibold text-sm uppercase tracking-wider mb-3 flex items-center gap-2">
                  <Dna size={16} /> DNA Genome
                </h3>
                <div className="space-y-2">
                  {DNA_FIELDS.map(({ key, label, icon: Icon, format }) => (
                    <div
                      key={key}
                      className="flex items-center justify-between bg-nb-card border-2 border-nb-ink/30 rounded-nb px-3 py-2"
                    >
                      <div className="flex items-center gap-2 text-sm">
                        <Icon size={14} className="text-nb-ink/50" />
                        <span className="text-nb-ink/70">{label}</span>
                      </div>
                      <span className="font-mono text-sm font-semibold">
                        {format(creature.dna[key])}
                      </span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Lineage */}
              {(creature.parent1 || creature.parent2) && (
                <div>
                  <h3 className="font-display font-semibold text-sm uppercase tracking-wider mb-3 flex items-center gap-2">
                    <GitBranch size={16} /> Lineage
                  </h3>
                  <div className="space-y-2">
                    {creature.parent1 && (
                      <div className="bg-nb-card border-2 border-nb-ink/30 rounded-nb px-3 py-2">
                        <p className="text-xs text-nb-ink/50">Parent 1</p>
                        <p className="font-mono text-sm truncate">{creature.parent1}</p>
                      </div>
                    )}
                    {creature.parent2 && (
                      <div className="bg-nb-card border-2 border-nb-ink/30 rounded-nb px-3 py-2">
                        <p className="text-xs text-nb-ink/50">Parent 2</p>
                        <p className="font-mono text-sm truncate">{creature.parent2}</p>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* Born epoch */}
              <p className="text-xs text-center text-nb-ink/40 font-mono pt-2 border-t-2 border-nb-ink/10">
                Born in Epoch {creature.birthEpoch} &middot; Generation {creature.generation}
              </p>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

function Stat({ label, value, positive }: { label: string; value: string; positive?: boolean }) {
  return (
    <div className="bg-nb-bg border-3 border-nb-ink rounded-nb p-3">
      <p className="text-xs font-mono text-nb-ink/60 uppercase">{label}</p>
      <p
        className={`font-display font-bold text-lg ${
          positive === true ? "text-nb-ok" : positive === false ? "text-nb-error" : ""
        }`}
      >
        {value}
      </p>
    </div>
  );
}
