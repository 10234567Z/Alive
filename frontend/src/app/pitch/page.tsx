"use client";

import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Dna, Sparkles, Zap, Shield, GitBranch, ChevronRight, ChevronLeft,
  TrendingUp, Brain, Globe, Users, Coins, BarChart3, Cpu,
  ArrowRight, ExternalLink, Skull, Heart, Swords, Target,
} from "lucide-react";
import Link from "next/link";

// ── Slide data ─────────────────────────────────────────────────────

const SLIDES = [
  { id: "title", bg: "bg-nb-accent" },
  { id: "problem", bg: "bg-nb-error/20" },
  { id: "solution", bg: "bg-nb-accent/20" },
  { id: "how", bg: "bg-nb-purple/20" },
  { id: "lifecycle", bg: "bg-nb-accent-2/20" },
  { id: "architecture", bg: "bg-nb-pink/20" },
  { id: "tech", bg: "bg-nb-accent/20" },
  { id: "demo", bg: "bg-nb-ok/20" },
  { id: "market", bg: "bg-nb-accent-2/20" },
  { id: "team", bg: "bg-nb-purple/20" },
  { id: "cta", bg: "bg-nb-accent" },
];

const fadeSlide = {
  initial: { opacity: 0, x: 80 },
  animate: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: -80 },
  transition: { duration: 0.4, ease: "easeInOut" as const },
};

// ── Main component ─────────────────────────────────────────────────

export default function PitchDeck() {
  const [slide, setSlide] = useState(0);
  const total = SLIDES.length;

  const next = useCallback(() => setSlide((s) => Math.min(s + 1, total - 1)), [total]);
  const prev = useCallback(() => setSlide((s) => Math.max(s - 1, 0)), []);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "ArrowRight" || e.key === " ") { e.preventDefault(); next(); }
      if (e.key === "ArrowLeft") { e.preventDefault(); prev(); }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [next, prev]);

  return (
    <div className="fixed inset-0 bg-nb-bg flex flex-col overflow-hidden z-50">
      {/* Progress bar */}
      <div className="h-1.5 bg-nb-ink/10 w-full">
        <motion.div
          className="h-full bg-nb-ink"
          animate={{ width: `${((slide + 1) / total) * 100}%` }}
          transition={{ duration: 0.3 }}
        />
      </div>

      {/* Slide content */}
      <div className="flex-1 relative overflow-hidden">
        <AnimatePresence mode="wait">
          <motion.div key={slide} {...fadeSlide} className="absolute inset-0 flex items-center justify-center p-8">
            {slide === 0 && <TitleSlide />}
            {slide === 1 && <ProblemSlide />}
            {slide === 2 && <SolutionSlide />}
            {slide === 3 && <HowSlide />}
            {slide === 4 && <LifecycleSlide />}
            {slide === 5 && <ArchitectureSlide />}
            {slide === 6 && <TechSlide />}
            {slide === 7 && <DemoSlide />}
            {slide === 8 && <MarketSlide />}
            {slide === 9 && <TeamSlide />}
            {slide === 10 && <CTASlide />}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Navigation */}
      <div className="flex items-center justify-between px-8 py-4 border-t-3 border-nb-ink bg-nb-card">
        <button onClick={prev} disabled={slide === 0} className="nb-btn nb-btn-secondary disabled:opacity-30 disabled:cursor-not-allowed">
          <ChevronLeft size={20} /> Back
        </button>
        <div className="flex gap-2">
          {SLIDES.map((_, i) => (
            <button
              key={i}
              onClick={() => setSlide(i)}
              className={`w-3 h-3 rounded-full border-2 border-nb-ink transition-all ${
                i === slide ? "bg-nb-ink scale-125" : "bg-nb-bg hover:bg-nb-ink/30"
              }`}
            />
          ))}
        </div>
        <button onClick={next} disabled={slide === total - 1} className="nb-btn nb-btn-primary disabled:opacity-30 disabled:cursor-not-allowed">
          Next <ChevronRight size={20} />
        </button>
      </div>
    </div>
  );
}

// ── Individual slides ──────────────────────────────────────────────

function SlideBox({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <div className={`max-w-5xl w-full mx-auto ${className}`}>{children}</div>;
}

function TitleSlide() {
  return (
    <SlideBox className="text-center space-y-8">
      <motion.div
        animate={{ rotate: [0, 5, -5, 0] }}
        transition={{ repeat: Infinity, duration: 4, ease: "easeInOut" }}
        className="inline-block"
      >
        <div className="inline-flex items-center gap-3 nb-badge bg-nb-accent text-lg px-5 py-2 mb-4">
          <Sparkles size={22} /> Polkadot Solidity Hackathon 2026
        </div>
      </motion.div>

      <h1 className="font-display font-bold text-7xl sm:text-9xl tracking-tight">
        <span className="inline-block bg-nb-accent border-3 border-nb-ink rounded-nb px-6 py-3 shadow-nb -rotate-1">
          ALIVE
        </span>
      </h1>

      <p className="text-2xl sm:text-3xl text-nb-ink/70 font-display max-w-3xl mx-auto">
        Autonomous DeFi creatures that{" "}
        <span className="bg-nb-purple/20 px-2 rounded-lg font-bold text-nb-purple">evolve</span>{" "}
        yield strategies through{" "}
        <span className="bg-nb-accent/40 px-2 rounded-lg font-bold">natural selection</span>
      </p>

      <div className="flex flex-wrap justify-center gap-4 pt-4">
        {[
          { icon: Dna, label: "Genetic Algorithms", color: "bg-nb-accent/30" },
          { icon: Cpu, label: "PolkaVM Evolution", color: "bg-nb-purple/20" },
          { icon: Globe, label: "XCM Cross-Chain", color: "bg-nb-accent-2/20" },
          { icon: GitBranch, label: "On-Chain Breeding", color: "bg-nb-pink/20" },
        ].map(({ icon: Icon, label, color }) => (
          <motion.span
            key={label}
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.3, type: "spring" }}
            className={`nb-badge ${color} text-base px-4 py-1.5`}
          >
            <Icon size={16} /> {label}
          </motion.span>
        ))}
      </div>

      <p className="text-sm text-nb-ink/40 font-mono">Track 1: EVM Smart Contract Track</p>
    </SlideBox>
  );
}

function ProblemSlide() {
  const problems = [
    { icon: TrendingUp, text: "DeFi users manually chase yield across chains — it's exhausting", color: "bg-nb-error/20" },
    { icon: Brain, text: "Most yield strategies are static. Markets change, strategies don't", color: "bg-nb-warn/20" },
    { icon: Users, text: "Only whales with bots can efficiently optimize cross-chain yield", color: "bg-nb-pink/20" },
    { icon: Shield, text: "No adaptive system exists that evolves strategies based on real performance", color: "bg-nb-purple/20" },
  ];

  return (
    <SlideBox className="space-y-8">
      <div className="text-center">
        <span className="nb-badge bg-nb-error/20 text-nb-error text-lg px-4 py-1.5 mb-4 inline-flex">
          <Skull size={18} /> The Problem
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">DeFi Yield is Broken</h2>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {problems.map(({ icon: Icon, text, color }, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.15 }}
            className="nb-card p-6 flex items-start gap-4"
          >
            <div className={`p-3 ${color} border-2 border-nb-ink rounded-nb shrink-0`}>
              <Icon size={24} />
            </div>
            <p className="text-lg">{text}</p>
          </motion.div>
        ))}
      </div>
    </SlideBox>
  );
}

function SolutionSlide() {
  return (
    <SlideBox className="space-y-8">
      <div className="text-center">
        <span className="nb-badge bg-nb-ok/20 text-nb-ok text-lg px-4 py-1.5 mb-4 inline-flex">
          <Sparkles size={18} /> The Solution
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">
          Let <span className="bg-nb-accent px-3 rounded-lg">Evolution</span> Do the Work
        </h2>
      </div>

      <div className="nb-card p-8 text-center space-y-6">
        <p className="text-xl text-nb-ink/80 max-w-3xl mx-auto leading-relaxed">
          ALIVE deploys <span className="font-bold text-nb-purple">autonomous creatures</span> — each with unique DNA
          encoding a yield strategy. They compete for capital across Polkadot parachains.
          <span className="font-bold text-nb-ok"> The fittest survive and breed.</span>{" "}
          The weak die. Strategies evolve every epoch automatically.
        </p>

        <div className="flex justify-center gap-6 pt-4">
          <div className="text-center">
            <div className="text-4xl font-display font-bold text-nb-purple">10+</div>
            <div className="text-sm text-nb-ink/60">DNA Genes</div>
          </div>
          <div className="w-px bg-nb-ink/20" />
          <div className="text-center">
            <div className="text-4xl font-display font-bold text-nb-accent-2">6</div>
            <div className="text-sm text-nb-ink/60">Parachains</div>
          </div>
          <div className="w-px bg-nb-ink/20" />
          <div className="text-center">
            <div className="text-4xl font-display font-bold text-nb-ok">100%</div>
            <div className="text-sm text-nb-ink/60">On-Chain</div>
          </div>
          <div className="w-px bg-nb-ink/20" />
          <div className="text-center">
            <div className="text-4xl font-display font-bold text-nb-pink">0</div>
            <div className="text-sm text-nb-ink/60">Human Input</div>
          </div>
        </div>
      </div>
    </SlideBox>
  );
}

function HowSlide() {
  return (
    <SlideBox className="space-y-8">
      <div className="text-center">
        <span className="nb-badge bg-nb-purple/20 text-nb-purple text-lg px-4 py-1.5 mb-4 inline-flex">
          <Dna size={18} /> How It Works
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">The Creature DNA</h2>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        {[
          { gene: "targetChain", desc: "Which parachain", example: "Moonbeam", color: "bg-nb-accent" },
          { gene: "poolType", desc: "Strategy type", example: "AMM LP", color: "bg-nb-accent-2" },
          { gene: "allocation", desc: "Capital ratio", example: "70%", color: "bg-nb-purple" },
          { gene: "riskCeiling", desc: "Max risk level", example: "3/10", color: "bg-nb-error/60" },
          { gene: "yieldFloor", desc: "Min yield target", example: "5%", color: "bg-nb-ok" },
          { gene: "maxSlippage", desc: "Slippage tolerance", example: "0.8%", color: "bg-nb-warn" },
          { gene: "entryTiming", desc: "When to enter", example: "Aggressive", color: "bg-nb-pink" },
          { gene: "exitTiming", desc: "When to exit", example: "Conservative", color: "bg-nb-accent-2" },
          { gene: "hedgeRatio", desc: "Hedge amount", example: "20%", color: "bg-nb-purple" },
          { gene: "rebalance", desc: "Rebalance trigger", example: "15%", color: "bg-nb-accent" },
        ].map(({ gene, desc, example, color }, i) => (
          <motion.div
            key={gene}
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: i * 0.06 }}
            className={`${color} border-3 border-nb-ink rounded-nb p-3 shadow-nb-sm text-center`}
          >
            <div className="font-mono text-xs font-bold">{gene}</div>
            <div className="text-[11px] text-nb-ink/60 mt-0.5">{desc}</div>
            <div className="font-display font-bold text-sm mt-1">{example}</div>
          </motion.div>
        ))}
      </div>

      <p className="text-center text-nb-ink/60 text-lg">
        Each creature is a <span className="font-bold">unique combination</span> of these 10 genes.
        Crossover + mutation create new strategies every epoch.
      </p>
    </SlideBox>
  );
}

function LifecycleSlide() {
  const phases = [
    { step: "01", title: "DEPOSIT", desc: "Users deposit USDC into the ecosystem vault", icon: Coins, color: "bg-nb-accent" },
    { step: "02", title: "FEED", desc: "Creatures deploy capital to parachains via XCM", icon: Globe, color: "bg-nb-accent-2" },
    { step: "03", title: "HARVEST", desc: "XCM returns yield from DeFi protocols", icon: TrendingUp, color: "bg-nb-ok" },
    { step: "04", title: "EVOLVE", desc: "Fit creatures breed, weak ones die, DNA mutates", icon: Dna, color: "bg-nb-purple" },
    { step: "05", title: "ALLOCATE", desc: "Fittest survivors get more capital next epoch", icon: BarChart3, color: "bg-nb-pink" },
  ];

  return (
    <SlideBox className="space-y-8">
      <div className="text-center">
        <span className="nb-badge bg-nb-accent-2/20 text-nb-accent-2 text-lg px-4 py-1.5 mb-4 inline-flex">
          <Zap size={18} /> Epoch Lifecycle
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">Every ~10 Minutes</h2>
      </div>

      <div className="flex flex-col md:flex-row gap-3 items-stretch">
        {phases.map(({ step, title, desc, icon: Icon, color }, i) => (
          <motion.div
            key={step}
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.12 }}
            className="flex-1 nb-card p-5 flex flex-col items-center text-center gap-2"
          >
            <div className={`w-14 h-14 ${color} border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center`}>
              <Icon size={24} />
            </div>
            <div className="font-mono text-xs text-nb-ink/40">{step}</div>
            <div className="font-display font-bold text-lg">{title}</div>
            <p className="text-sm text-nb-ink/60">{desc}</p>
            {i < phases.length - 1 && (
              <ArrowRight size={16} className="text-nb-ink/30 hidden md:block absolute -right-5 top-1/2" />
            )}
          </motion.div>
        ))}
      </div>

      <div className="nb-badge bg-nb-warn/20 text-nb-warn mx-auto text-base px-4 py-1.5">
        <Zap size={16} /> Fully autonomous — no human intervention needed
      </div>
    </SlideBox>
  );
}

function ArchitectureSlide() {
  const contracts = [
    { name: "Ecosystem.sol", desc: "Vault + epoch orchestrator", lines: "650+", color: "bg-nb-accent" },
    { name: "Creature.sol", desc: "Autonomous agent with DNA", lines: "200+", color: "bg-nb-accent-2" },
    { name: "GenePool.sol", desc: "Breeding + seed injection", lines: "150+", color: "bg-nb-purple" },
    { name: "EvolutionEngine.sol", desc: "Crossover, mutation, selection", lines: "250+", color: "bg-nb-pink" },
    { name: "XCMRouter.sol", desc: "Cross-chain asset routing", lines: "300+", color: "bg-nb-ok" },
    { name: "CreatureFactory.sol", desc: "Deterministic creature deployment", lines: "100+", color: "bg-nb-warn" },
  ];

  return (
    <SlideBox className="space-y-8">
      <div className="text-center">
        <span className="nb-badge bg-nb-pink/20 text-nb-pink text-lg px-4 py-1.5 mb-4 inline-flex">
          <Shield size={18} /> Architecture
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">6 Smart Contracts</h2>
        <p className="text-lg text-nb-ink/60 mt-2">All deployed on Polkadot Hub TestNet (Chain 420420417)</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        {contracts.map(({ name, desc, lines, color }, i) => (
          <motion.div
            key={name}
            initial={{ opacity: 0, rotateY: 90 }}
            animate={{ opacity: 1, rotateY: 0 }}
            transition={{ delay: i * 0.1 }}
            className="nb-card p-5"
          >
            <div className={`inline-block ${color} border-2 border-nb-ink rounded-nb px-2 py-0.5 font-mono text-xs mb-2`}>
              {lines} lines
            </div>
            <h3 className="font-display font-bold">{name}</h3>
            <p className="text-sm text-nb-ink/60">{desc}</p>
          </motion.div>
        ))}
      </div>
    </SlideBox>
  );
}

function TechSlide() {
  const stack = [
    { layer: "Smart Contracts", items: ["Solidity 0.8.24", "Foundry", "73 Tests"], color: "bg-nb-accent" },
    { layer: "Evolution Engine", items: ["PolkaVM/Rust", "Genetic Algorithms", "17 Tests"], color: "bg-nb-purple" },
    { layer: "AI Seeder", items: ["Python", "Gemini 3.1 Pro", "LangChain"], color: "bg-nb-accent-2" },
    { layer: "Frontend", items: ["Next.js 15", "Framer Motion", "Neo-Brutalist"], color: "bg-nb-pink" },
    { layer: "Infrastructure", items: ["XCM Routing", "6 Parachains", "Render Deploy"], color: "bg-nb-ok" },
  ];

  const parachains = [
    { name: "Asset Hub", id: 0 },
    { name: "Moonbeam", id: 1 },
    { name: "Acala", id: 2 },
    { name: "Astar", id: 3 },
    { name: "HydraDX", id: 4 },
    { name: "Bifrost", id: 5 },
  ];

  return (
    <SlideBox className="space-y-8">
      <div className="text-center">
        <span className="nb-badge bg-nb-accent/30 text-lg px-4 py-1.5 mb-4 inline-flex">
          <Cpu size={18} /> Tech Stack
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">Built Different</h2>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
        {stack.map(({ layer, items, color }, i) => (
          <motion.div
            key={layer}
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.1 }}
            className="nb-card p-4 text-center"
          >
            <div className={`${color} border-2 border-nb-ink rounded-nb py-1 px-2 font-display font-bold text-sm mb-3`}>
              {layer}
            </div>
            {items.map((item) => (
              <div key={item} className="text-sm text-nb-ink/70 py-0.5">{item}</div>
            ))}
          </motion.div>
        ))}
      </div>

      <div className="nb-card p-4">
        <h3 className="font-display font-bold text-center mb-3">Target Parachains</h3>
        <div className="flex flex-wrap justify-center gap-3">
          {parachains.map(({ name, id }, i) => (
            <motion.span
              key={name}
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: 0.5 + i * 0.08, type: "spring" }}
              className="nb-badge bg-nb-accent-2/20 text-base px-3 py-1"
            >
              <Globe size={14} /> {name}
            </motion.span>
          ))}
        </div>
      </div>
    </SlideBox>
  );
}

function DemoSlide() {
  return (
    <SlideBox className="space-y-8 text-center">
      <div>
        <span className="nb-badge bg-nb-ok/20 text-nb-ok text-lg px-4 py-1.5 mb-4 inline-flex">
          <Zap size={18} /> Live Demo
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">See It Live</h2>
      </div>

      <div className="nb-card p-8 space-y-6">
        <p className="text-xl text-nb-ink/70">
          ALIVE is running <span className="font-bold text-nb-ok">right now</span> on Polkadot Hub TestNet.
          Creatures are competing. Evolution is happening. Yield is being generated.
        </p>

        <div className="grid grid-cols-3 gap-4">
          <div className="nb-card p-4 shadow-nb-sm!">
            <div className="font-mono text-xs text-nb-ink/40">DEPOSITED</div>
            <div className="font-display font-bold text-2xl text-nb-ok">100K+ USDC</div>
          </div>
          <div className="nb-card p-4 shadow-nb-sm!">
            <div className="font-mono text-xs text-nb-ink/40">CREATURES</div>
            <div className="font-display font-bold text-2xl text-nb-purple">10+</div>
          </div>
          <div className="nb-card p-4 shadow-nb-sm!">
            <div className="font-mono text-xs text-nb-ink/40">EPOCHS</div>
            <div className="font-display font-bold text-2xl text-nb-accent-2">Auto-advancing</div>
          </div>
        </div>

        <div className="flex justify-center gap-4">
          <Link href="/" className="nb-btn nb-btn-primary text-lg">
            <Dna size={20} /> Open Dashboard <ExternalLink size={16} />
          </Link>
          <a
            href="https://blockscout-testnet.polkadot.io/address/0xdf422894281A27Aa3d19B0B7D578c59Cb051ABF8"
            target="_blank"
            rel="noopener noreferrer"
            className="nb-btn nb-btn-secondary text-lg"
          >
            <Shield size={20} /> View on Explorer <ExternalLink size={16} />
          </a>
        </div>
      </div>
    </SlideBox>
  );
}

function MarketSlide() {
  return (
    <SlideBox className="space-y-8">
      <div className="text-center">
        <span className="nb-badge bg-nb-accent-2/20 text-nb-accent-2 text-lg px-4 py-1.5 mb-4 inline-flex">
          <TrendingUp size={18} /> Why Now
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">The Opportunity</h2>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="nb-card p-6 space-y-3">
          <div className="w-12 h-12 bg-nb-accent border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center">
            <Globe size={24} />
          </div>
          <h3 className="font-display font-bold text-xl">Polkadot XCM is Live</h3>
          <p className="text-nb-ink/60">Cross-chain messaging enables real multi-chain DeFi strategies for the first time on Polkadot.</p>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="nb-card p-6 space-y-3">
          <div className="w-12 h-12 bg-nb-purple border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center">
            <Brain size={24} />
          </div>
          <h3 className="font-display font-bold text-xl">AI Meets DeFi</h3>
          <p className="text-nb-ink/60">Gemini 3.1 Pro generates new creature DNA based on real market conditions. Biology meets alpha.</p>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="nb-card p-6 space-y-3">
          <div className="w-12 h-12 bg-nb-pink border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center">
            <Swords size={24} />
          </div>
          <h3 className="font-display font-bold text-xl">Autonomous Agents</h3>
          <p className="text-nb-ink/60">Self-sustaining ecosystem with keeper bots + AI seeder. Zero maintenance after deployment.</p>
        </motion.div>
      </div>

      <div className="nb-card p-6 text-center">
        <div className="font-display font-bold text-2xl mb-2">$180B+</div>
        <div className="text-nb-ink/60">Total DeFi TVL that could benefit from autonomous yield optimization</div>
      </div>
    </SlideBox>
  );
}

function TeamSlide() {
  return (
    <SlideBox className="space-y-8 text-center">
      <div>
        <span className="nb-badge bg-nb-purple/20 text-nb-purple text-lg px-4 py-1.5 mb-4 inline-flex">
          <Users size={18} /> The Builder
        </span>
        <h2 className="font-display font-bold text-5xl mt-4">Solo Hacker</h2>
      </div>

      <div className="nb-card p-8 max-w-lg mx-auto space-y-4">
        <div className="w-24 h-24 mx-auto bg-nb-accent border-3 border-nb-ink rounded-nb shadow-nb flex items-center justify-center text-4xl font-display font-bold">
          H
        </div>
        <h3 className="font-display font-bold text-2xl">Harsh</h3>
        <p className="text-nb-ink/60">
          Full-stack builder. Solidity, Rust, Python, Next.js — the entire ALIVE protocol
          built solo in one hackathon sprint.
        </p>
        <div className="flex flex-wrap justify-center gap-2">
          {["Solidity", "Rust", "Python", "Next.js", "Foundry", "web3.py", "LangChain", "Framer Motion"].map((skill) => (
            <span key={skill} className="nb-badge bg-nb-bg text-xs">{skill}</span>
          ))}
        </div>
      </div>
    </SlideBox>
  );
}

function CTASlide() {
  return (
    <SlideBox className="text-center space-y-8">
      <motion.div
        animate={{ scale: [1, 1.05, 1] }}
        transition={{ repeat: Infinity, duration: 2 }}
      >
        <h1 className="font-display font-bold text-6xl sm:text-8xl">
          <span className="inline-block bg-nb-accent border-3 border-nb-ink rounded-nb px-6 py-3 shadow-nb">
            ALIVE
          </span>
        </h1>
      </motion.div>

      <p className="text-2xl text-nb-ink/70 font-display max-w-2xl mx-auto">
        Evolution never stops. Neither should your yield.
      </p>

      <div className="flex flex-wrap justify-center gap-4">
        <Link href="/" className="nb-btn nb-btn-primary text-xl px-8 py-4">
          <Dna size={24} /> Try the Live App
        </Link>
        <a
          href="https://github.com"
          target="_blank"
          rel="noopener noreferrer"
          className="nb-btn nb-btn-secondary text-xl px-8 py-4"
        >
          <GitBranch size={24} /> View Source
        </a>
      </div>

      <div className="space-y-2 text-nb-ink/40 font-mono text-sm">
        <p>6 Contracts  ·  73 Tests  ·  PolkaVM + XCM  ·  AI-Powered Seeding</p>
        <p>Built for Polkadot Solidity Hackathon 2026</p>
      </div>
    </SlideBox>
  );
}
