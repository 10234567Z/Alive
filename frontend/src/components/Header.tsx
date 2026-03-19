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
      <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-14 sm:h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-1.5 sm:gap-2 group">
            <div className="w-8 h-8 sm:w-10 sm:h-10 bg-nb-accent border-3 border-nb-ink rounded-nb shadow-nb-sm flex items-center justify-center font-display font-bold text-base sm:text-lg group-hover:-translate-y-0.5 transition-transform">
              A
            </div>
            <span className="font-display font-bold text-lg sm:text-xl tracking-tight hidden xs:inline">
              ALIVE
            </span>
            {isLoading && (
              <Loader2 size={14} className="animate-spin text-nb-ink/40 ml-1" />
            )}
          </Link>

          {/* Nav */}
          <nav className="flex items-center gap-1 sm:gap-2">
            {NAV_ITEMS.map(({ href, label, icon: Icon }) => {
              const isActive = pathname === href;
              return (
                <Link
                  key={href}
                  href={href}
                  className={`
                    flex items-center gap-1 sm:gap-1.5 px-2 sm:px-4 py-1.5 sm:py-2 font-display font-medium text-xs sm:text-sm
                    border-2 sm:border-3 border-nb-ink rounded-nb transition-all
                    ${
                      isActive
                        ? "bg-nb-accent shadow-nb-sm -translate-y-0.5"
                        : "bg-nb-card hover:bg-nb-accent/30 hover:-translate-y-0.5 hover:shadow-nb-sm"
                    }
                  `}
                >
                  <Icon size={14} className="sm:w-4 sm:h-4" />
                  <span className="hidden sm:inline">{label}</span>
                </Link>
              );
            })}
          </nav>

          {/* Wallet */}
          <button
            onClick={handleWallet}
            className={`nb-btn text-xs sm:text-sm ${isConnected ? "nb-btn-secondary" : "nb-btn-primary"}`}
          >
            {isConnecting ? (
              <Loader2 size={14} className="animate-spin" />
            ) : (
              <BarChart3 size={14} className="sm:w-4 sm:h-4" />
            )}
            <span className="hidden sm:inline">
              {isConnected && address
                ? `${address.slice(0, 6)}...${address.slice(-4)}`
                : "Connect Wallet"}
            </span>
            <span className="sm:hidden text-xs">
              {isConnected ? address?.slice(0, 4) + "…" : "Connect"}
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}
