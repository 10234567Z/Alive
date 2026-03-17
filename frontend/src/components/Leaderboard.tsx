"use client";

import { motion } from "framer-motion";
import { Crown, Skull, TrendingUp, TrendingDown, ChevronRight } from "lucide-react";
import { useEcosystemStore } from "@/stores/ecosystem";
import { POOL_TYPE_NAMES, POOL_TYPE_COLORS, CHAIN_NAMES, type Creature } from "@/lib/types";
import { useMounted } from "@/lib/use-mounted";

export default function Leaderboard({ filter = "all" }: { filter?: "all" | "alive" | "dead" }) {
  const mounted = useMounted();
  const { creatures, openInspector } = useEcosystemStore();

  if (!mounted) return null;

  const filtered = filter === "all" ? creatures : creatures.filter((c) => filter === "alive" ? c.isAlive : !c.isAlive);
  const sorted = [...filtered].sort((a, b) => b.fitnessScore - a.fitnessScore);

  return (
    <div className="space-y-3">
      {/* Table Header */}
      <div className="grid grid-cols-12 gap-2 px-4 py-2 text-xs font-mono text-nb-ink/50 uppercase">
        <span className="col-span-1">#</span>
        <span className="col-span-3">Creature</span>
        <span className="col-span-2">Strategy</span>
        <span className="col-span-1 text-center">Gen</span>
        <span className="col-span-1 text-center">Epochs</span>
        <span className="col-span-2 text-right">Return</span>
        <span className="col-span-2 text-right">Fitness</span>
      </div>

      {/* Rows */}
      {sorted.map((creature, i) => (
        <LeaderboardRow
          key={creature.address}
          creature={creature}
          rank={i + 1}
          onClick={() => openInspector(creature)}
        />
      ))}
    </div>
  );
}

function LeaderboardRow({
  creature,
  rank,
  onClick,
}: {
  creature: Creature;
  rank: number;
  onClick: () => void;
}) {
  const isTop3 = rank <= 3;
  const isDead = !creature.isAlive;

  return (
    <motion.button
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: rank * 0.04 }}
      onClick={onClick}
      className={`
        w-full grid grid-cols-12 gap-2 items-center px-4 py-3 text-left
        border-3 border-nb-ink rounded-nb transition-all cursor-pointer
        ${isDead ? "bg-nb-error/5 opacity-60" : "bg-nb-card"}
        ${isTop3 ? "shadow-nb-sm" : "shadow-none"}
        hover:-translate-y-0.5 hover:shadow-nb
      `}
    >
      {/* Rank */}
      <div className="col-span-1">
        {rank === 1 ? (
          <div className="w-8 h-8 bg-nb-warn border-2 border-nb-ink rounded-lg flex items-center justify-center">
            <Crown size={16} />
          </div>
        ) : rank === 2 ? (
          <div className="w-8 h-8 bg-gray-300 border-2 border-nb-ink rounded-lg flex items-center justify-center font-display font-bold">
            2
          </div>
        ) : rank === 3 ? (
          <div className="w-8 h-8 bg-amber-700/30 border-2 border-nb-ink rounded-lg flex items-center justify-center font-display font-bold">
            3
          </div>
        ) : (
          <span className="font-mono text-sm text-nb-ink/50 pl-2">{rank}</span>
        )}
      </div>

      {/* Creature ID */}
      <div className="col-span-3 flex items-center gap-2">
        <div
          className="w-8 h-8 border-2 border-nb-ink rounded-lg flex items-center justify-center text-xs font-bold"
          style={{ backgroundColor: POOL_TYPE_COLORS[creature.dna.poolType] || "#6EE7B7" }}
        >
          {isDead ? <Skull size={14} /> : `G${creature.generation}`}
        </div>
        <div>
          <p className="font-mono text-sm font-medium">
            #{creature.address.slice(2, 8)}
          </p>
          <p className="text-xs text-nb-ink/40">
            {CHAIN_NAMES[creature.dna.targetChainId] || `Chain ${creature.dna.targetChainId}`}
          </p>
        </div>
      </div>

      {/* Strategy */}
      <div className="col-span-2">
        <span
          className="nb-badge text-xs"
          style={{
            backgroundColor: `${POOL_TYPE_COLORS[creature.dna.poolType]}33`,
          }}
        >
          {POOL_TYPE_NAMES[creature.dna.poolType]}
        </span>
      </div>

      {/* Gen */}
      <div className="col-span-1 text-center font-mono text-sm">
        {creature.generation}
      </div>

      {/* Epochs */}
      <div className="col-span-1 text-center font-mono text-sm">
        {creature.performance.epochsSurvived}
      </div>

      {/* Return */}
      <div className="col-span-2 text-right flex items-center justify-end gap-1">
        {creature.performance.cumulativeReturn >= 0 ? (
          <TrendingUp size={14} className="text-nb-ok" />
        ) : (
          <TrendingDown size={14} className="text-nb-error" />
        )}
        <span
          className={`font-mono text-sm font-semibold ${
            creature.performance.cumulativeReturn >= 0 ? "text-nb-ok" : "text-nb-error"
          }`}
        >
          {creature.performance.cumulativeReturn >= 0 ? "+" : ""}
          ${(Math.abs(creature.performance.cumulativeReturn) / 1e6).toFixed(0)}
        </span>
      </div>

      {/* Fitness */}
      <div className="col-span-2 flex items-center justify-end gap-2">
        <div className="flex flex-col items-end">
          <span className="font-display font-bold text-sm">
            {creature.fitnessScore}
          </span>
          <div className="w-16 h-1.5 bg-nb-bg border border-nb-ink/30 rounded-full overflow-hidden">
            <div
              className="h-full bg-nb-accent"
              style={{ width: `${Math.min(100, (creature.fitnessScore / 75) * 100)}%` }}
            />
          </div>
        </div>
        <ChevronRight size={14} className="text-nb-ink/30" />
      </div>
    </motion.button>
  );
}
