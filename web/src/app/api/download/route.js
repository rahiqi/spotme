import { NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

export async function GET() {
  const artifactsDir = '/app/artifacts';
  
  try {
    if (!fs.existsSync(artifactsDir)) {
      return new NextResponse('Artifacts directory not found', { status: 404 });
    }

    const files = fs.readdirSync(artifactsDir)
      .filter(f => f.startsWith('app-') && f.endsWith('.apk'));

    if (files.length === 0) {
      return new NextResponse('No APK release found', { status: 404 });
    }

    // Sort files by file modification time (mtime) descending
    const filesWithStats = files.map(file => {
      const filePath = path.join(artifactsDir, file);
      const stats = fs.statSync(filePath);
      return { file, mtime: stats.mtime.getTime() };
    });
    filesWithStats.sort((a, b) => b.mtime - a.mtime);

    const latestFile = filesWithStats[0].file;
    const filePath = path.join(artifactsDir, latestFile);

    const fileStream = fs.readFileSync(filePath);
    
    return new NextResponse(fileStream, {
      headers: {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Disposition': `attachment; filename="${latestFile}"`,
      },
    });
  } catch (e) {
    return new NextResponse(`Error: ${e.message}`, { status: 500 });
  }
}
