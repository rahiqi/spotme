import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import ServerStatus from './components/ServerStatus';

export const dynamic = 'force-dynamic';

// Server-side function to retrieve latest APK information
function getLatestApkInfo() {
  const artifactsDir = '/app/artifacts';
  try {
    if (!fs.existsSync(artifactsDir)) return null;
    const files = fs.readdirSync(artifactsDir)
      .filter(f => f.startsWith('app-') && f.endsWith('.apk'));
    if (files.length === 0) return null;
    files.sort();
    const latestFile = files[files.length - 1];
    const filePath = path.join(artifactsDir, latestFile);
    const stats = fs.statSync(filePath);
    
    const parts = latestFile.replace('.apk', '').split('-');
    const gitSha = parts[1] || 'unknown';
    const rawTime = parts[2] || '';
    
    let formattedTime = 'Recent Build';
    if (rawTime.length >= 15) {
      const y = rawTime.slice(0, 4);
      const m = rawTime.slice(4, 6);
      const d = rawTime.slice(6, 8);
      const hh = rawTime.slice(9, 11);
      const mm = rawTime.slice(11, 13);
      formattedTime = `${y}-${m}-${d} ${hh}:${mm}`;
    }

    // Compute checksum
    const fileBuffer = fs.readFileSync(filePath);
    const sha256 = crypto.createHash('sha256').update(fileBuffer).digest('hex');

    return {
      filename: latestFile,
      gitSha,
      formattedTime,
      sizeMb: (stats.size / (1024 * 1024)).toFixed(2),
      sha256,
    };
  } catch (e) {
    console.error("Error reading apk info:", e);
    return null;
  }
}

export default function Home() {
  const apkInfo = getLatestApkInfo();

  return (
    <div className="relative min-h-screen bg-black text-neutral-200 selection:bg-violet-500 selection:text-white overflow-hidden">
      {/* Background Gradients */}
      <div className="absolute top-[-20%] left-[-10%] w-[60%] h-[60%] rounded-full bg-violet-900/10 blur-[150px] pointer-events-none"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-900/10 blur-[150px] pointer-events-none"></div>

      {/* Grid Pattern overlay */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#1f1f1f0a_1px,transparent_1px),linear-gradient(to_bottom,#1f1f1f0a_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)] pointer-events-none"></div>

      {/* Header */}
      <header className="sticky top-0 z-50 w-full border-b border-neutral-900 bg-black/60 backdrop-blur-lg">
        <div className="mx-auto max-w-7xl px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-violet-600 to-indigo-600 flex items-center justify-center shadow-lg shadow-violet-500/20">
              <span className="font-bold text-white text-sm tracking-wider">SM</span>
            </div>
            <span className="font-bold text-lg text-white tracking-tight">SpotMe</span>
          </div>

          <nav className="hidden md:flex items-center gap-6 text-sm text-neutral-400">
            <a href="#features" className="hover:text-white transition-colors">Features</a>
            <a href="#download" className="hover:text-white transition-colors">Download</a>
            <a href="#architecture" className="hover:text-white transition-colors">Architecture</a>
          </nav>

          <div className="flex items-center gap-3">
            <ServerStatus />
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <main className="mx-auto max-w-7xl px-6 pt-16 pb-24 md:pt-24 lg:pt-32">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-16 items-center">
          
          {/* Left Column: Headline and Call to Actions */}
          <div className="lg:col-span-7 space-y-8">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-violet-500/20 bg-violet-500/5 text-xs text-violet-400 font-medium">
              <span>🚀 Real-Time Connection Built in Rust & Flutter</span>
            </div>

            <h1 className="text-4xl md:text-6xl font-black tracking-tight text-white leading-[1.1]">
              Share your path. <br />
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-violet-400 via-indigo-400 to-cyan-400">
                Stay in sync.
              </span>
            </h1>

            <p className="text-neutral-400 text-lg md:text-xl leading-relaxed max-w-2xl">
              An instant, 1-to-1 location streaming service. Zero account registrations. Zero trackers. Just input your name, share a session request, and view your partner on a dark-themed live map.
            </p>

            <div className="flex flex-wrap items-center gap-4">
              <a
                href="#download"
                className="px-6 py-3 rounded-xl bg-violet-600 hover:bg-violet-500 text-white font-medium text-sm transition-all duration-300 transform hover:-translate-y-0.5 shadow-lg shadow-violet-500/25 hover:shadow-violet-500/40"
              >
                Get Latest APK
              </a>
              <a
                href="#features"
                className="px-6 py-3 rounded-xl border border-neutral-800 hover:border-neutral-700 bg-neutral-950 text-neutral-300 hover:text-white font-medium text-sm transition-all duration-300"
              >
                Explore Features
              </a>
            </div>
          </div>

          {/* Right Column: Live App Simulator / Mockup */}
          <div className="lg:col-span-5 relative flex justify-center">
            {/* Phone Screen Mockup */}
            <div className="relative w-[300px] h-[580px] rounded-[40px] border-4 border-neutral-800 bg-neutral-950 overflow-hidden shadow-2xl shadow-violet-500/5 flex flex-col">
              
              {/* Camera Notch */}
              <div className="absolute top-2 left-1/2 transform -translate-x-1/2 w-32 h-4 rounded-full bg-neutral-900 z-50"></div>
              
              {/* App Map Simulation */}
              <div className="relative flex-1 bg-[#0b0c10] overflow-hidden flex flex-col">
                
                {/* Simulated OSM Map Grid background */}
                <div className="absolute inset-0 bg-[radial-gradient(#1f2025_1px,transparent_1px)] [background-size:16px_16px] opacity-60"></div>
                
                {/* Simulated Roads/Paths */}
                <svg className="absolute inset-0 w-full h-full opacity-20" xmlns="http://www.w3.org/2000/svg">
                  <path d="M -20,100 L 320,150 M 50,-20 L 120,600 M 250,-20 L 200,600 M -20,400 L 320,380 M -20,480 C 100,480 150,520 320,530" fill="none" stroke="#52525b" strokeWidth="2" />
                  <path d="M 50,150 L 250,380" fill="none" stroke="#8b5cf6" strokeWidth="3" strokeDasharray="6 4" className="animate-[dash_8s_linear_infinite]" />
                </svg>

                {/* Animated Connection Path */}
                <style>{`
                  @keyframes dash {
                    to {
                      stroke-dashoffset: -20;
                    }
                  }
                  @keyframes pulse-ring {
                    0% { transform: scale(0.6); opacity: 0; }
                    50% { opacity: 0.5; }
                    100% { transform: scale(1.6); opacity: 0; }
                  }
                `}</style>

                {/* Simulated User 1: You */}
                <div className="absolute top-[140px] left-[45px] flex flex-col items-center">
                  <div className="relative">
                    <span className="absolute -inset-1.5 rounded-full bg-violet-500/30 animate-[pulse-ring_2s_cubic-bezier(0.215,0.61,0.355,1)_infinite]"></span>
                    <div className="relative w-8 h-8 rounded-full border border-violet-400 bg-neutral-900 flex items-center justify-center overflow-hidden">
                      <span className="text-[10px] font-bold text-violet-400">YOU</span>
                    </div>
                  </div>
                  <span className="text-[9px] bg-neutral-900/80 px-1.5 py-0.5 rounded border border-neutral-800 text-neutral-300 mt-1 select-none font-medium">You</span>
                </div>

                {/* Simulated User 2: Partner */}
                <div className="absolute top-[370px] left-[235px] flex flex-col items-center">
                  <div className="relative">
                    <span className="absolute -inset-1.5 rounded-full bg-cyan-500/30 animate-[pulse-ring_2s_cubic-bezier(0.215,0.61,0.355,1)_infinite_1s]"></span>
                    <div className="relative w-8 h-8 rounded-full border border-cyan-400 bg-neutral-900 flex items-center justify-center overflow-hidden">
                      <span className="text-[10px] font-bold text-cyan-400">PTN</span>
                    </div>
                  </div>
                  <span className="text-[9px] bg-neutral-900/80 px-1.5 py-0.5 rounded border border-neutral-800 text-neutral-300 mt-1 select-none font-medium">Partner</span>
                </div>

                {/* Glassmorphic App Interface HUD overlays */}
                {/* Top Banner */}
                <div className="absolute top-8 inset-x-3 p-3 rounded-2xl border border-neutral-800/80 bg-neutral-900/70 backdrop-blur-md flex items-center justify-between">
                  <div className="flex flex-col">
                    <span className="text-[10px] font-bold text-violet-400 uppercase tracking-wider">SpotMe Live</span>
                    <span className="text-[9px] text-neutral-400">Stream paired successfully</span>
                  </div>
                  <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></div>
                </div>

                {/* Bottom Actions card */}
                <div className="absolute bottom-4 inset-x-3 p-3 rounded-2xl border border-neutral-800/80 bg-neutral-900/70 backdrop-blur-md space-y-2">
                  <div className="flex items-center justify-between text-[10px]">
                    <span className="text-neutral-400 font-medium">Distance:</span>
                    <span className="text-white font-bold">142 meters</span>
                  </div>
                  <div className="h-0.5 bg-neutral-800 rounded">
                    <div className="h-full w-2/3 bg-gradient-to-r from-violet-500 to-indigo-500 rounded"></div>
                  </div>
                  <button className="w-full py-1.5 bg-rose-600/20 hover:bg-rose-600/30 border border-rose-500/20 text-rose-300 rounded-lg text-[9px] font-semibold transition-colors uppercase tracking-wider">
                    Disconnect
                  </button>
                </div>

              </div>
            </div>
            
            {/* Ambient glow behind mockup */}
            <div className="absolute -inset-4 rounded-[48px] bg-gradient-to-tr from-violet-500/10 to-indigo-500/10 blur-xl pointer-events-none -z-10"></div>
          </div>

        </div>
      </main>

      {/* Features Section */}
      <section id="features" className="border-t border-neutral-900 bg-neutral-950/40 py-24">
        <div className="mx-auto max-w-7xl px-6">
          <div className="text-center max-w-3xl mx-auto space-y-4 mb-16">
            <h2 className="text-3xl font-extrabold text-white tracking-tight">Designed for Privacy & Speed</h2>
            <p className="text-neutral-400">
              SpotMe features a dual-stack configuration combining Rust’s raw network performance with Flutter’s seamless hardware execution.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            
            {/* Feature 1 */}
            <div className="p-6 rounded-2xl border border-neutral-900 bg-neutral-900/20 hover:bg-neutral-900/40 hover:border-neutral-800 transition-all duration-300 group">
              <div className="w-10 h-10 rounded-xl bg-violet-500/10 border border-violet-500/20 text-violet-400 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                ⚡
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Tokio WebSocket</h3>
              <p className="text-neutral-400 text-sm leading-relaxed">
                Powered by Axum and Tokio broadcast loops. Delivers coordinates with sub-100ms latency directly to your paired client.
              </p>
            </div>

            {/* Feature 2 */}
            <div className="p-6 rounded-2xl border border-neutral-900 bg-neutral-900/20 hover:bg-neutral-900/40 hover:border-neutral-800 transition-all duration-300 group">
              <div className="w-10 h-10 rounded-xl bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                🧭
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Background Isolate</h3>
              <p className="text-neutral-400 text-sm leading-relaxed">
                Foreground Android service registers coordinate streaming updates even when the device screen is locked or the app is closed.
              </p>
            </div>

            {/* Feature 3 */}
            <div className="p-6 rounded-2xl border border-neutral-900 bg-neutral-900/20 hover:bg-neutral-900/40 hover:border-neutral-800 transition-all duration-300 group">
              <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/20 text-cyan-400 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                🗺️
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Dark Matter Tiles</h3>
              <p className="text-neutral-400 text-sm leading-relaxed">
                OpenStreetMap rendered via CartoDB Dark Matter layouts. Beautiful visual display with zero configuration or API key requirements.
              </p>
            </div>

            {/* Feature 4 */}
            <div className="p-6 rounded-2xl border border-neutral-900 bg-neutral-900/20 hover:bg-neutral-900/40 hover:border-neutral-800 transition-all duration-300 group">
              <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-400 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                🛡️
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Privacy Centric</h3>
              <p className="text-neutral-400 text-sm leading-relaxed">
                Zero central history storage. Handshake coordinates are routed in-memory and discarded immediately upon disconnection.
              </p>
            </div>

          </div>
        </div>
      </section>

      {/* Download Section */}
      <section id="download" className="py-24 border-t border-neutral-900">
        <div className="mx-auto max-w-4xl px-6">
          <div className="p-8 md:p-12 rounded-3xl border border-neutral-800 bg-gradient-to-b from-neutral-900/50 to-neutral-950/20 backdrop-blur-xl relative overflow-hidden flex flex-col md:flex-row md:items-center justify-between gap-12">
            
            {/* Glowing spot background */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-80 h-80 rounded-full bg-violet-600/5 blur-[80px] pointer-events-none"></div>

            <div className="space-y-6 max-w-lg relative z-10">
              <h2 className="text-2xl md:text-3xl font-extrabold text-white">Get the Android Client</h2>
              <p className="text-neutral-400 text-sm leading-relaxed">
                Download the release APK package directly. Make sure to allow installation from unknown sources in your Android security settings.
              </p>

              {apkInfo ? (
                <div className="space-y-2 border-t border-neutral-900 pt-4 text-xs font-mono text-neutral-500">
                  <div className="flex justify-between">
                    <span>Version (Git SHA):</span>
                    <span className="text-neutral-300">{apkInfo.gitSha}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Compiled At:</span>
                    <span className="text-neutral-300">{apkInfo.formattedTime}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>File Size:</span>
                    <span className="text-neutral-300">{apkInfo.sizeMb} MB</span>
                  </div>
                  <div className="flex flex-col gap-1 mt-2">
                    <span>SHA-256 Checksum:</span>
                    <span className="text-violet-400 select-all break-all">{apkInfo.sha256}</span>
                  </div>
                </div>
              ) : (
                <div className="p-4 rounded-xl bg-amber-500/5 border border-amber-500/10 text-xs text-amber-400 font-mono">
                  ⚠️ No release APK build detected in volume. Ensure that the Android build task has populated the artifacts output folder.
                </div>
              )}
            </div>

            <div className="flex flex-col items-center justify-center gap-4 relative z-10">
              <a
                href="/api/download"
                className="w-full md:w-auto px-8 py-4 rounded-2xl bg-white hover:bg-neutral-200 text-black font-semibold text-center text-sm transition-all duration-300 transform hover:-translate-y-0.5 shadow-xl shadow-white/10"
              >
                Download Latest APK
              </a>
              <span className="text-[10px] text-neutral-500 text-center">
                Compatible with Android 8.0 (Oreo) and above
              </span>
            </div>

          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-neutral-900 bg-black/80 py-12 text-sm text-neutral-500">
        <div className="mx-auto max-w-7xl px-6 flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-2">
            <span className="font-bold text-white">SpotMe App</span>
            <span className="text-xs">© 2026. All rights reserved.</span>
          </div>

          <div className="flex items-center gap-6">
            <span>Powered by Next.js & Tailwind CSS v4</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
