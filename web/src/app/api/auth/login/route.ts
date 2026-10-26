import { NextResponse } from 'next/server';
import { z } from 'zod';
import { authenticateUserAccount, setSessionCookie } from '@/server/auth/session';

const loginSchema = z.object({
  email: z.string().email('Enter a valid email address'),
  password: z.string().min(1, 'Enter your password'),
});

export async function POST(request: Request) {
  try {
    const raw = await request.json();
    const parsed = loginSchema.safeParse(raw);
    if (!parsed.success) {
      const firstIssue = parsed.error.issues[0];
      return NextResponse.json(
        {
          error: 'validation_failed',
          message: firstIssue?.message ?? 'Invalid credentials',
          field: firstIssue?.path[0] ?? 'email',
        },
        { status: 422 },
      );
    }

    const result = await authenticateUserAccount(parsed.data);
    if (!result) {
      return NextResponse.json(
        {
          error: 'invalid_credentials',
          message: 'Invalid email or password.',
        },
        { status: 401 },
      );
    }

    await setSessionCookie(result.rawToken, result.expiresAt);
    return NextResponse.json({
      user: result.user,
      token: result.rawToken,
      expires_at: result.expiresAt,
    });
  } catch {
    return NextResponse.json(
      {
        error: 'server_error',
        message: 'Could not sign in. Please try again.',
      },
      { status: 500 },
    );
  }
}
