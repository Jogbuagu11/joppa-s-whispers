import type { ReactNode } from "react";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";

export function PageShell({ eyebrow, title, intro, children }: { eyebrow: string; title: string; intro?: string; children: ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <SiteHeader />
      <main>
        <header className="page-banner">
          <div className="site-container relative py-16 sm:py-22">
            <p className="eyebrow">{eyebrow}</p>
            <h1 className="page-title">{title}</h1>
            {intro && <p className="page-intro">{intro}</p>}
          </div>
        </header>
        <div className="site-container py-12 sm:py-16">{children}</div>
      </main>
      <SiteFooter />
    </div>
  );
}

export function ProseSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="prose-section">
      <h2>{title}</h2>
      <div className="prose-copy">{children}</div>
    </section>
  );
}
