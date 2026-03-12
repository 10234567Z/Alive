"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Dna, BarChart3, LayoutDashboard, Trophy } from "lucide-react";

const NAV_ITEMS = [
  { href: "/", label: "Ecosystem", icon: Dna },
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/leaderboard", label: "Leaderboard", icon: Trophy },
];

export default function Header() {
  const pathname = usePathname();

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
          <button className="nb-btn nb-btn-secondary text-sm">
            <BarChart3 size={16} />
            <span className="hidden sm:inline">0x742d...bD18</span>
            <span className="sm:hidden">Connected</span>
          </button>
        </div>
      </div>
    </header>
  );
}
