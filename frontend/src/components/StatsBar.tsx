"use client";

import { motion } from "framer-motion";
import { Users, Layers, Zap, TrendingUp, Clock, Loader2 } from "lucide-react";
import { useEcosystemStore } from "@/stores/ecosystem";
import { Phase } from "@/lib/types";
import { useMounted } from "@/lib/use-mounted";

const PHASE_LABELS: Record<Phase, { label: string; color: string }> = {
  [Phase.IDLE]: { label: "IDLE", color: "bg-nb-card" },
  [Phase.FEEDING]: { label: "FEEDING", color: "bg-nb-accent" },
  [Phase.HARVESTING]: { label: "HARVESTING", color: "bg-nb-warn" },
  [Phase.EVOLVING]: { label: "EVOLVING", color: "bg-nb-purple" },
  [Phase.ALLOCATING]: { label: "ALLOCATING", color: "bg-nb-accent-2" },
};

export default function StatsBar() {
  const mounted = useMounted();
  const { ecosystem, creatures, isLoading } = useEcosystemStore();

  const alive = creatures.filter((c) => c.isAlive).length;
  const phase = PHASE_LABELS[ecosystem.phase];

  if (!mounted) return null;

  const stats = [
    {
      icon: Layers,
      label: "Total Deposits",
      value: `$${(ecosystem.totalDeposits / 1e6).toLocaleString("en-US", { maximumFractionDigits: 0 })}`,
    },
    {
      icon: Users,
      label: "Creatures",
      value: alive > 0 ? `${alive} alive` : `${ecosystem.creatureCount} total`,
    },
    {
      icon: Clock,
      label: "Epoch",
      value: `#${ecosystem.currentEpoch}`,
    },
    {
      icon: TrendingUp,
      label: "Yield Generated",
      value: `$${(ecosystem.yieldGenerated / 1e6).toLocaleString("en-US", { maximumFractionDigits: 0 })}`,
    },
    {
      icon: Zap,
      label: "Phase",
      value: phase.label,
      badge: true,
      badgeColor: phase.color,
    },
  ];

  return (
    <div className="w-full overflow-x-auto">
      <div className="flex items-stretch gap-3 min-w-max px-1 py-1">
        {stats.map((stat, i) => (
          <motion.div
            key={stat.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.08 }}
            className="flex items-center gap-3 bg-nb-card border-3 border-nb-ink rounded-nb px-4 py-3 shadow-nb-sm hover:-translate-y-0.5 hover:shadow-nb transition-all"
          >
            <div className="w-9 h-9 bg-nb-bg border-2 border-nb-ink rounded-lg flex items-center justify-center">
              {isLoading ? (
                <Loader2 size={18} className="animate-spin text-nb-ink/30" />
              ) : (
                <stat.icon size={18} />
              )}
            </div>
            <div>
              <p className="text-xs font-mono text-nb-ink/50 uppercase whitespace-nowrap">
                {stat.label}
              </p>
              {stat.badge ? (
                <span className={`nb-badge ${stat.badgeColor} mt-0.5`}>{stat.value}</span>
              ) : (
                <p className="font-display font-bold text-lg whitespace-nowrap">{stat.value}</p>
              )}
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
