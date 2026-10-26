/**
 * Canonical unit system for Healthie (1:1 port of `lib/core/units/unit.dart`).
 *
 * Every stored measurement carries a unit. Values are stored in the metric's
 * canonical unit (kg for mass, cm for length, mmHg for pressure, °C for
 * temperature, % for ratio, bpm for rate, mg/dL for concentration) and
 * converted only at the boundaries: once when the user types a value, and
 * once when a value is rendered.
 */

export type UnitKind =
  | 'mass'
  | 'length'
  | 'pressure'
  | 'temperature'
  | 'ratio'
  | 'rate'
  | 'concentration';

export type UnitSymbol =
  | 'kg'
  | 'lb'
  | 'cm'
  | 'in'
  | 'm'
  | 'mmHg'
  | 'bpm'
  | '%'
  | '°C'
  | '°F'
  | 'mg/dL'
  | 'mmol/L';

export interface UnitSpec {
  readonly id: string;
  readonly symbol: UnitSymbol;
  readonly kind: UnitKind;
}

export const Units = {
  kilogram: { id: 'kilogram', symbol: 'kg', kind: 'mass' },
  pound: { id: 'pound', symbol: 'lb', kind: 'mass' },
  centimetre: { id: 'centimetre', symbol: 'cm', kind: 'length' },
  inch: { id: 'inch', symbol: 'in', kind: 'length' },
  meter: { id: 'meter', symbol: 'm', kind: 'length' },
  millimetreOfMercury: { id: 'millimetreOfMercury', symbol: 'mmHg', kind: 'pressure' },
  beatsPerMinute: { id: 'beatsPerMinute', symbol: 'bpm', kind: 'rate' },
  percent: { id: 'percent', symbol: '%', kind: 'ratio' },
  celsius: { id: 'celsius', symbol: '°C', kind: 'temperature' },
  fahrenheit: { id: 'fahrenheit', symbol: '°F', kind: 'temperature' },
  milligramPerDecilitre: { id: 'milligramPerDecilitre', symbol: 'mg/dL', kind: 'concentration' },
  millimolePerLitre: { id: 'millimolePerLitre', symbol: 'mmol/L', kind: 'concentration' },
} as const satisfies Record<string, UnitSpec>;

export const ALL_UNITS: readonly UnitSpec[] = Object.values(Units);

export function unitFromSymbol(symbol: string): UnitSpec {
  const found = ALL_UNITS.find((u) => u.symbol === symbol);
  return found ?? Units.percent;
}

export function canonicalUnitFor(kind: UnitKind): UnitSpec {
  switch (kind) {
    case 'mass':
      return Units.kilogram;
    case 'length':
      return Units.centimetre;
    case 'pressure':
      return Units.millimetreOfMercury;
    case 'temperature':
      return Units.celsius;
    case 'ratio':
      return Units.percent;
    case 'rate':
      return Units.beatsPerMinute;
    case 'concentration':
      return Units.milligramPerDecilitre;
  }
}

export function isCanonicalUnit(unit: UnitSpec): boolean {
  return unit.symbol === canonicalUnitFor(unit.kind).symbol;
}

/**
 * Converts `value` expressed in `from` into the canonical unit of its kind.
 */
export function toCanonical(value: number, from: UnitSpec | UnitSymbol): number {
  const symbol = typeof from === 'string' ? from : from.symbol;
  switch (symbol) {
    case 'kg':
      return value;
    case 'lb':
      return value * 0.45359237;
    case 'cm':
      return value;
    case 'in':
      return value * 2.54;
    case 'm':
      return value * 100;
    case 'mmHg':
    case 'bpm':
    case '%':
    case '°C':
    case 'mg/dL':
      return value;
    case '°F':
      return ((value - 32) * 5) / 9;
    case 'mmol/L':
      return value * 18.0182;
  }
}

/**
 * Converts a canonical `value` into `to`.
 */
export function fromCanonical(canonical: number, to: UnitSpec | UnitSymbol): number {
  const symbol = typeof to === 'string' ? to : to.symbol;
  switch (symbol) {
    case 'kg':
      return canonical;
    case 'lb':
      return canonical / 0.45359237;
    case 'cm':
      return canonical;
    case 'in':
      return canonical / 2.54;
    case 'm':
      return canonical / 100;
    case 'mmHg':
    case 'bpm':
    case '%':
    case '°C':
    case 'mg/dL':
      return canonical;
    case '°F':
      return (canonical * 9) / 5 + 32;
    case 'mmol/L':
      return canonical / 18.0182;
  }
}

/**
 * Converts `value` from one unit to another within the same dimension.
 * Throws Error when dimensions differ.
 */
export function convert(
  value: number,
  from: UnitSpec | UnitSymbol,
  to: UnitSpec | UnitSymbol,
): number {
  const fromSpec = typeof from === 'string' ? unitFromSymbol(from) : from;
  const toSpec = typeof to === 'string' ? unitFromSymbol(to) : to;
  if (fromSpec.symbol === toSpec.symbol) return value;
  if (fromSpec.kind !== toSpec.kind) {
    throw new Error(
      `Cannot convert ${fromSpec.symbol} to ${toSpec.symbol}: different dimensions.`,
    );
  }
  return fromCanonical(toCanonical(value, fromSpec), toSpec);
}

/**
 * Rounds `value` to `decimals` places, avoiding `-0.0`.
 */
export function roundTo(value: number, decimals: number): number {
  const factor = Math.pow(10, decimals);
  const rounded = Math.round(value * factor) / factor;
  return Object.is(rounded, -0) || rounded === 0 ? 0 : rounded;
}

/**
 * Locale-hardened numeric parser (`docs/web/05-manual-entry.md`).
 *
 * Accepts:
 * - Standard decimal point (`"72.4"`)
 * - Decimal comma (`"72,4"`)
 * - Thousands separators (`"1,234.5"` or `"1.234,5"` or `"1 234,5"`)
 * Rejects empty, non-numeric, NaN, or Infinity inputs.
 */
export function parseNumeric(raw: string | number | null | undefined): number | null {
  if (raw === null || raw === undefined) return null;
  if (typeof raw === 'number') {
    return Number.isFinite(raw) ? raw : null;
  }
  const trimmed = raw.trim().replace(/\s+/g, '');
  if (!trimmed) return null;

  let normalized = trimmed;
  const lastComma = trimmed.lastIndexOf(',');
  const lastDot = trimmed.lastIndexOf('.');

  if (lastComma !== -1 && lastDot !== -1) {
    if (lastComma > lastDot) {
      // European format: 1.234,56 -> 1234.56
      normalized = trimmed.replace(/\./g, '').replace(',', '.');
    } else {
      // US/UK format: 1,234.56 -> 1234.56
      normalized = trimmed.replace(/,/g, '');
    }
  } else if (lastComma !== -1) {
    const commaCount = (trimmed.match(/,/g) ?? []).length;
    if (commaCount === 1) {
      // Single comma is treated as a decimal separator (e.g. "72,4")
      normalized = trimmed.replace(',', '.');
    } else {
      // Multiple commas with no dot -> thousands separators
      normalized = trimmed.replace(/,/g, '');
    }
  }

  if (!/^[+-]?(\d+\.?\d*|\.\d+)$/.test(normalized)) {
    return null;
  }

  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

export function formatValue(value: number, precision = 0): string {
  const safe = roundTo(value, precision);
  return safe.toFixed(precision);
}

export function formatSigned(value: number, precision = 0): string {
  const safe = roundTo(value, precision);
  const sign = safe > 0 ? '+' : safe < 0 ? '−' : '';
  return `${sign}${Math.abs(safe).toFixed(precision)}`;
}

export function formatBloodPressure(
  systolic: number,
  diastolic?: number | null,
): string {
  const sys = formatValue(systolic, 0);
  const dia = diastolic === null || diastolic === undefined ? '—' : formatValue(diastolic, 0);
  return `${sys}/${dia}`;
}
