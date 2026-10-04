import { Link } from "@tanstack/react-router";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="site-container py-12">
        <div className="flex flex-col items-center justify-between gap-7 md:flex-row">
          <Link to="/" className="brand-link brand-link-footer">
            <img src="/images/joppa-icon.png" width="44" height="44" alt="" className="h-10 w-10" />
            <span>Whispers of Joppa</span>
          </Link>
          <nav className="flex flex-wrap justify-center gap-x-6 gap-y-3 text-sm" aria-label="Footer navigation">
            <Link to="/support">Support</Link>
            <Link to="/privacy">Privacy Policy</Link>
            <Link to="/terms">Terms of Service</Link>
            <Link to="/delete-account">Delete Account</Link>
          </nav>
        </div>
        <div className="footer-rule" />
        <p className="text-center text-xs text-footer-muted md:text-left">© 2026 Whispers of Joppa. All rights reserved.</p>
      </div>
    </footer>
  );
}
