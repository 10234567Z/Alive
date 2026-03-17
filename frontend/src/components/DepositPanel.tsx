"use client";

import { useState, useCallback } from "react";
import { ArrowDownToLine, ArrowUpFromLine, Wallet, TrendingUp, Loader2, AlertCircle, CheckCircle2 } from "lucide-react";
import { useAccount, useWriteContract, useReadContract } from "wagmi";
import { parseUnits } from "viem";
import { waitForTransactionReceipt } from "@wagmi/core";
import { useQueryClient } from "@tanstack/react-query";
import { EcosystemABI, ERC20ABI, CONTRACTS, wagmiConfig } from "@/lib/contracts";
import { useUserPosition } from "@/hooks/useContracts";

export default function DepositPanel() {
  const { address, isConnected } = useAccount();
  const { shares, shareValue } = useUserPosition(address);
  const queryClient = useQueryClient();
  const [amount, setAmount] = useState("");
  const [mode, setMode] = useState<"deposit" | "withdraw">("deposit");
  const [status, setStatus] = useState("");
  const [isPending, setIsPending] = useState(false);

  const { writeContractAsync } = useWriteContract();

  // Read user's USDC balance
  const { data: usdcBalanceRaw } = useReadContract({
    address: CONTRACTS.stablecoin,
    abi: ERC20ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });
  const usdcBalance = Number(usdcBalanceRaw ?? BigInt(0)) / 1e6;

  const shareValueUSD = shareValue / 1e6;

  // ── Deposit: approve → wait confirm → deposit → wait confirm ──
  const handleDeposit = useCallback(async () => {
    const val = parseFloat(amount);
    if (isNaN(val) || val <= 0 || !isConnected) return;

    const scaled = parseUnits(val.toString(), 6);

    try {
      setIsPending(true);

      // Step 1: Approve
      setStatus("Approving USDC spend...");
      const approveTxHash = await writeContractAsync({
        address: CONTRACTS.stablecoin,
        abi: ERC20ABI,
        functionName: "approve",
        args: [CONTRACTS.ecosystem, scaled],
      });

      // Step 2: Wait for approval to be mined
      setStatus("Waiting for approval confirmation...");
      await waitForTransactionReceipt(wagmiConfig, { hash: approveTxHash });

      // Step 3: Deposit
      setStatus("Depositing USDC...");
      const depositTxHash = await writeContractAsync({
        address: CONTRACTS.ecosystem,
        abi: EcosystemABI,
        functionName: "deposit",
        args: [scaled],
      });

      // Step 4: Wait for deposit to be mined
      setStatus("Confirming deposit...");
      await waitForTransactionReceipt(wagmiConfig, { hash: depositTxHash });

      setStatus("Deposit successful!");
      setAmount("");
      // Refetch all chain data immediately
      queryClient.invalidateQueries();
      setTimeout(() => setStatus(""), 4000);
    } catch (err: unknown) {
      const msg = err instanceof Error ? (err as { shortMessage?: string }).shortMessage || err.message : "Unknown error";
      setStatus(`Error: ${msg}`);
      setTimeout(() => setStatus(""), 5000);
    } finally {
      setIsPending(false);
    }
  }, [amount, isConnected, writeContractAsync, queryClient]);

  // ── Withdraw: calculate proportional shares → withdraw → wait confirm ──
  const handleWithdraw = useCallback(async () => {
    const val = parseFloat(amount);
    if (isNaN(val) || val <= 0 || !isConnected || shares <= 0) return;

    const enteredRaw = parseUnits(val.toString(), 6);

    // Calculate how many shares to burn for the entered USDC amount
    // sharesToBurn = (enteredUSDC * totalUserShares) / totalUserShareValue
    let sharesToBurn: bigint;
    if (Number(enteredRaw) >= shareValue) {
      // Withdrawing everything — burn all shares
      sharesToBurn = BigInt(shares);
    } else {
      sharesToBurn = (enteredRaw * BigInt(shares)) / BigInt(shareValue);
      if (sharesToBurn <= BigInt(0)) sharesToBurn = BigInt(1);
    }

    try {
      setIsPending(true);
      setStatus(`Withdrawing (burning ${sharesToBurn.toString()} shares)...`);

      const withdrawTxHash = await writeContractAsync({
        address: CONTRACTS.ecosystem,
        abi: EcosystemABI,
        functionName: "withdraw",
        args: [sharesToBurn],
      });

      setStatus("Confirming withdrawal...");
      await waitForTransactionReceipt(wagmiConfig, { hash: withdrawTxHash });

      setStatus("Withdrawal successful! USDC returned to wallet.");
      setAmount("");
      queryClient.invalidateQueries();
      setTimeout(() => setStatus(""), 4000);
    } catch (err: unknown) {
      const msg = err instanceof Error ? (err as { shortMessage?: string }).shortMessage || err.message : "Unknown error";
      setStatus(`Error: ${msg}`);
      setTimeout(() => setStatus(""), 5000);
    } finally {
      setIsPending(false);
    }
  }, [amount, isConnected, shares, shareValue, writeContractAsync, queryClient]);

  const handleSubmit = mode === "deposit" ? handleDeposit : handleWithdraw;

  const presets = mode === "deposit" ? [100, 1000, 5000, 10000] : [100, 500, 1000];

  return (
    <div className="nb-card p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 bg-nb-accent border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center">
          <Wallet size={20} />
        </div>
        <div>
          <h3 className="font-display font-bold text-lg">Your Position</h3>
          <p className="text-sm text-nb-ink/60">
            {isConnected ? "Deposit USDC to feed the creatures" : "Connect wallet to deposit"}
          </p>
        </div>
      </div>

      {!isConnected && (
        <div className="flex items-center gap-2 bg-nb-warn/20 border-3 border-nb-ink rounded-nb p-3 text-sm">
          <AlertCircle size={16} className="text-nb-warn shrink-0" />
          <span>Connect your wallet to interact with the ecosystem</span>
        </div>
      )}

      {/* Stats Grid */}
      <div className="grid grid-cols-2 gap-3">
        <div className="bg-nb-bg border-3 border-nb-ink rounded-nb p-3">
          <p className="text-xs font-mono text-nb-ink/60 uppercase">Position Value</p>
          <p className="font-display font-bold text-lg">
            ${shareValueUSD.toLocaleString("en-US", { minimumFractionDigits: 2 })}
          </p>
        </div>
        <div className="bg-nb-bg border-3 border-nb-ink rounded-nb p-3 overflow-hidden">
          <p className="text-xs font-mono text-nb-ink/60 uppercase">Shares</p>
          <p className="font-display font-bold text-lg truncate">
            {shares >= 1e9 ? `${(shares / 1e9).toFixed(1)}B` :
             shares >= 1e6 ? `${(shares / 1e6).toFixed(1)}M` :
             shares >= 1e3 ? `${(shares / 1e3).toFixed(1)}K` :
             shares.toLocaleString()}
          </p>
        </div>
        <div className="bg-nb-accent/20 border-3 border-nb-ink rounded-nb p-3 col-span-2 flex items-center justify-between">
          <div>
            <p className="text-xs font-mono text-nb-ink/60 uppercase flex items-center gap-1">
              <Wallet size={12} /> USDC Balance
            </p>
            <p className="font-display font-bold text-lg">
              ${usdcBalance.toLocaleString("en-US", { minimumFractionDigits: 2 })}
            </p>
          </div>
          <div className="text-right">
            <p className="text-xs font-mono text-nb-ink/60 uppercase flex items-center gap-1 justify-end">
              <TrendingUp size={12} /> Available to Withdraw
            </p>
            <p className="font-display font-bold text-lg text-nb-ok">
              ${shareValueUSD.toLocaleString("en-US", { minimumFractionDigits: 2 })}
            </p>
          </div>
        </div>
      </div>

      {/* Status Message */}
      {status && (
        <div className={`flex items-center gap-2 border-3 border-nb-ink rounded-nb p-3 text-sm ${
          status.startsWith("Error") ? "bg-nb-error/20 text-nb-error" :
          status.includes("successful") ? "bg-nb-ok/20 text-nb-ok" :
          "bg-nb-accent/20"
        }`}>
          {status.includes("successful") ? <CheckCircle2 size={16} className="shrink-0" /> :
           status.startsWith("Error") ? <AlertCircle size={16} className="shrink-0" /> :
           <Loader2 size={16} className="animate-spin shrink-0" />}
          <span className="font-mono">{status}</span>
        </div>
      )}

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
            disabled={!isConnected || isPending}
          />
          <span className="absolute right-4 top-1/2 -translate-y-1/2 font-mono text-sm text-nb-ink/50">
            USDC
          </span>
        </div>

        {/* Presets + Max */}
        <div className="flex gap-2">
          {presets.map((p) => (
            <button
              key={p}
              onClick={() => setAmount(p.toString())}
              disabled={!isConnected || isPending}
              className="flex-1 py-1.5 text-xs font-mono font-semibold border-2 border-nb-ink rounded-nb bg-nb-card hover:bg-nb-accent/20 hover:-translate-y-0.5 transition-all disabled:opacity-30"
            >
              {p >= 1000 ? `${p / 1000}K` : p}
            </button>
          ))}
          <button
            onClick={() => {
              if (mode === "deposit") {
                setAmount(usdcBalance.toString());
              } else {
                setAmount(shareValueUSD.toString());
              }
            }}
            disabled={!isConnected || isPending}
            className="flex-1 py-1.5 text-xs font-mono font-semibold border-2 border-nb-ink rounded-nb bg-nb-warn/30 hover:bg-nb-warn/50 hover:-translate-y-0.5 transition-all disabled:opacity-30"
          >
            MAX
          </button>
        </div>
      </div>

      {/* Submit Button */}
      <button
        onClick={handleSubmit}
        disabled={!amount || parseFloat(amount) <= 0 || !isConnected || isPending}
        className={`nb-btn w-full text-lg ${
          mode === "deposit" ? "nb-btn-primary" : "nb-btn-danger"
        } disabled:opacity-40 disabled:cursor-not-allowed disabled:transform-none disabled:shadow-none`}
      >
        {isPending ? (
          <>
            <Loader2 size={20} className="animate-spin" /> Confirming...
          </>
        ) : mode === "deposit" ? (
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
