import { Link } from "@tanstack/react-router";
import { Menu, X } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/button";

const links = [
  { to: "/", label: "Home" },
  { to: "/support", label: "Support" },
  { to: "/privacy", label: "Privacy" },
  { to: "/terms", label: "Terms" },
] as const;

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  return (
    <header className="site-header">
      <div className="site-container flex h-18 items-center justify-between">
        <Link to="/" className="brand-link" aria-label="Whispers of Joppa home">
          <img src="/images/joppa-icon.png" width="44" height="44" alt="" className="h-10 w-10" />
          <span>Whispers of Joppa</span>
        </Link>
        <nav className="hidden items-center gap-7 md:flex" aria-label="Main navigation">
          {links.map((link) => (
            <Link key={link.to} to={link.to} className="nav-link" activeProps={{ className: "nav-link nav-link-active" }}>
              {link.label}
            </Link>
          ))}
        </nav>
        <Button variant="ghost" size="icon" className="md:hidden" onClick={() => setOpen((value) => !value)} aria-label={open ? "Close menu" : "Open menu"} aria-expanded={open}>
          {open ? <X /> : <Menu />}
        </Button>
      </div>
      {open && (
        <nav className="mobile-nav md:hidden" aria-label="Mobile navigation">
          {links.map((link) => (
            <Link key={link.to} to={link.to} className="mobile-nav-link" onClick={() => setOpen(false)}>{link.label}</Link>
          ))}
        </nav>
      )}
    </header>
  );
}
