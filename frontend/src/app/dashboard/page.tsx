"use client";

import { motion } from "framer-motion";
import { LayoutDashboard, PieChart, Activity, TrendingUp } from "lucide-react";
import DepositPanel from "@/components/DepositPanel";
import EpochControls from "@/components/EpochControls";
import StatsBar from "@/components/StatsBar";
import { useEcosystemStore } from "@/stores/ecosystem";
import { POOL_TYPE_NAMES, POOL_TYPE_COLORS } from "@/lib/types";
import { useMounted } from "@/lib/use-mounted";

export default function DashboardPage() {
  const mounted = useMounted();
  const { creatures, ecosystem } = useEcosystemStore();
  const alive = creatures.filter((c) => c.isAlive);

  if (!mounted) return null;

  // Pool distribution
  const poolDist = alive.reduce<Record<number, number>>((acc, c) => {
    acc[c.dna.poolType] = (acc[c.dna.poolType] || 0) + 1;
    return acc;
  }, {});

  // Top performers
  const top5 = [...alive].sort((a, b) => b.fitnessScore - a.fitnessScore).slice(0, 5);

  // Avg stats
  const avgFitness =
    alive.length > 0
      ? alive.reduce((s, c) => s + c.fitnessScore, 0) / alive.length
      : 0;
  const avgEpochs =
    alive.length > 0
      ? alive.reduce((s, c) => s + c.performance.epochsSurvived, 0) / alive.length
      : 0;
  const totalBalance = alive.reduce((s, c) => s + c.balance, 0);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center gap-3"
      >
        <div className="w-12 h-12 bg-nb-accent-2 border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center">
          <LayoutDashboard size={24} />
        </div>
        <div>
          <h1 className="font-display font-bold text-3xl">Dashboard</h1>
          <p className="text-nb-ink/60">Your position &amp; ecosystem analytics</p>
        </div>
      </motion.div>

      <StatsBar />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left — Deposit Panel + Epoch Controls */}
        <div className="lg:col-span-1 space-y-6">
          <DepositPanel />
          <EpochControls />
        </div>

        {/* Right — Analytics */}
        <div className="lg:col-span-2 space-y-6">
          {/* Overview Cards */}
          <div className="grid grid-cols-3 gap-4">
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.1 }}
              className="nb-card p-5"
            >
              <div className="flex items-center gap-2 mb-2">
                <Activity size={16} className="text-nb-accent" />
                <p className="text-xs font-mono text-nb-ink/50 uppercase">Avg Fitness</p>
              </div>
              <p className="font-display font-bold text-2xl">
                {avgFitness.toFixed(0)}
              </p>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.15 }}
              className="nb-card p-5"
            >
              <div className="flex items-center gap-2 mb-2">
                <TrendingUp size={16} className="text-nb-ok" />
                <p className="text-xs font-mono text-nb-ink/50 uppercase">Avg Lifespan</p>
              </div>
              <p className="font-display font-bold text-2xl">
                {avgEpochs.toFixed(1)} <span className="text-sm font-normal text-nb-ink/50">epochs</span>
              </p>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.2 }}
              className="nb-card p-5"
            >
              <div className="flex items-center gap-2 mb-2">
                <PieChart size={16} className="text-nb-purple" />
                <p className="text-xs font-mono text-nb-ink/50 uppercase">TVL Active</p>
              </div>
              <p className="font-display font-bold text-2xl">
                ${(totalBalance / 1e6).toLocaleString("en-US", { maximumFractionDigits: 0 })}
              </p>
            </motion.div>
          </div>

          {/* Strategy Distribution */}
          <div className="nb-card p-6">
            <h3 className="font-display font-bold text-lg mb-4">Strategy Distribution</h3>
            <div className="space-y-3">
              {Object.entries(poolDist)
                .sort(([, a], [, b]) => b - a)
                .map(([poolType, count]) => {
                  const pct = (count / alive.length) * 100;
                  const pt = parseInt(poolType);
                  return (
                    <div key={poolType} className="space-y-1">
                      <div className="flex justify-between text-sm">
                        <span className="font-display font-medium flex items-center gap-2">
                          <span
                            className="w-3 h-3 rounded-full border-2 border-nb-ink"
                            style={{ backgroundColor: POOL_TYPE_COLORS[pt] }}
                          />
                          {POOL_TYPE_NAMES[pt]}
                        </span>
                        <span className="font-mono text-nb-ink/60">
                          {count} ({pct.toFixed(0)}%)
                        </span>
                      </div>
                      <div className="w-full h-3 bg-nb-bg border-2 border-nb-ink rounded-full overflow-hidden">
                        <motion.div
                          initial={{ width: 0 }}
                          animate={{ width: `${pct}%` }}
                          transition={{ delay: 0.3, duration: 0.6 }}
                          className="h-full rounded-full"
                          style={{ backgroundColor: POOL_TYPE_COLORS[pt] }}
                        />
                      </div>
                    </div>
                  );
                })}
            </div>
          </div>

          {/* Top 5 Performers */}
          <div className="nb-card p-6">
            <h3 className="font-display font-bold text-lg mb-4">Top Performers</h3>
            <div className="space-y-2">
              {top5.map((c, i) => (
                <div
                  key={c.address}
                  className="flex items-center justify-between bg-nb-bg border-2 border-nb-ink/30 rounded-nb px-4 py-3"
                >
                  <div className="flex items-center gap-3">
                    <span
                      className="w-8 h-8 border-2 border-nb-ink rounded-lg flex items-center justify-center font-display font-bold text-sm"
                      style={{ backgroundColor: POOL_TYPE_COLORS[c.dna.poolType] }}
                    >
                      {i + 1}
                    </span>
                    <div>
                      <p className="font-mono text-sm font-medium">
                        #{c.address.slice(2, 8)}
                      </p>
                      <p className="text-xs text-nb-ink/50">
                        Gen {c.generation} &middot; {POOL_TYPE_NAMES[c.dna.poolType]}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-display font-bold">
                      {c.fitnessScore}
                    </p>
                    <p
                      className={`text-xs font-mono ${
                        c.performance.cumulativeReturn >= 0 ? "text-nb-ok" : "text-nb-error"
                      }`}
                    >
                      {c.performance.cumulativeReturn >= 0 ? "+" : "-"}${(Math.abs(c.performance.cumulativeReturn) / 1e6).toFixed(0)}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
