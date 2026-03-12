"use client";

import { motion } from "framer-motion";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
  Cell,
} from "recharts";
import { useEcosystemStore } from "@/stores/ecosystem";
import { GitBranch, Skull, TrendingUp, Users } from "lucide-react";
import { useMounted } from "@/lib/use-mounted";

export default function EpochTimeline() {
  const mounted = useMounted();
  const { epochs } = useEcosystemStore();

  if (!mounted) return null;

  return (
    <div className="space-y-6">
      {/* Evolution Chart */}
      <div className="nb-card p-6">
        <h3 className="font-display font-bold text-lg mb-4 flex items-center gap-2">
          <TrendingUp size={20} /> Fitness Evolution
        </h3>
        <div className="h-48">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={epochs}>
              <defs>
                <linearGradient id="fitGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#6EE7B7" stopOpacity={0.4} />
                  <stop offset="95%" stopColor="#6EE7B7" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis
                dataKey="epoch"
                tick={{ fontFamily: "'JetBrains Mono'", fontSize: 12 }}
                tickFormatter={(v) => `E${v}`}
              />
              <YAxis
                tick={{ fontFamily: "'JetBrains Mono'", fontSize: 11 }}
                tickFormatter={(v) => `${(v / 1000).toFixed(0)}k`}
              />
              <Tooltip
                contentStyle={{
                  background: "#F7F5F2",
                  border: "3px solid #111",
                  borderRadius: "1.25rem",
                  fontFamily: "'JetBrains Mono'",
                  fontSize: 12,
                  boxShadow: "4px 4px 0 0 rgba(0,0,0,0.9)",
                }}
                formatter={(v) => [`${(Number(v) / 1000).toFixed(1)}k`, "Top Fitness"]}
                labelFormatter={(v) => `Epoch ${v}`}
              />
              <Area
                type="monotone"
                dataKey="topFitness"
                stroke="#111"
                strokeWidth={3}
                fill="url(#fitGrad)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Population + Births/Deaths */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Population Over Time */}
        <div className="nb-card p-6">
          <h3 className="font-display font-bold text-sm mb-3 flex items-center gap-2">
            <Users size={16} /> Population
          </h3>
          <div className="h-36">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={epochs}>
                <defs>
                  <linearGradient id="popGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#60A5FA" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#60A5FA" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis
                  dataKey="epoch"
                  tick={{ fontFamily: "'JetBrains Mono'", fontSize: 10 }}
                  tickFormatter={(v) => `E${v}`}
                />
                <YAxis
                  tick={{ fontFamily: "'JetBrains Mono'", fontSize: 10 }}
                  domain={[0, "auto"]}
                />
                <Tooltip
                  contentStyle={{
                    background: "#F7F5F2",
                    border: "2px solid #111",
                    borderRadius: "1rem",
                    fontFamily: "'JetBrains Mono'",
                    fontSize: 11,
                  }}
                  labelFormatter={(v) => `Epoch ${v}`}
                />
                <Area
                  type="monotone"
                  dataKey="populationSize"
                  stroke="#60A5FA"
                  strokeWidth={2}
                  fill="url(#popGrad)"
                  name="Population"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Births & Deaths Bar Chart */}
        <div className="nb-card p-6">
          <h3 className="font-display font-bold text-sm mb-3 flex items-center gap-2">
            <GitBranch size={16} /> Births &amp; <Skull size={16} /> Deaths
          </h3>
          <div className="h-36">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={epochs} barGap={2}>
                <XAxis
                  dataKey="epoch"
                  tick={{ fontFamily: "'JetBrains Mono'", fontSize: 10 }}
                  tickFormatter={(v) => `E${v}`}
                />
                <YAxis tick={{ fontFamily: "'JetBrains Mono'", fontSize: 10 }} />
                <Tooltip
                  contentStyle={{
                    background: "#F7F5F2",
                    border: "2px solid #111",
                    borderRadius: "1rem",
                    fontFamily: "'JetBrains Mono'",
                    fontSize: 11,
                  }}
                  labelFormatter={(v) => `Epoch ${v}`}
                />
                <Bar dataKey="births" name="Births" radius={[4, 4, 0, 0]}>
                  {epochs.map((_, i) => (
                    <Cell key={i} fill="#6EE7B7" stroke="#111" strokeWidth={2} />
                  ))}
                </Bar>
                <Bar dataKey="deaths" name="Deaths" radius={[4, 4, 0, 0]}>
                  {epochs.map((_, i) => (
                    <Cell key={i} fill="#EF4444" stroke="#111" strokeWidth={2} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Epoch Cards Strip */}
      <div className="overflow-x-auto pb-2">
        <div className="flex gap-3 min-w-max">
          {epochs.map((ep, i) => (
            <motion.div
              key={ep.epoch}
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: i * 0.05 }}
              className="bg-nb-card border-3 border-nb-ink rounded-nb p-4 min-w-[140px] shadow-nb-sm hover:-translate-y-1 hover:shadow-nb transition-all"
            >
              <p className="font-display font-bold text-lg">E{ep.epoch}</p>
              <div className="mt-2 space-y-1 text-xs font-mono">
                <div className="flex justify-between">
                  <span className="text-nb-ok">+{ep.births} born</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-nb-error">-{ep.deaths} died</span>
                </div>
                <div className="flex justify-between text-nb-ink/60">
                  <span>Pop: {ep.populationSize}</span>
                </div>
                <div className="flex justify-between text-nb-ink/60">
                  <span>Yield: {ep.avgYield}%</span>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  );
}
