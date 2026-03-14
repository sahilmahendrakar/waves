import Image from "next/image";

const features = [
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-7 h-7">
        <circle cx="12" cy="12" r="10" />
        <polyline points="12 6 12 12 16 14" />
      </svg>
    ),
    title: "Waves Mode",
    description:
      "Deep focus sessions with a rising and falling intensity arc that follows your work rhythm.",
  },
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-7 h-7">
        <path d="M9 18V5l12-2v13" />
        <circle cx="6" cy="18" r="3" />
        <circle cx="18" cy="16" r="3" />
      </svg>
    ),
    title: "Surf Mode",
    description:
      "Auto-adapting music that responds to your activity and keeps you in the zone without manual tweaking.",
  },
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-7 h-7">
        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
        <line x1="12" x2="12" y1="19" y2="22" />
      </svg>
    ),
    title: "Voice Steering",
    description:
      "Natural language commands to shape the music in real time. Just speak and the music responds.",
  },
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-7 h-7">
        <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z" />
        <circle cx="12" cy="12" r="3" />
      </svg>
    ),
    title: "FocusGuard",
    description:
      "Monitors your activity and gently refocuses you when you drift. Stay in the zone without trying.",
  },
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-7 h-7">
        <rect x="2" y="3" width="20" height="14" rx="2" />
        <line x1="8" x2="16" y1="21" y2="21" />
        <line x1="12" x2="12" y1="17" y2="21" />
      </svg>
    ),
    title: "App Music Routing",
    description:
      "Automatically switches the music based on your active app. Code, design, browse — each gets its own sound.",
  },
  {
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="w-7 h-7">
        <rect x="3" y="1" width="18" height="4" rx="1" />
        <path d="M12 5v2" />
        <path d="M8 5v1" />
        <path d="M16 5v1" />
        <rect x="1" y="7" width="22" height="16" rx="2" />
      </svg>
    ),
    title: "Menu Bar Control",
    description:
      "Always accessible from your macOS menu bar. One click to play, pause, or switch modes.",
  },
];

export default function Home() {
  return (
    <div className="min-h-screen overflow-x-hidden">
      {/* ==================== HERO ==================== */}
      <section className="radial-hero relative flex min-h-screen flex-col items-center justify-center overflow-visible px-6 text-center">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full bg-cyan/5 blur-[120px] animate-glow-pulse" />
          <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full bg-purple/8 blur-[100px] animate-glow-pulse animation-delay-1000" />
          <div className="ripple-ring absolute left-1/2 top-1/3 h-[380px] w-[380px] -translate-x-1/2 -translate-y-1/2 rounded-full" />
          <div className="ripple-ring animation-delay-1000 absolute left-1/2 top-1/3 h-[500px] w-[500px] -translate-x-1/2 -translate-y-1/2 rounded-full" />
          <div className="ripple-ring animation-delay-2000 absolute left-1/2 top-1/3 h-[620px] w-[620px] -translate-x-1/2 -translate-y-1/2 rounded-full" />
        </div>

        <div className="relative z-10 flex max-w-4xl flex-col items-center gap-8 overflow-visible">
          <div className="animate-fade-in-up overflow-visible">
            <div className="hero-wordmark animate-float bg-gradient-to-r from-cyan via-blue to-purple bg-clip-text text-transparent">
              Waves
            </div>
          </div>

          <h1 className="animate-fade-in-up animation-delay-200 text-2xl font-semibold tracking-tight text-white/90 sm:text-4xl">
            Your Desktop Musical Companion
          </h1>

          <p className="animate-fade-in-up animation-delay-400 text-lg text-white/60 sm:text-xl max-w-xl leading-relaxed">
            AI-generated music that adapts to your focus. Powered by real-time
            generative audio, Waves keeps you in the zone.
          </p>

          <div className="animate-fade-in-up animation-delay-600 flex flex-col items-center gap-4 sm:flex-row">
            <a
              href="#"
              className="glow-button inline-flex items-center gap-2.5 rounded-full px-8 py-3.5 text-base font-semibold text-white"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11Z" />
              </svg>
              Download for macOS
            </a>
            <a
              href="#features"
              className="inline-flex items-center gap-2 rounded-full border border-white/10 px-6 py-3.5 text-base font-medium text-white/70 transition-colors hover:border-white/20 hover:text-white"
            >
              Learn more
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                <path fillRule="evenodd" d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z" clipRule="evenodd" />
              </svg>
            </a>
          </div>
        </div>

        <div className="absolute bottom-12 animate-fade-in-up animation-delay-1000">
          <div className="flex flex-col items-center gap-2 text-white/30 text-sm">
            <span>Scroll to explore</span>
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 animate-bounce">
              <path fillRule="evenodd" d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z" clipRule="evenodd" />
            </svg>
          </div>
        </div>
      </section>

      {/* ==================== FEATURES ==================== */}
      <section id="features" className="relative px-6 py-32">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-0 left-1/4 w-[500px] h-[500px] rounded-full bg-purple/5 blur-[150px]" />
          <div className="absolute bottom-0 right-1/4 w-[400px] h-[400px] rounded-full bg-cyan/5 blur-[120px]" />
        </div>

        <div className="relative z-10 mx-auto max-w-6xl">
          <div className="mb-16 text-center">
            <h2 className="text-4xl font-bold tracking-tight text-white sm:text-5xl">
              Everything you need to{" "}
              <span className="bg-gradient-to-r from-cyan to-purple bg-clip-text text-transparent">
                stay in flow
              </span>
            </h2>
            <p className="mt-4 text-lg text-white/50 max-w-2xl mx-auto">
              Waves combines AI music generation with smart productivity
              features to create your perfect work soundtrack.
            </p>
          </div>

          <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {features.map((feature, i) => (
              <div
                key={feature.title}
                className="glass-card group rounded-2xl p-7"
                style={{ animationDelay: `${i * 0.1}s` }}
              >
                <div className="mb-4 inline-flex rounded-xl bg-gradient-to-br from-cyan/10 to-purple/10 p-3 text-cyan transition-colors group-hover:from-cyan/20 group-hover:to-purple/20">
                  {feature.icon}
                </div>
                <h3 className="mb-2 text-lg font-semibold text-white">
                  {feature.title}
                </h3>
                <p className="text-sm leading-relaxed text-white/50">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="relative px-6 py-20">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-1/3 left-1/4 w-[500px] h-[500px] rounded-full bg-cyan/5 blur-[150px]" />
          <div className="absolute bottom-1/3 right-1/4 w-[500px] h-[500px] rounded-full bg-purple/5 blur-[150px]" />
        </div>

        <div className="relative z-10 mx-auto max-w-6xl space-y-8">
          <div className="glass-card rounded-3xl border border-cyan/30 bg-cyan/5 p-8 sm:p-10">
            <div className="grid grid-cols-1 gap-8 lg:grid-cols-2 lg:gap-10">
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-cyan/80">
                  Waves Mode
                </p>
                <h2 className="mt-3 text-3xl font-bold tracking-tight text-white sm:text-5xl">
                  A complete focus cycle that guides you back when you drift
                </h2>
                <p className="mt-4 text-base leading-relaxed text-white/65 sm:text-lg">
                  Start by setting a blocklist or allowlist for apps and websites.
                  Waves builds intensity as you settle in, crescendos when you are
                  locked in, and keeps pushing momentum while you work.
                </p>
              </div>

              <div className="relative aspect-[16/10] overflow-hidden rounded-xl border border-white/10 bg-black/20 shadow-2xl shadow-cyan/10">
                <Image
                  src="/Waves.png"
                  alt="Waves mode session interface"
                  fill
                  sizes="(min-width: 1024px) 45vw, 100vw"
                  className="object-contain"
                />
              </div>
            </div>

            <div className="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2">
              <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
                <div className="relative aspect-[4/3] overflow-hidden rounded-xl border border-white/10 bg-black/20">
                  <Image
                    src="/focus-guard.png"
                    alt="FocusGuard blocklist and allowlist controls"
                    fill
                    sizes="(min-width: 640px) 50vw, 100vw"
                    className="object-contain"
                  />
                </div>
                <h3 className="mt-4 text-sm font-semibold text-white">
                  Set your boundaries
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-white/55">
                  Use blocklist mode to mute known distractions, or allowlist mode
                  to only permit your focused apps and sites.
                </p>
              </div>

              <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
                <div className="relative aspect-[4/3] overflow-hidden rounded-xl border border-white/10 bg-black/20">
                  <Image
                    src="/crescendo.png"
                    alt="Music intensity crescendo during focus session"
                    fill
                    sizes="(min-width: 640px) 50vw, 100vw"
                    className="object-contain"
                  />
                </div>
                <h3 className="mt-4 text-sm font-semibold text-white">
                  Music crescendos with your momentum
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-white/55">
                  The soundtrack evolves from calm to energized as your session
                  progresses, then resolves as your wave completes.
                </p>
              </div>

              <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
                <div className="relative aspect-[4/3] overflow-hidden rounded-xl border border-white/10 bg-black/20">
                  <Image
                    src="/Wave%20refocus.png"
                    alt="Wave refocus warning when distracted"
                    fill
                    sizes="(min-width: 640px) 50vw, 100vw"
                    className="object-contain"
                  />
                </div>
                <h3 className="mt-4 text-sm font-semibold text-white">
                  Drift detection and reset
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-white/55">
                  If you get distracted, the music stops, Waves pings you, and the
                  wave resets so your next focused stretch starts clean.
                </p>
              </div>

              <div className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
                <div className="relative aspect-[4/3] overflow-hidden rounded-xl border border-white/10 bg-black/20">
                  <Image
                    src="/voice-steering.png"
                    alt="Voice steering to control music and blocklist"
                    fill
                    sizes="(min-width: 640px) 50vw, 100vw"
                    className="object-contain"
                  />
                </div>
                <h3 className="mt-4 text-sm font-semibold text-white">
                  Voice steering on the fly
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-white/55">
                  Speak to adjust your blocklist or shift the musical direction in
                  real time without leaving your workflow.
                </p>
              </div>
            </div>
          </div>

          <div className="glass-card rounded-3xl border border-purple/30 bg-purple/5 p-8 sm:p-10">
            <div className="grid grid-cols-1 gap-8 lg:grid-cols-2 lg:gap-10">
              <div className="order-2 lg:order-1">
                <p className="text-xs uppercase tracking-[0.2em] text-purple/80">
                  Surf Mode
                </p>
                <h2 className="mt-3 text-2xl font-bold tracking-tight text-white sm:text-4xl">
                  Adaptive flow music that keeps you in the zone
                </h2>
                <p className="mt-4 text-base leading-relaxed text-white/65 sm:text-lg">
                  Surf mode continuously adapts your soundtrack to your activity and
                  context, balancing familiarity and variation so you can stay in a
                  productive groove for longer.
                </p>
              </div>
              <div className="order-1 relative aspect-[16/10] overflow-hidden rounded-xl border border-white/10 bg-black/20 shadow-2xl shadow-purple/10 lg:order-2">
                <Image
                  src="/Surf.png"
                  alt="Surf mode adaptive music controls"
                  fill
                  sizes="(min-width: 1024px) 45vw, 100vw"
                  className="object-contain"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ==================== BOTTOM CTA ==================== */}
      <section className="relative px-6 py-32">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] rounded-full bg-cyan/5 blur-[150px]" />
          <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[500px] h-[300px] rounded-full bg-purple/5 blur-[120px]" />
        </div>

        <div className="relative z-10 mx-auto max-w-2xl text-center">
          <div className="mb-8">
            <Image
              src="/icon.png"
              alt="Waves app icon"
              width={80}
              height={80}
              className="mx-auto rounded-[18px] shadow-xl shadow-cyan/15"
            />
          </div>
          <h2 className="text-4xl font-bold tracking-tight text-white sm:text-5xl">
            Ready to find your{" "}
            <span className="bg-gradient-to-r from-cyan via-blue to-purple bg-clip-text text-transparent">
              flow
            </span>
            ?
          </h2>
          <p className="mt-4 text-lg text-white/50">
            Download Waves and let AI-generated music keep you in the zone.
          </p>
          <div className="mt-8 flex flex-col items-center gap-4">
            <a
              href="#"
              className="glow-button inline-flex items-center gap-2.5 rounded-full px-8 py-3.5 text-base font-semibold text-white"
            >
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11Z" />
              </svg>
              Download for macOS
            </a>
            <span className="text-sm text-white/30">
              Available for macOS 15.4+
            </span>
          </div>
        </div>
      </section>

      {/* ==================== FOOTER ==================== */}
      <footer className="border-t border-white/5 px-6 py-8">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 sm:flex-row">
          <div className="flex items-center gap-2.5">
            <Image
              src="/icon.png"
              alt="Waves"
              width={24}
              height={24}
              className="rounded-md"
            />
            <span className="text-sm font-medium text-white/60">Waves</span>
          </div>
          <p className="text-sm text-white/30">
            Built by Lyrn &middot; &copy; {new Date().getFullYear()}
          </p>
        </div>
      </footer>
    </div>
  );
}
