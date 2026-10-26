import { NextResponse } from 'next/server';
import { resolveRequestUser } from '@/server/auth/session';

export async function GET(request: Request) {
  const user = await resolveRequestUser(request);
  if (!user) {
    return NextResponse.json({ authenticated: false, user: null }, { status: 200 });
  }
  return NextResponse.json({ authenticated: true, user }, { status: 200 });
}
