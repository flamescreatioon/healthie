import { NextResponse } from 'next/server';
import { clearSessionCookie, revokeCurrentSession } from '@/server/auth/session';

export async function POST(request: Request) {
  await revokeCurrentSession(request);
  await clearSessionCookie();
  return NextResponse.json({ status: 'signed_out' });
}
