import type { Metadata } from "next";
import "./globals.css";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import InspectorWrapper from "@/components/InspectorWrapper";
import Web3Provider from "@/components/Web3Provider";
import ChainSync from "@/components/ChainSync";

export const metadata: Metadata = {
  title: "ALIVE | Evolutionary DeFi on Polkadot",
  description:
    "Autonomous Creatures compete for yield. Genetic algorithms evolve optimal DeFi strategies on-chain.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen flex flex-col bg-nb-bg text-nb-ink antialiased">
        <Web3Provider>
          <ChainSync />
          <Header />
          <main className="flex-1">{children}</main>
          <Footer />
          <InspectorWrapper />
        </Web3Provider>
      </body>
    </html>
  );
}
