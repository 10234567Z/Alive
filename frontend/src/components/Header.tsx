"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Dna, BarChart3, LayoutDashboard, Trophy, Loader2 } from "lucide-react";
import { useAccount, useConnect, useDisconnect } from "wagmi";
import { injected } from "wagmi/connectors";
import { useEcosystemStore } from "@/stores/ecosystem";

const NAV_ITEMS = [
  { href: "/", label: "Ecosystem", icon: Dna },
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/leaderboard", label: "Leaderboard", icon: Trophy },
];

export default function Header() {
  const pathname = usePathname();
  const { address, isConnected, isConnecting } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();
  const isLoading = useEcosystemStore((s) => s.isLoading);

  const handleWallet = () => {
    if (isConnected) {
      disconnect();
    } else {
      connect({ connector: injected() });
    }
  };

  return (
    <header className="sticky top-0 z-50 bg-nb-bg border-b-3 border-nb-ink">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-10 h-10 bg-nb-accent border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center font-display font-bold text-lg group-hover:-translate-y-0.5 transition-transform">
              A
            </div>
            <span className="font-display font-bold text-xl tracking-tight">
              ALIVE
            </span>
            {isLoading && (
              <Loader2 size={14} className="animate-spin text-nb-ink/40 ml-1" />
            )}
          </Link>

          {/* Nav */}
          <nav className="flex items-center gap-2">
            {NAV_ITEMS.map(({ href, label, icon: Icon }) => {
              const isActive = pathname === href;
              return (
                <Link
                  key={href}
                  href={href}
                  className={`
                    flex items-center gap-1.5 px-4 py-2 font-display font-medium text-sm
                    border-3 border-nb-ink rounded-nb transition-all
                    ${
                      isActive
                        ? "bg-nb-accent shadow-nb-sm -translate-y-0.5"
                        : "bg-nb-card hover:bg-nb-accent/30 hover:-translate-y-0.5 hover:shadow-nb-sm"
                    }
                  `}
                >
                  <Icon size={16} />
                  <span className="hidden sm:inline">{label}</span>
                </Link>
              );
            })}
          </nav>

          {/* Wallet */}
          <button
            onClick={handleWallet}
            className={`nb-btn text-sm ${isConnected ? "nb-btn-secondary" : "nb-btn-primary"}`}
          >
            {isConnecting ? (
              <Loader2 size={16} className="animate-spin" />
            ) : (
              <BarChart3 size={16} />
            )}
            <span className="hidden sm:inline">
              {isConnected && address
                ? `${address.slice(0, 6)}...${address.slice(-4)}`
                : "Connect Wallet"}
            </span>
            <span className="sm:hidden">
              {isConnected ? "Connected" : "Connect"}
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}
