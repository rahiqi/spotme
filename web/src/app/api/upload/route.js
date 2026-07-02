import { NextResponse } from 'next/server';
import fs from 'fs';
import path from 'path';

export async function POST(request) {
  try {
    const formData = await request.formData();
    const file = formData.get('file');
    const secret = formData.get('secret');

    // Validate upload secret
    const expectedSecret = process.env.UPLOAD_SECRET || 'spotme-admin-secret';
    if (secret !== expectedSecret) {
      return NextResponse.json({ error: 'Unauthorized: Invalid secret key' }, { status: 401 });
    }

    if (!file) {
      return NextResponse.json({ error: 'No file uploaded' }, { status: 400 });
    }

    // Validate file type
    if (!file.name.endsWith('.apk')) {
      return NextResponse.json({ error: 'Only .apk files are allowed' }, { status: 400 });
    }

    const artifactsDir = '/app/artifacts';
    if (!fs.existsSync(artifactsDir)) {
      fs.mkdirSync(artifactsDir, { recursive: true });
    }

    // Generate unique name: app-uploaded-YYYYMMDD_HHMMSS.apk
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    const hh = String(now.getHours()).padStart(2, '0');
    const mm = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');
    
    const fileName = `app-uploaded-${y}${m}${d}_${hh}${mm}${ss}.apk`;
    const filePath = path.join(artifactsDir, fileName);

    // Save file to artifacts directory
    const buffer = Buffer.from(await file.arrayBuffer());
    fs.writeFileSync(filePath, buffer);

    return NextResponse.json({ success: true, fileName });
  } catch (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
