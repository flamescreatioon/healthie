/**
 * First-party Cookie-Session Auth backed by Neon (`docs/web/03-cloud-sync-and-auth.md`).
 *
 * - HttpOnly, Secure, SameSite=Lax session cookies
 * - Password hashing uses `$2y$12$...` bcrypt (100% compatible with Laravel's
 *   `Hash::make` / `Hash::check` on Mobile) with backward-compatible scrypt fallback.
 * - Supports `Authorization: Bearer <token>` (including Sanctum `<id>|<token>` format)
 *   so mobile (`/api/v1/*`) and browser clients share the same database & auth seamlessly.
 * - Never logs tokens, session IDs, or auth headers.
 */

import { createHash, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { cookies } from 'next/headers';
import type { NextRequest } from 'next/server';
import {
  createSessionInStore,
  createUserInStore,
  findSessionByTokenHash,
  findUserByEmail,
  revokeSessionByTokenHash,
  type ServerUser,
} from '@/server/db/store';

export const SESSION_COOKIE_NAME = 'healthie_session';
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30; // 30 days

export function hashPassword(password: string): string {
  const hash = bcrypt.hashSync(password, 12);
  // Emit `$2y$` prefix so PHP/Laravel `Hash::check` and Node `bcryptjs` both accept it
  return hash.replace(/^\$2[ab]\$/, '$2y$');
}

export function verifyPassword(password: string, storedHash: string): boolean {
  if (storedHash.startsWith('$2y$') || storedHash.startsWith('$2b$') || storedHash.startsWith('$2a$')) {
    const normalized = storedHash.replace(/^\$2y\$/, '$2a$');
    return bcrypt.compareSync(password, normalized);
  }
  const [salt, keyHex] = storedHash.split(':');
  if (!salt || !keyHex) return false;
  const keyBuffer = Buffer.from(keyHex, 'hex');
  const derivedBuffer = scryptSync(password, salt, 64);
  if (keyBuffer.length !== derivedBuffer.length) return false;
  return timingSafeEqual(keyBuffer, derivedBuffer);
}

export function hashSessionToken(rawToken: string): string {
  const cleanToken = rawToken.includes('|')
    ? (rawToken.split('|')[1] ?? rawToken)
    : rawToken;
  return createHash('sha256').update(cleanToken).digest('hex');
}

export async function registerUserAccount(params: {
  email: string;
  password: string;
  displayName?: string | null;
}): Promise<{ user: Omit<ServerUser, 'passwordHash'>; rawToken: string; expiresAt: string }> {
  const id = crypto.randomUUID();
  const nowIso = new Date().toISOString();
  const user = await createUserInStore({
    id,
    email: params.email,
    displayName: params.displayName?.trim() || null,
    passwordHash: hashPassword(params.password),
    createdAt: nowIso,
  });

  const { rawToken, expiresAt } = await issueSessionForUser(user.id);
  return {
    user: {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      createdAt: user.createdAt,
    },
    rawToken,
    expiresAt,
  };
}

export async function authenticateUserAccount(params: {
  email: string;
  password: string;
}): Promise<{ user: Omit<ServerUser, 'passwordHash'>; rawToken: string; expiresAt: string } | null> {
  const user = await findUserByEmail(params.email);
  if (!user) return null;
  if (!verifyPassword(params.password, user.passwordHash)) return null;

  const { rawToken, expiresAt } = await issueSessionForUser(user.id);
  return {
    user: {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      createdAt: user.createdAt,
    },
    rawToken,
    expiresAt,
  };
}

export async function issueSessionForUser(
  userId: string,
): Promise<{ rawToken: string; expiresAt: string }> {
  const rawToken = randomBytes(32).toString('hex');
  const tokenHash = hashSessionToken(rawToken);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_MS).toISOString();

  await createSessionInStore({
    id: crypto.randomUUID(),
    userId,
    tokenHash,
    expiresAt,
    createdAt: now.toISOString(),
  });

  return { rawToken, expiresAt };
}

export async function setSessionCookie(rawToken: string, expiresAtIso: string): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(SESSION_COOKIE_NAME, rawToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    expires: new Date(expiresAtIso),
  });
}

export async function clearSessionCookie(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.delete(SESSION_COOKIE_NAME);
}

export async function resolveRequestUser(
  req?: NextRequest | Request,
): Promise<Omit<ServerUser, 'passwordHash'> | null> {
  let rawToken: string | undefined;

  if (req) {
    const authHeader = req.headers.get('authorization');
    if (authHeader?.toLowerCase().startsWith('bearer ')) {
      rawToken = authHeader.slice(7).trim();
    }
    if (!rawToken) {
      const cookieHeader = req.headers.get('cookie') ?? '';
      const match = new RegExp(`(?:^|;\\s*)${SESSION_COOKIE_NAME}=([^;]+)`).exec(
        cookieHeader,
      );
      if (match?.[1]) {
        rawToken = decodeURIComponent(match[1]);
      }
    }
  }

  if (!rawToken) {
    try {
      const cookieStore = await cookies();
      rawToken = cookieStore.get(SESSION_COOKIE_NAME)?.value;
    } catch {
      // Called outside Next.js request context (e.g. direct unit test)
    }
  }

  if (!rawToken) return null;
  const found = await findSessionByTokenHash(hashSessionToken(rawToken));
  if (!found) return null;

  return {
    id: found.user.id,
    email: found.user.email,
    displayName: found.user.displayName,
    createdAt: found.user.createdAt,
  };
}

export async function revokeCurrentSession(req?: NextRequest | Request): Promise<void> {
  let rawToken: string | undefined;
  if (req) {
    const authHeader = req.headers.get('authorization');
    if (authHeader?.toLowerCase().startsWith('bearer ')) {
      rawToken = authHeader.slice(7).trim();
    }
  }
  if (!rawToken) {
    try {
      const cookieStore = await cookies();
      rawToken = cookieStore.get(SESSION_COOKIE_NAME)?.value;
    } catch {
      // ignore
    }
  }
  if (rawToken) {
    await revokeSessionByTokenHash(hashSessionToken(rawToken));
  }
}
