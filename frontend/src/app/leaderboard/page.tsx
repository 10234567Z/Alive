"use client";

import { motion } from "framer-motion";
import { Trophy, Filter } from "lucide-react";
import { useState } from "react";
import LeaderboardComponent from "@/components/Leaderboard";
import StatsBar from "@/components/StatsBar";
import { useEcosystemStore } from "@/stores/ecosystem";
import { useMounted } from "@/lib/use-mounted";

export default function LeaderboardPage() {
  const mounted = useMounted();
  const { creatures } = useEcosystemStore();
  const [filter, setFilter] = useState<"all" | "alive" | "dead">("all");

  const alive = creatures.filter((c) => c.isAlive).length;
  const dead = creatures.filter((c) => !c.isAlive).length;

  if (!mounted) return null;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-between"
      >
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-nb-warn border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center">
            <Trophy size={24} />
          </div>
          <div>
            <h1 className="font-display font-bold text-3xl">Leaderboard</h1>
            <p className="text-nb-ink/60">
              {alive} alive &middot; {dead} dead &middot; survival of the fittest
            </p>
          </div>
        </div>

        {/* Filter */}
        <div className="flex items-center gap-2">
          <Filter size={16} className="text-nb-ink/50" />
          {(["all", "alive", "dead"] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 text-xs font-mono font-semibold border-2 border-nb-ink rounded-nb transition-all capitalize ${
                filter === f
                  ? f === "dead"
                    ? "bg-nb-error text-white"
                    : "bg-nb-accent"
                  : "bg-nb-card hover:bg-nb-accent/20"
              }`}
            >
              {f} {f === "all" ? `(${creatures.length})` : f === "alive" ? `(${alive})` : `(${dead})`}
            </button>
          ))}
        </div>
      </motion.div>

      <StatsBar />

      {/* Leaderboard Table */}
      <LeaderboardComponent filter={filter} />
    </div>
  );
}
