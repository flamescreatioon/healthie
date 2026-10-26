/**
 * Blood-pressure interpretation against the US AHA/ACC 2017 clinical guideline
 * (1:1 port of `blood_pressure_guideline.dart`).
 *
 * Healthie screens blood pressure; it does not diagnose.
 * Safety alerts are per-reading and independent of averages.
 */

export type BpCategoryWire =
  | 'normal'
  | 'elevated'
  | 'stage_1_hypertension'
  | 'stage_2_hypertension'
  | 'hypertensive_crisis';

export interface BpCategorySpec {
  readonly wireName: BpCategoryWire;
  readonly label: string;
  readonly shortLabel: string;
  readonly severity: number;
}

export const BP_CATEGORIES: Record<BpCategoryWire, BpCategorySpec> = {
  normal: {
    wireName: 'normal',
    label: 'Normal',
    shortLabel: 'Optimal',
    severity: 0,
  },
  elevated: {
    wireName: 'elevated',
    label: 'Elevated',
    shortLabel: 'Elevated',
    severity: 1,
  },
  stage_1_hypertension: {
    wireName: 'stage_1_hypertension',
    label: 'Stage 1 Hypertension',
    shortLabel: 'Stage 1',
    severity: 2,
  },
  stage_2_hypertension: {
    wireName: 'stage_2_hypertension',
    label: 'Stage 2 Hypertension',
    shortLabel: 'Stage 2',
    severity: 3,
  },
  hypertensive_crisis: {
    wireName: 'hypertensive_crisis',
    label: 'Hypertensive Crisis',
    shortLabel: 'Seek care',
    severity: 4,
  },
} as const;

export const ALL_BP_CATEGORIES: readonly BpCategorySpec[] = Object.values(BP_CATEGORIES);

export type BpSafetyLevel = 'none' | 'caution' | 'urgent';

export interface BpGuideline {
  readonly id: string;
  readonly name: string;
  readonly targetSystolic: number;
  readonly targetDiastolic: number;
  classify(params: { systolic: number; diastolic: number }): BpCategoryWire;
}

export const ahaAcc2017Guideline: BpGuideline = {
  id: 'aha_acc_2017',
  name: 'AHA/ACC 2017',
  targetSystolic: 120,
  targetDiastolic: 80,
  classify({ systolic, diastolic }): BpCategoryWire {
    if (systolic > 180 || diastolic > 120) {
      return 'hypertensive_crisis';
    }
    if (systolic >= 140 || diastolic >= 90) {
      return 'stage_2_hypertension';
    }
    if ((systolic >= 130 && systolic <= 139) || (diastolic >= 80 && diastolic <= 89)) {
      return 'stage_1_hypertension';
    }
    if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
      return 'elevated';
    }
    return 'normal';
  },
};

export const defaultBpGuideline: BpGuideline = ahaAcc2017Guideline;

export function classifyBloodPressure(params: {
  systolic: number;
  diastolic: number;
}): BpCategoryWire {
  return defaultBpGuideline.classify(params);
}

export interface BpSafetyAssessment {
  readonly level: BpSafetyLevel;
  readonly headline: string;
  readonly guidance: string;
  readonly requiresAttention: boolean;
}

export const BP_SAFETY_NONE: BpSafetyAssessment = {
  level: 'none',
  headline: 'Clinical Safeguard Protocol',
  guidance:
    'Readings above 180 systolic or 120 diastolic prompt rapid re-verification guidance and instant emergency consultation safeguards.',
  requiresAttention: false,
};

export function assessBloodPressureSafety(params: {
  systolic?: number | null;
  diastolic?: number | null;
}): BpSafetyAssessment {
  const { systolic, diastolic } = params;
  const crisis =
    (systolic !== null && systolic !== undefined && systolic > 180) ||
    (diastolic !== null && diastolic !== undefined && diastolic > 120);
  if (crisis) {
    return {
      level: 'urgent',
      headline: 'Immediate Action Guidance',
      guidance:
        'This reading is above 180/120. Wait at least one minute and repeat the measurement using the recommended technique. If it stays this high, contact your healthcare professional promptly. If you have chest pain, shortness of breath, weakness, numbness, vision changes, or difficulty speaking, seek emergency medical care immediately rather than waiting for another reading.',
      requiresAttention: true,
    };
  }
  const high =
    (systolic !== null && systolic !== undefined && systolic >= 140) ||
    (diastolic !== null && diastolic !== undefined && diastolic >= 90);
  if (high) {
    return {
      level: 'caution',
      headline: 'Re-check With Correct Technique',
      guidance:
        'This reading is in a high range. Rest for five minutes, sit with your back supported and feet flat, keep your arm at heart level, and measure again before deciding what to do.',
      requiresAttention: true,
    };
  }
  const low =
    (systolic !== null && systolic !== undefined && systolic < 90) ||
    (diastolic !== null && diastolic !== undefined && diastolic < 60);
  if (low) {
    return {
      level: 'caution',
      headline: 'Low Reading Notice',
      guidance:
        'This reading is below 90/60 mmHg. If you feel dizzy, lightheaded, or faint, sit or lie down and seek medical advice.',
      requiresAttention: true,
    };
  }
  return BP_SAFETY_NONE;
}
