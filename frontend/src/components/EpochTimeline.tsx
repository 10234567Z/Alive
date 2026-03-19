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
import { useRef, useEffect, useCallback } from "react";

export default function EpochTimeline() {
  const mounted = useMounted();
  const { epochs } = useEcosystemStore();
  const scrollRef = useRef<HTMLDivElement>(null);
  const isDragging = useRef(false);
  const dragStartX = useRef(0);
  const scrollStartX = useRef(0);

  // Auto-scroll to the latest epoch
  useEffect(() => {
    if (scrollRef.current && epochs.length > 0) {
      scrollRef.current.scrollLeft = scrollRef.current.scrollWidth;
    }
  }, [epochs.length]);

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    isDragging.current = true;
    dragStartX.current = e.clientX;
    scrollStartX.current = scrollRef.current?.scrollLeft ?? 0;
    e.preventDefault();
  }, []);

  const onMouseMove = useCallback((e: React.MouseEvent) => {
    if (!isDragging.current || !scrollRef.current) return;
    const dx = e.clientX - dragStartX.current;
    scrollRef.current.scrollLeft = scrollStartX.current - dx;
  }, []);

  const onMouseUp = useCallback(() => {
    isDragging.current = false;
  }, []);

  if (!mounted) return null;

  return (
    <div className="space-y-6">
      {/* Evolution Chart */}
      <div className="nb-card p-4 sm:p-6">
        <h3 className="font-display font-bold text-base sm:text-lg mb-3 sm:mb-4 flex items-center gap-2">
          <TrendingUp size={18} /> Fitness Evolution
        </h3>
        <div className="h-36 sm:h-48">
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
                domain={[0, 75]}
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
                formatter={(v) => [`${Number(v)}`, "Top Fitness"]}
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
        <div className="nb-card p-4 sm:p-6">
          <h3 className="font-display font-bold text-sm mb-2 sm:mb-3 flex items-center gap-2">
            <Users size={16} /> Population
          </h3>
          <div className="h-28 sm:h-36">
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
        <div className="nb-card p-4 sm:p-6">
          <h3 className="font-display font-bold text-sm mb-2 sm:mb-3 flex items-center gap-2">
            <GitBranch size={16} /> Births &amp; <Skull size={16} /> Deaths
          </h3>
          <div className="h-28 sm:h-36">
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
      <div
        ref={scrollRef}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
        className="overflow-x-auto pb-4 pt-3 cursor-grab active:cursor-grabbing relative z-10 scrollbar-hide"
        style={{ scrollbarWidth: "none", msOverflowStyle: "none" }}
      >
        <div className="flex gap-5 min-w-max select-none px-1">
          {epochs.map((ep, i) => (
            <motion.div
              key={ep.epoch}
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: i * 0.05 }}
              className="bg-nb-card border-3 border-nb-ink rounded-nb px-4 sm:px-5 py-3 sm:py-4 min-w-[140px] sm:min-w-[160px] shadow-nb-sm hover:-translate-y-1 hover:shadow-nb transition-all"
            >
              <p className="font-display font-bold text-xl mb-3">E{ep.epoch}</p>
              <div className="space-y-2 text-xs font-mono">
                <div>
                  <span className="text-nb-ok font-semibold">+{ep.births} born</span>
                </div>
                <div>
                  <span className="text-nb-error font-semibold">-{ep.deaths} died</span>
                </div>
                <hr className="border-nb-ink/15" />
                <div className="text-nb-ink/60">
                  <span>Pop: {ep.populationSize}</span>
                </div>
                <div className="text-nb-ink/60">
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
