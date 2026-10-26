import { NextResponse } from 'next/server';
import { z } from 'zod';
import { registerUserAccount, setSessionCookie } from '@/server/auth/session';

const registerSchema = z.object({
  email: z.string().email('Enter a valid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  displayName: z.string().max(80).optional().nullable(),
});

export async function POST(request: Request) {
  try {
    const raw = await request.json();
    const parsed = registerSchema.safeParse(raw);
    if (!parsed.success) {
      const firstIssue = parsed.error.issues[0];
      return NextResponse.json(
        {
          error: 'validation_failed',
          message: firstIssue?.message ?? 'Invalid registration details',
          field: firstIssue?.path[0] ?? 'email',
        },
        { status: 422 },
      );
    }

    const { user, rawToken, expiresAt } = await registerUserAccount(parsed.data);
    await setSessionCookie(rawToken, expiresAt);

    return NextResponse.json(
      {
        user,
        token: rawToken,
        expires_at: expiresAt,
      },
      { status: 201 },
    );
  } catch (err) {
    if (err instanceof Error && err.message === 'EMAIL_EXISTS') {
      return NextResponse.json(
        {
          error: 'email_exists',
          message: 'An account with this email already exists.',
          field: 'email',
        },
        { status: 409 },
      );
    }
    return NextResponse.json(
      {
        error: 'server_error',
        message: 'Could not create account. Please try again.',
      },
      { status: 500 },
    );
  }
}
