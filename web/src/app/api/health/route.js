import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  const backendUrl = process.env.BACKEND_URL || 'http://back:8080';
  
  try {
    // Call the Rust backend's health check endpoint internally
    const res = await fetch(`${backendUrl}/health`, {
      cache: 'no-store',
      signal: AbortSignal.timeout(5000), // Timeout after 5s
    });
    
    if (res.ok) {
      const data = await res.json();
      return NextResponse.json(data);
    }
    
    return NextResponse.json({ status: 'unhealthy' }, { status: 502 });
  } catch (e) {
    return NextResponse.json({ status: 'unhealthy', error: e.message }, { status: 502 });
  }
}
