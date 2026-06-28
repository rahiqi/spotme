'use client';

import { useState, useEffect } from 'react';

export default function ServerStatus() {
  const [status, setStatus] = useState('checking'); // 'checking' | 'online' | 'offline'

  useEffect(() => {
    async function checkStatus() {
      try {
        const res = await fetch('http://localhost:8080/health', { mode: 'cors' });
        if (res.ok) {
          const data = await res.json();
          if (data.status === 'healthy') {
            setStatus('online');
            return;
          }
        }
        setStatus('offline');
      } catch (e) {
        setStatus('offline');
      }
    }

    checkStatus();
    const interval = setInterval(checkStatus, 15000); // Check every 15 seconds
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="flex items-center gap-2 px-3 py-1.5 rounded-full border border-neutral-800 bg-neutral-900/60 backdrop-blur-md">
      <span className="relative flex h-2 w-2">
        {status === 'online' && (
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
        )}
        <span className={`relative inline-flex rounded-full h-2 w-2 ${
          status === 'online' 
            ? 'bg-emerald-500' 
            : status === 'offline' 
            ? 'bg-rose-500' 
            : 'bg-amber-500'
        }`}></span>
      </span>
      <span className="text-xs font-medium text-neutral-400 select-none">
        {status === 'online' ? 'Backend Live' : status === 'offline' ? 'Backend Offline' : 'Checking Backend'}
      </span>
    </div>
  );
}
