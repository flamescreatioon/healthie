/**
 * Reading context model (1:1 port of `reading_context.dart`).
 *
 * Every contextual field is optional — the user is never forced to answer a
 * context question to log a value.
 */

export type BodyPostureWire = 'sitting' | 'lying_down' | 'standing';

export interface BodyPostureSpec {
  readonly wireName: BodyPostureWire;
  readonly label: string;
}

export const BODY_POSTURES: readonly BodyPostureSpec[] = [
  { wireName: 'sitting', label: 'Sitting' },
  { wireName: 'lying_down', label: 'Lying down' },
  { wireName: 'standing', label: 'Standing' },
] as const;

export type MeasurementArmWire = 'left' | 'right';

export interface MeasurementArmSpec {
  readonly wireName: MeasurementArmWire;
  readonly label: string;
}

export const MEASUREMENT_ARMS: readonly MeasurementArmSpec[] = [
  { wireName: 'left', label: 'Left Arm' },
  { wireName: 'right', label: 'Right Arm' },
] as const;

export type ReadingCircumstanceWire =
  | 'resting'
  | 'post_exercise'
  | 'before_medication'
  | 'after_medication'
  | 'stressed'
  | 'fasting';

export interface ReadingCircumstanceSpec {
  readonly wireName: ReadingCircumstanceWire;
  readonly label: string;
}

export const READING_CIRCUMSTANCES: readonly ReadingCircumstanceSpec[] = [
  { wireName: 'resting', label: 'Resting' },
  { wireName: 'post_exercise', label: 'Post-exercise' },
  { wireName: 'before_medication', label: 'Before medication' },
  { wireName: 'after_medication', label: 'After medication' },
  { wireName: 'stressed', label: 'Stressed' },
  { wireName: 'fasting', label: 'Fasting' },
] as const;

export type WeightTimeOfDayWire = 'morning_fasting' | 'post_meal' | 'evening';

export interface WeightTimeOfDaySpec {
  readonly wireName: WeightTimeOfDayWire;
  readonly label: string;
}

export const WEIGHT_TIMES_OF_DAY: readonly WeightTimeOfDaySpec[] = [
  { wireName: 'morning_fasting', label: 'Morning fasting' },
  { wireName: 'post_meal', label: 'Post-meal' },
  { wireName: 'evening', label: 'Evening' },
] as const;

export interface MeasurementContext {
  readonly posture?: BodyPostureWire;
  readonly arm?: MeasurementArmWire;
  readonly circumstances?: readonly ReadingCircumstanceWire[];
  readonly weightTimeOfDay?: WeightTimeOfDayWire;
  readonly notes?: string;
  readonly device?: string;
}

export const EMPTY_MEASUREMENT_CONTEXT: MeasurementContext = {};

const VALID_POSTURES = new Set<string>(BODY_POSTURES.map((p) => p.wireName));
const VALID_ARMS = new Set<string>(MEASUREMENT_ARMS.map((a) => a.wireName));
const VALID_CIRCUMSTANCES = new Set<string>(READING_CIRCUMSTANCES.map((c) => c.wireName));
const VALID_WEIGHT_SLOTS = new Set<string>(WEIGHT_TIMES_OF_DAY.map((w) => w.wireName));

export function contextFromJson(raw: unknown): MeasurementContext {
  if (!raw || typeof raw !== 'object') return EMPTY_MEASUREMENT_CONTEXT;
  const obj = raw as Record<string, unknown>;

  const posture =
    typeof obj.posture === 'string' && VALID_POSTURES.has(obj.posture)
      ? (obj.posture as BodyPostureWire)
      : undefined;

  const arm =
    typeof obj.arm === 'string' && VALID_ARMS.has(obj.arm)
      ? (obj.arm as MeasurementArmWire)
      : undefined;

  const circumstances = Array.isArray(obj.circumstances)
    ? Array.from(
        new Set(
          obj.circumstances.filter(
            (c): c is ReadingCircumstanceWire =>
              typeof c === 'string' && VALID_CIRCUMSTANCES.has(c),
          ),
        ),
      ).sort()
    : undefined;

  const weightTimeOfDay =
    typeof obj.weight_time_of_day === 'string' && VALID_WEIGHT_SLOTS.has(obj.weight_time_of_day)
      ? (obj.weight_time_of_day as WeightTimeOfDayWire)
      : undefined;

  const notes =
    typeof obj.notes === 'string' && obj.notes.trim().length > 0
      ? obj.notes.trim()
      : undefined;

  const device =
    typeof obj.device === 'string' && obj.device.trim().length > 0
      ? obj.device.trim()
      : undefined;

  return {
    ...(posture ? { posture } : {}),
    ...(arm ? { arm } : {}),
    ...(circumstances && circumstances.length > 0 ? { circumstances } : {}),
    ...(weightTimeOfDay ? { weightTimeOfDay } : {}),
    ...(notes ? { notes } : {}),
    ...(device ? { device } : {}),
  };
}

export function contextToJson(ctx?: MeasurementContext): Record<string, unknown> {
  if (!ctx) return {};
  const result: Record<string, unknown> = {};
  if (ctx.posture) result.posture = ctx.posture;
  if (ctx.arm) result.arm = ctx.arm;
  if (ctx.circumstances && ctx.circumstances.length > 0) {
    result.circumstances = [...new Set(ctx.circumstances)].sort();
  }
  if (ctx.weightTimeOfDay) result.weight_time_of_day = ctx.weightTimeOfDay;
  if (ctx.notes && ctx.notes.trim().length > 0) result.notes = ctx.notes.trim();
  if (ctx.device && ctx.device.trim().length > 0) result.device = ctx.device.trim();
  return result;
}
