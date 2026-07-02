'use client';

import { useEffect, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';

function CallbackHandler() {
  const searchParams = useSearchParams();

  useEffect(() => {
    const id = searchParams.get('id');
    const first_name = searchParams.get('first_name') || '';
    const last_name = searchParams.get('last_name') || '';
    const photo_url = searchParams.get('photo_url') || '';

    if (id) {
      // Build display name combining first and last name
      const displayName = last_name ? `${first_name} ${last_name}`.trim() : first_name;
      
      // Redirect to the Flutter application custom deep link schema
      const appRedirectUrl = `spotme://auth?id=${id}&first_name=${encodeURIComponent(displayName)}&photo_url=${encodeURIComponent(photo_url)}`;
      
      window.location.href = appRedirectUrl;
    }
  }, [searchParams]);

  return (
    <div className="min-h-screen bg-black flex flex-col items-center justify-center text-white px-4">
      <div className="text-center space-y-6">
        <div className="relative flex h-12 w-12 mx-auto justify-center items-center">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-cyan-400 opacity-75"></span>
          <div className="relative inline-flex rounded-full h-8 w-8 bg-cyan-500 items-center justify-center">
            <svg className="w-4 h-4 text-white animate-spin" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
        </div>
        <div className="space-y-2">
          <h3 className="text-xl font-bold text-neutral-200">Authenticating...</h3>
          <p className="text-sm text-neutral-500">Passing credentials back to the SpotMe application.</p>
        </div>
      </div>
    </div>
  );
}

export default function TelegramCallback() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-black flex items-center justify-center text-white">
        <div className="text-center text-neutral-400">Loading callback...</div>
      </div>
    }>
      <CallbackHandler />
    </Suspense>
  );
}
