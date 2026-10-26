/**
 * Injectable clock abstraction.
 *
 * Domain functions never call `Date.now()` or `new Date()` directly; they
 * accept a `Date` or a `Clock` so every date boundary, local-day rollup, and
 * sync timestamp is deterministic in unit tests.
 */

export interface Clock {
  now(): Date;
}

export class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }
}

export class FixedClock implements Clock {
  private current: Date;

  constructor(initial: Date | string) {
    this.current = typeof initial === 'string' ? new Date(initial) : new Date(initial.getTime());
  }

  now(): Date {
    return new Date(this.current.getTime());
  }

  advanceMs(ms: number): void {
    this.current = new Date(this.current.getTime() + ms);
  }

  set(next: Date | string): void {
    this.current = typeof next === 'string' ? new Date(next) : new Date(next.getTime());
  }
}

export const systemClock: Clock = new SystemClock();
