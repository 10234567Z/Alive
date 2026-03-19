export default function Footer() {
  return (
    <footer className="border-t-3 border-nb-ink bg-nb-bg mt-auto">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="font-display font-medium text-sm">
            &copy; 2026 ALIVE Protocol | Evolutionary DeFi on Polkadot
          </p>
          <div className="flex items-center gap-4 text-sm font-mono">
            <a
              href="https://github.com"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-nb-accent-2 transition-colors"
            >
              GitHub
            </a>
            <span className="text-nb-ink/30">|</span>
            <a href="#" className="hover:text-nb-accent-2 transition-colors">
              Docs
            </a>
            <span className="text-nb-ink/30">|</span>
            <div className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-nb-ok animate-pulse" />
              <span className="text-nb-ok">Polkadot Hub</span>
            </div>
          </div>
        </div>
      </div>
    </footer>
  );
}
