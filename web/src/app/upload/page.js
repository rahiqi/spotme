"use client";

import { useState } from 'react';
import Link from 'next/link';

export default function UploadPage() {
  const [file, setFile] = useState(null);
  const [secret, setSecret] = useState('');
  const [status, setStatus] = useState('idle'); // idle, uploading, success, error
  const [message, setMessage] = useState('');

  const handleDragOver = (e) => {
    e.preventDefault();
  };

  const handleDrop = (e) => {
    e.preventDefault();
    const droppedFile = e.dataTransfer.files[0];
    if (droppedFile && droppedFile.name.endsWith('.apk')) {
      setFile(droppedFile);
      setStatus('idle');
      setMessage('');
    } else {
      setStatus('error');
      setMessage('Invalid file type. Please select an Android APK (.apk) file.');
    }
  };

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile && selectedFile.name.endsWith('.apk')) {
      setFile(selectedFile);
      setStatus('idle');
      setMessage('');
    } else {
      setStatus('error');
      setMessage('Invalid file type. Please select an Android APK (.apk) file.');
    }
  };

  const handleUpload = async (e) => {
    e.preventDefault();
    if (!file) {
      setStatus('error');
      setMessage('Please select an APK file first.');
      return;
    }
    if (!secret) {
      setStatus('error');
      setMessage('Please enter your administrator secret key.');
      return;
    }

    setStatus('uploading');
    setMessage('Uploading release package...');

    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('secret', secret);

      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      });

      const data = await res.json();

      if (res.ok && data.success) {
        setStatus('success');
        setMessage(`APK uploaded successfully! Saved as: ${data.fileName}`);
        setFile(null);
      } else {
        setStatus('error');
        setMessage(data.error || 'Upload failed. Check secret key and file format.');
      }
    } catch (err) {
      setStatus('error');
      setMessage(err.message || 'An error occurred during upload.');
    }
  };

  return (
    <div className="relative min-h-screen bg-black text-neutral-200 selection:bg-violet-500 selection:text-white flex flex-col overflow-hidden">
      {/* Background Gradients */}
      <div className="absolute top-[-20%] left-[-10%] w-[60%] h-[60%] rounded-full bg-violet-900/10 blur-[150px] pointer-events-none"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-indigo-900/10 blur-[150px] pointer-events-none"></div>

      {/* Grid Pattern overlay */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#1f1f1f0a_1px,transparent_1px),linear-gradient(to_bottom,#1f1f1f0a_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)] pointer-events-none"></div>

      {/* Header */}
      <header className="sticky top-0 z-50 w-full border-b border-neutral-900 bg-black/60 backdrop-blur-lg">
        <div className="mx-auto max-w-7xl px-6 h-16 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-violet-600 to-indigo-600 flex items-center justify-center shadow-lg shadow-violet-500/20 group-hover:scale-105 transition-transform">
              <span className="font-bold text-white text-sm tracking-wider">SM</span>
            </div>
            <span className="font-bold text-lg text-white tracking-tight">SpotMe</span>
          </Link>
          <Link href="/" className="text-sm text-neutral-400 hover:text-white transition-colors flex items-center gap-1">
            ← Back to Homepage
          </Link>
        </div>
      </header>

      {/* Main Container */}
      <main className="flex-1 flex items-center justify-center px-6 py-12 md:py-24">
        <div className="w-full max-w-lg p-8 rounded-3xl border border-neutral-800 bg-gradient-to-b from-neutral-900/50 to-neutral-950/20 backdrop-blur-xl relative overflow-hidden space-y-8">
          
          {/* Ambient glow inside card */}
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-80 h-80 rounded-full bg-violet-600/5 blur-[80px] pointer-events-none"></div>

          <div className="text-center space-y-2 relative z-10">
            <h1 className="text-2xl md:text-3xl font-extrabold text-white tracking-tight">Upload Android APK</h1>
            <p className="text-neutral-400 text-sm">
              Publish a locally compiled release build directly to the download repository.
            </p>
          </div>

          <form onSubmit={handleUpload} className="space-y-6 relative z-10">
            {/* Secret Input */}
            <div className="space-y-2">
              <label className="text-xs font-bold uppercase tracking-wider text-neutral-400">Secret Admin Key</label>
              <input
                type="password"
                value={secret}
                onChange={(e) => setSecret(e.target.value)}
                placeholder="Enter administrator password"
                className="w-full px-4 py-3 rounded-xl border border-neutral-800 bg-neutral-950 text-white placeholder-neutral-600 focus:outline-none focus:border-violet-500 transition-colors text-sm"
                required
              />
            </div>

            {/* File Dropzone */}
            <div className="space-y-2">
              <label className="text-xs font-bold uppercase tracking-wider text-neutral-400">Select Release File</label>
              
              <div
                onDragOver={handleDragOver}
                onDrop={handleDrop}
                onClick={() => document.getElementById('file-input').click()}
                className={`border-2 border-dashed rounded-2xl p-8 text-center cursor-pointer transition-all duration-300 ${
                  file 
                    ? 'border-violet-500/50 bg-violet-500/5' 
                    : 'border-neutral-800 hover:border-neutral-700 bg-neutral-950/40 hover:bg-neutral-950/60'
                }`}
              >
                <input
                  id="file-input"
                  type="file"
                  accept=".apk"
                  onChange={handleFileChange}
                  className="hidden"
                />
                
                {file ? (
                  <div className="space-y-2">
                    <div className="text-3xl">📦</div>
                    <div className="text-sm font-semibold text-white break-all">{file.name}</div>
                    <div className="text-xs text-neutral-400">{(file.size / (1024 * 1024)).toFixed(2)} MB</div>
                    <div className="text-xs text-violet-400 font-medium">Click or drag another file to replace</div>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <div className="text-3xl text-neutral-600">📥</div>
                    <div className="text-sm text-neutral-300 font-medium">Drag and drop your APK file here</div>
                    <div className="text-xs text-neutral-500">or click to browse local files</div>
                    <div className="text-[10px] text-neutral-600 uppercase tracking-widest pt-2">Only .apk files allowed</div>
                  </div>
                )}
              </div>
            </div>

            {/* Status Feedback */}
            {status !== 'idle' && (
              <div className={`p-4 rounded-xl text-xs font-medium border ${
                status === 'uploading' 
                  ? 'bg-violet-500/5 border-violet-500/20 text-violet-300' 
                  : status === 'success'
                    ? 'bg-emerald-500/5 border-emerald-500/20 text-emerald-400'
                    : 'bg-rose-500/5 border-rose-500/20 text-rose-400'
              }`}>
                <div className="flex items-center gap-2">
                  {status === 'uploading' && <span className="w-1.5 h-1.5 rounded-full bg-violet-400 animate-ping"></span>}
                  <span>{message}</span>
                </div>
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={status === 'uploading'}
              className="w-full py-4 rounded-xl bg-white hover:bg-neutral-200 text-black font-semibold text-sm transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-lg hover:shadow-white/5"
            >
              {status === 'uploading' ? 'Publishing Package...' : 'Publish APK'}
            </button>
          </form>

        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-neutral-900 bg-black/80 py-8 text-xs text-neutral-500 mt-auto">
        <div className="mx-auto max-w-7xl px-6 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span className="font-bold text-white">SpotMe App</span>
            <span>© 2026. All rights reserved.</span>
          </div>
          <div>
            <span>Protected Admin Endpoint</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
