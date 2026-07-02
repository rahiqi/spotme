'use client';

import { useEffect, useRef } from 'react';

export default function TelegramLogin() {
  const widgetRef = useRef(null);

  useEffect(() => {
    // Read the bot username from environment variables, fallback to SpotMeAuthBot
    const botUsername = process.env.NEXT_PUBLIC_TELEGRAM_BOT_USERNAME || 'SpotMeAuthBot';
    
    const script = document.createElement('script');
    script.src = 'https://telegram.org/js/telegram-widget.js?22';
    script.async = true;
    script.setAttribute('data-telegram-login', botUsername);
    script.setAttribute('data-size', 'large');
    script.setAttribute('data-radius', '16');
    script.setAttribute('data-auth-url', '/auth/telegram-callback');
    script.setAttribute('data-request-access', 'write');

    if (widgetRef.current) {
      widgetRef.current.innerHTML = ''; // Clear previous widget if any
      widgetRef.current.appendChild(script);
    }
  }, []);

  return (
    <div className="min-h-screen bg-black flex flex-col items-center justify-center text-white px-4 selection:bg-cyan-500 selection:text-white">
      {/* Background radial gradient decoration */}
      <div className="absolute top-[-20%] left-[-10%] w-[60%] h-[60%] rounded-full bg-cyan-900/10 blur-[150px] pointer-events-none"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-blue-900/10 blur-[150px] pointer-events-none"></div>

      <div className="max-w-md w-full p-8 rounded-[30px] border border-neutral-900 bg-neutral-950/70 backdrop-blur-xl text-center space-y-8 shadow-2xl relative z-10">
        <div className="space-y-3">
          <h2 className="text-3xl font-extrabold bg-clip-text text-transparent bg-gradient-to-r from-cyan-400 to-blue-500">
            Telegram Login
          </h2>
          <p className="text-sm text-neutral-400 leading-relaxed">
            Link your Telegram account to SpotMe to automatically import your display name and profile picture.
          </p>
        </div>

        <div className="flex justify-center py-4 bg-neutral-900/30 rounded-2xl border border-neutral-900">
          <div ref={widgetRef}></div>
        </div>

        <p className="text-xs text-neutral-500">
          SpotMe does not store your password. Your identity is verified securely by Telegram.
        </p>
      </div>
    </div>
  );
}
