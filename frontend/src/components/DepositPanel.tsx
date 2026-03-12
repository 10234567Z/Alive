"use client";

import { useState } from "react";
import { ArrowDownToLine, ArrowUpFromLine, Wallet, TrendingUp } from "lucide-react";
import { useEcosystemStore } from "@/stores/ecosystem";

export default function DepositPanel() {
  const { user, deposit, withdraw } = useEcosystemStore();
  const [amount, setAmount] = useState("");
  const [mode, setMode] = useState<"deposit" | "withdraw">("deposit");

  const deposited = user.deposited / 1e6;
  const shareValue = user.shareValue / 1e6;
  const yieldEarned = shareValue - deposited;
  const yieldPct = deposited > 0 ? ((yieldEarned / deposited) * 100).toFixed(2) : "0.00";

  const handleSubmit = () => {
    const val = parseFloat(amount);
    if (isNaN(val) || val <= 0) return;
    const scaled = Math.floor(val * 1e6);
    if (mode === "deposit") {
      deposit(scaled);
    } else {
      withdraw(scaled);
    }
    setAmount("");
  };

  const presets = [100, 1000, 5000, 10000];

  return (
    <div className="nb-card p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 bg-nb-accent border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center">
          <Wallet size={20} />
        </div>
        <div>
          <h3 className="font-display font-bold text-lg">Your Position</h3>
          <p className="text-sm text-nb-ink/60">Deposit USDC to feed the creatures</p>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-nb-bg border-3 border-nb-ink rounded-nb p-3">
          <p className="text-xs font-mono text-nb-ink/60 uppercase">Deposited</p>
          <p className="font-display font-bold text-lg">
            ${deposited.toLocaleString("en-US", { minimumFractionDigits: 0 })}
          </p>
        </div>
        <div className="bg-nb-bg border-3 border-nb-ink rounded-nb p-3">
          <p className="text-xs font-mono text-nb-ink/60 uppercase">Share Value</p>
          <p className="font-display font-bold text-lg">
            ${shareValue.toLocaleString("en-US", { minimumFractionDigits: 0 })}
          </p>
        </div>
        <div className="bg-nb-bg border-3 border-nb-ink rounded-nb p-3">
          <p className="text-xs font-mono text-nb-ink/60 uppercase">Shares</p>
          <p className="font-display font-bold text-lg">{user.shares.toLocaleString()}</p>
        </div>
        <div className="bg-nb-accent/20 border-3 border-nb-ink rounded-nb p-3">
          <p className="text-xs font-mono text-nb-ink/60 uppercase flex items-center gap-1">
            <TrendingUp size={12} /> Yield
          </p>
          <p className="font-display font-bold text-lg text-nb-ok">
            +${yieldEarned.toLocaleString("en-US", { minimumFractionDigits: 0 })}
            <span className="text-xs ml-1">({yieldPct}%)</span>
          </p>
        </div>
      </div>

      {/* Mode Toggle */}
      <div className="flex border-3 border-nb-ink rounded-nb overflow-hidden">
        <button
          onClick={() => setMode("deposit")}
          className={`flex-1 py-2.5 font-display font-semibold text-sm flex items-center justify-center gap-1.5 transition-colors ${
            mode === "deposit" ? "bg-nb-accent" : "bg-nb-card hover:bg-nb-accent/20"
          }`}
        >
          <ArrowDownToLine size={16} /> Deposit
        </button>
        <button
          onClick={() => setMode("withdraw")}
          className={`flex-1 py-2.5 font-display font-semibold text-sm flex items-center justify-center gap-1.5 border-l-3 border-nb-ink transition-colors ${
            mode === "withdraw" ? "bg-nb-error text-white" : "bg-nb-card hover:bg-nb-error/10"
          }`}
        >
          <ArrowUpFromLine size={16} /> Withdraw
        </button>
      </div>

      {/* Amount Input */}
      <div className="space-y-3">
        <div className="relative">
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            className="nb-input pr-16 text-lg"
          />
          <span className="absolute right-4 top-1/2 -translate-y-1/2 font-mono text-sm text-nb-ink/50">
            USDC
          </span>
        </div>

        {/* Presets */}
        <div className="flex gap-2">
          {presets.map((p) => (
            <button
              key={p}
              onClick={() => setAmount(p.toString())}
              className="flex-1 py-1.5 text-xs font-mono font-semibold border-2 border-nb-ink rounded-nb bg-nb-card hover:bg-nb-accent/20 hover:-translate-y-0.5 transition-all"
            >
              {p >= 1000 ? `${p / 1000}K` : p}
            </button>
          ))}
          {mode === "withdraw" && (
            <button
              onClick={() => setAmount((deposited).toString())}
              className="flex-1 py-1.5 text-xs font-mono font-semibold border-2 border-nb-ink rounded-nb bg-nb-error/10 hover:bg-nb-error/20 hover:-translate-y-0.5 transition-all"
            >
              MAX
            </button>
          )}
        </div>
      </div>

      {/* Submit Button */}
      <button
        onClick={handleSubmit}
        disabled={!amount || parseFloat(amount) <= 0}
        className={`nb-btn w-full text-lg ${
          mode === "deposit" ? "nb-btn-primary" : "nb-btn-danger"
        } disabled:opacity-40 disabled:cursor-not-allowed disabled:transform-none disabled:shadow-none`}
      >
        {mode === "deposit" ? (
          <>
            <ArrowDownToLine size={20} /> Deposit USDC
          </>
        ) : (
          <>
            <ArrowUpFromLine size={20} /> Withdraw USDC
          </>
        )}
      </button>

      {/* Info */}
      <p className="text-xs text-center text-nb-ink/40 font-mono">
        Deposits are allocated to creatures based on fitness scores each epoch
      </p>
    </div>
  );
}
