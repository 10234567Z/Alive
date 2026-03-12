"use client";

import { motion } from "framer-motion";
import { Dna, Sparkles, ChevronDown, Zap, Shield, GitBranch } from "lucide-react";
import EcosystemCanvas from "@/components/EcosystemCanvas";
import StatsBar from "@/components/StatsBar";
import EpochTimeline from "@/components/EpochTimeline";
import { useMounted } from "@/lib/use-mounted";

export default function Home() {
  const mounted = useMounted();
  if (!mounted) return null;

  return (
    <div className="space-y-8 pb-12">
      {/* Hero Section */}
      <section className="relative overflow-hidden">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-12 pb-8">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="text-center space-y-4 mb-8"
          >
            <motion.div
              initial={{ scale: 0.8, rotate: -5 }}
              animate={{ scale: 1, rotate: 0 }}
              transition={{ type: "spring", damping: 10, stiffness: 100 }}
              className="inline-flex items-center gap-2 nb-badge bg-nb-accent text-lg px-4 py-2"
            >
              <Sparkles size={18} /> Artificial Life Ecosystem
            </motion.div>

            <h1 className="font-display font-bold text-5xl sm:text-7xl tracking-tight">
              <span className="inline-block bg-nb-accent border-3 border-nb-ink rounded-nb px-3 py-1 shadow-nb-sm -rotate-1">
                ALIVE
              </span>
            </h1>

            <p className="text-xl text-nb-ink/70 max-w-2xl mx-auto font-body">
              Autonomous DeFi creatures evolve optimal yield strategies through
              natural selection on <span className="font-semibold text-nb-purple">Polkadot Hub</span>.
              Deposit. Watch them compete. Earn yield from the fittest.
            </p>

            {/* Feature pills */}
            <div className="flex flex-wrap justify-center gap-3 pt-4">
              {[
                { icon: Dna, label: "Genetic Algorithms", color: "bg-nb-accent/30" },
                { icon: Zap, label: "PolkaVM Evolution", color: "bg-nb-purple/20" },
                { icon: Shield, label: "XCM Cross-Chain", color: "bg-nb-accent-2/20" },
                { icon: GitBranch, label: "On-Chain Breeding", color: "bg-nb-pink/20" },
              ].map(({ icon: Icon, label, color }) => (
                <span key={label} className={`nb-badge ${color} text-sm`}>
                  <Icon size={14} /> {label}
                </span>
              ))}
            </div>
          </motion.div>

          {/* Scroll hint */}
          <motion.div
            animate={{ y: [0, 8, 0] }}
            transition={{ repeat: Infinity, duration: 2 }}
            className="flex justify-center text-nb-ink/30"
          >
            <ChevronDown size={24} />
          </motion.div>
        </div>
      </section>

      {/* Stats Bar */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <StatsBar />
      </section>

      {/* Live Ecosystem Canvas */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="nb-card p-2 sm:p-4">
          <div className="flex items-center justify-between mb-4 px-2">
            <h2 className="font-display font-bold text-xl flex items-center gap-2">
              <Dna size={22} /> Live Ecosystem
            </h2>
            <span className="nb-badge bg-nb-ok/20 text-nb-ok">
              <span className="w-2 h-2 bg-nb-ok rounded-full animate-pulse" />
              Real-time
            </span>
          </div>
          <EcosystemCanvas />
          <p className="text-xs text-center text-nb-ink/40 font-mono mt-3">
            Click any creature to inspect its DNA and performance
          </p>
        </div>
      </section>

      {/* Epoch Timeline */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <h2 className="font-display font-bold text-2xl mb-4">Evolution History</h2>
        <EpochTimeline />
      </section>

      {/* How it Works */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <h2 className="font-display font-bold text-2xl mb-6 text-center">How ALIVE Works</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {[
            {
              step: "01",
              title: "Deposit",
              desc: "Users deposit USDC into the ecosystem vault. Capital becomes food for creatures.",
              color: "bg-nb-accent",
            },
            {
              step: "02",
              title: "Feed & Harvest",
              desc: "Creatures deploy capital across Polkadot parachains via XCM to chase yield.",
              color: "bg-nb-accent-2",
            },
            {
              step: "03",
              title: "Evolve",
              desc: "PolkaVM runs genetic algorithms. Fit creatures breed. Weak ones die. DNA mutates.",
              color: "bg-nb-purple",
            },
            {
              step: "04",
              title: "Allocate",
              desc: "The fittest survivors get more capital. Better strategies earn more yield for depositors.",
              color: "bg-nb-pink",
            },
          ].map(({ step, title, desc, color }, i) => (
            <motion.div
              key={step}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
              className="nb-card p-5"
            >
              <div
                className={`w-12 h-12 ${color} border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center font-display font-bold text-xl mb-3`}
              >
                {step}
              </div>
              <h3 className="font-display font-bold text-lg mb-1">{title}</h3>
              <p className="text-sm text-nb-ink/60">{desc}</p>
            </motion.div>
          ))}
        </div>
      </section>
    </div>
  );
}
