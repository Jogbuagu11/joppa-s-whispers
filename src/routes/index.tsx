import { createFileRoute, Link } from "@tanstack/react-router";
import { Apple, Play, Sparkles, Hammer, Search, CheckCircle2 } from "lucide-react";
import { useState, type FormEvent } from "react";
import { SiteHeader } from "@/components/site-header";
import { SiteFooter } from "@/components/site-footer";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/")({
  head: () => ({ meta: [{ title: "Whispers of Joppa — A Merge Story of Grace" }, { name: "description", content: "Restore an ancient harbor town, uncover hidden letters, and discover what grace can rebuild in this free merge-and-story mobile game." }, { property: "og:title", content: "Whispers of Joppa — A Merge Story of Grace" }, { property: "og:description", content: "Restore the town, uncover the truth behind its whispers, and discover what grace can rebuild." }, { property: "og:type", content: "website" }, { property: "og:url", content: "/" }, { property: "og:image", content: "https://whispersofjoppa.com/images/joppa-hero.jpg" }, { name: "twitter:card", content: "summary_large_image" }, { name: "twitter:image", content: "https://whispersofjoppa.com/images/joppa-hero.jpg" }], links: [{ rel: "canonical", href: "/" }] }),
  component: HomePage,
});

const people = [
  { name: "Naomi", description: "A widow with a reputation to restore.", position: "object-[6%_center]" },
  { name: "Esther", description: "Her grandmother, whose hidden letters guide the way.", position: "object-[27%_center]" },
  { name: "Caleb", description: "A quiet boat builder carrying a painful secret.", position: "object-[51%_center]" },
  { name: "Joy", description: "His fearless daughter, who asks the questions no one else will.", position: "object-[73%_center]" },
  { name: "Silas", description: "An old fisherman who remembers everything, slowly.", position: "object-[96%_center]" },
];
const steps = [
  { title: "Merge", text: "Combine items into greater treasures.", Icon: Sparkles },
  { title: "Restore", text: "Rebuild the bakehouse, the docks, and the harbor.", Icon: Hammer },
  { title: "Uncover", text: "Reveal the truth behind every rumor.", Icon: Search },
];

function StoreBadge({ store }: { store: "App Store" | "Google Play" }) { const Icon = store === "App Store" ? Apple : Play; return <a href="#launch-list" className="store-badge" aria-label={`${store}, coming soon`}><Icon className="h-7 w-7" /><span className="leading-tight"><small className="block text-[.65rem] uppercase opacity-75">Coming soon on the</small><strong>{store}</strong></span></a>; }

function LaunchSignup() {
  const [state, setState] = useState<"idle" | "loading" | "success" | "duplicate" | "error">("idle");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setState("loading");
    const data = new FormData(event.currentTarget);
    const name = String(data.get("name") ?? "").trim();
    const email = String(data.get("email") ?? "").trim().toLowerCase();
    const { error } = await supabase.from("launch_signups").insert({ name, email });
    if (!error) { setState("success"); event.currentTarget.reset(); return; }
    if (error.code === "23505") { setState("duplicate"); return; }
    setState("error");
  }
  if (state === "success") return <div className="flex items-center justify-center gap-3 py-7 text-center text-lg"><CheckCircle2 className="h-6 w-6 text-sea" /><span>Thank you. We’ll send word when the harbor opens.</span></div>;
  return <form onSubmit={submit} className="mx-auto mt-8 grid max-w-3xl gap-3 sm:grid-cols-[1fr_1.25fr_auto]">
    <label className="sr-only" htmlFor="launch-name">Name</label><Input id="launch-name" name="name" placeholder="Your name" required maxLength={100} className="h-12 border-on-dark/30 bg-on-dark/10 text-on-dark placeholder:text-footer-muted" />
    <label className="sr-only" htmlFor="launch-email">Email</label><Input id="launch-email" name="email" type="email" placeholder="Email address" required maxLength={254} className="h-12 border-on-dark/30 bg-on-dark/10 text-on-dark placeholder:text-footer-muted" />
    <Button type="submit" disabled={state === "loading"} className="h-12 bg-terracotta px-7 text-primary-foreground hover:bg-terracotta/90">{state === "loading" ? "Joining…" : "Join the list"}</Button>
    {state === "duplicate" && <p className="sm:col-span-3 text-sm text-sand">That email is already on the launch list.</p>}
    {state === "error" && <p className="sm:col-span-3 text-sm text-sand">We couldn’t add you just now. Please try again.</p>}
  </form>;
}

function HomePage() {
  return <div className="min-h-screen bg-background"><SiteHeader /><main>
    <section className="hero"><img src="/images/joppa-hero.jpg" width="1200" height="630" alt="Naomi at her grandmother's bakehouse overlooking ancient Joppa" className="hero-image" fetchPriority="high" /><div className="hero-shade" /><div className="hero-content fade-in"><p className="mb-4 text-sm font-bold uppercase tracking-[.14em] text-sand">A free merge & story adventure</p><h1 className="hero-title">Whispers<br />of Joppa</h1><p className="hero-tagline">A merge story of grace</p><div className="mt-8 flex flex-wrap gap-3"><StoreBadge store="App Store" /><StoreBadge store="Google Play" /></div></div></section>
    <section className="section-pad"><div className="site-container text-center"><p className="eyebrow">Her story begins again</p><p className="story-lede">Sent away under a cloud of rumor, Naomi returns to the ancient harbor town of Joppa, where her late grandmother left her a crumbling bakehouse and a trail of hidden letters. Restore the town, uncover the truth behind its whispers, and discover what grace can rebuild.</p></div></section>
    <section className="pb-22"><div className="site-container"><div className="text-center"><p className="eyebrow">From ruin to renewal</p><h2 className="section-title">How it plays</h2></div><img src="/images/how-it-plays.jpg" width="1536" height="768" alt="Merging treasures, restoring the bakehouse, and uncovering a hidden letter" className="mt-9 aspect-[2/1] w-full rounded-md object-cover shadow-xl" loading="lazy" /><div className="play-grid">{steps.map(({ title, text, Icon }, i) => <article className="play-card" key={title}><div className="flex items-center justify-between"><span className="play-number">0{i + 1}</span><Icon className="h-6 w-6 text-olive" /></div><h3 className="play-title">{title}</h3><p className="mt-1 text-muted-foreground">{text}</p></article>)}</div></div></section>
    <section className="bg-parchment section-pad"><div className="site-container"><p className="eyebrow">Friends, family & old secrets</p><h2 className="section-title">Meet the people of Joppa</h2><div className="mt-10 grid grid-cols-2 gap-4 md:grid-cols-5">{people.map((person) => <article className="cast-card" key={person.name}><img src="/images/joppa-cast.jpg" width="1600" height="900" alt={person.name} className={`cast-portrait ${person.position}`} loading="lazy" /><div className="p-4"><h3 className="text-2xl font-semibold text-indigo">{person.name}</h3><p className="mt-1 text-sm leading-relaxed text-muted-foreground">{person.description}</p></div></article>)}</div></div></section>
    <section className="faith-band"><div className="site-container grid items-center gap-10 py-18 md:grid-cols-[.75fr_1.25fr]"><div><p className="text-xs font-bold uppercase tracking-[.14em] text-sand">A story with purpose</p><h2 className="mt-3 text-5xl font-semibold leading-none">Rooted in Scripture.</h2></div><blockquote className="border-l border-sand/50 pl-6 font-serif text-2xl leading-relaxed">Inspired by Acts 9–11 and Proverbs 16:28, “A whisperer separateth chief friends.” <span className="block mt-3 font-sans text-base text-on-dark/75">A story about the cost of gossip and the power of truth, forgiveness, and grace.</span></blockquote></div></section>
    <section id="launch-list" className="signup-band scroll-mt-20"><div className="site-container py-18 text-center"><p className="text-xs font-bold uppercase tracking-[.14em] text-sand">Be first to return to Joppa</p><h2 className="mt-3 text-5xl font-semibold">Join the launch list</h2><p className="mx-auto mt-3 max-w-xl text-footer-muted">Get a note when Whispers of Joppa is ready for iPhone and Android.</p><LaunchSignup /></div></section>
  </main><SiteFooter /></div>;
}
