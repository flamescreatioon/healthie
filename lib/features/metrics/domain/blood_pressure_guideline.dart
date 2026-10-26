/// Blood-pressure interpretation against a named clinical guideline.
///
/// Healthie **screens** blood pressure; it does not diagnose. Every
/// classification here is a screening category from a published guideline, and
/// the guideline's identity and version travel with the result so that a
/// future guideline update does not require rewriting the analytics engine.
///
/// Two rules govern everything below:
///
/// 1. **Never mix thresholds from different guidelines.** One guideline, one
///    decision tree, evaluated in order.
/// 2. **Safety alerts are per-reading and independent of averages.** Averages
///    must never be used to soften an individual dangerous reading.
library;

/// The screening categories defined by the AHA/ACC 2017 guideline.
enum BpCategory {
  normal('normal', 'Normal', 0),
  elevated('elevated', 'Elevated', 1),
  stage1Hypertension('stage_1_hypertension', 'Stage 1 Hypertension', 2),
  stage2Hypertension('stage_2_hypertension', 'Stage 2 Hypertension', 3),
  hypertensiveCrisis('hypertensive_crisis', 'Hypertensive Crisis', 4);

  const BpCategory(this.wireName, this.label, this.severity);

  /// The stable persisted name.
  final String wireName;

  /// The label shown to the user.
  final String label;

  /// Higher means more severe. Used for ordering, not for colour.
  final int severity;

  static BpCategory fromWireName(String wireName) => BpCategory.values
      .firstWhere(
        (category) => category.wireName == wireName,
        orElse: () => BpCategory.normal,
      );
}

/// How urgent an individual reading is.
enum BpSafetyLevel {
  /// Nothing beyond the standard screening guidance.
  none,

  /// Worth re-checking with correct technique.
  caution,

  /// Repeat immediately; seek care if it persists or symptoms are present.
  urgent,
}

/// A named clinical guideline that can classify a blood-pressure reading.
///
/// Implement this to add another guideline (for example, the 2024 ESC
/// guideline) without touching the analytics engine.
abstract class BpGuideline {
  /// A stable identifier, e.g. `aha_acc_2017`.
  String get id;

  /// The display name of the guideline, e.g. `AHA/ACC 2017`.
  String get name;

  /// Classifies one reading.
  BpCategory classify({required int systolic, required int diastolic});

  /// The target the guideline treats as the healthy reference, in mmHg.
  int get targetSystolic;

  /// The target the guideline treats as the healthy reference, in mmHg.
  int get targetDiastolic;
}

/// The US AHA/ACC 2017 guideline for high blood pressure in adults.
///
/// Decision rules, applied in order:
///
/// - **Hypertensive crisis** — systolic above 180 *and/or* diastolic above 120.
/// - **Stage 2 hypertension** — systolic at least 140 *or* diastolic at least 90.
/// - **Stage 1 hypertension** — systolic 130–139 *or* diastolic 80–89.
/// - **Elevated** — systolic 120–129 *and* diastolic below 80.
/// - **Normal** — systolic below 120 *and* diastolic below 80.
///
/// The ordering matters: because "or" governs the elevated stages, a reading
/// of 125/85 is *Stage 1*, not *Elevated*, and 118/85 is *Stage 1*, not
/// *Normal*.
class AhaAcc2017Guideline implements BpGuideline {
  const AhaAcc2017Guideline();

  @override
  String get id => 'aha_acc_2017';

  @override
  String get name => 'AHA/ACC 2017';

  @override
  int get targetSystolic => 120;

  @override
  int get targetDiastolic => 80;

  @override
  BpCategory classify({required int systolic, required int diastolic}) {
    if (systolic > 180 || diastolic > 120) {
      return BpCategory.hypertensiveCrisis;
    }
    if (systolic >= 140 || diastolic >= 90) {
      return BpCategory.stage2Hypertension;
    }
    if ((systolic >= 130 && systolic <= 139) ||
        (diastolic >= 80 && diastolic <= 89)) {
      return BpCategory.stage1Hypertension;
    }
    if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
      return BpCategory.elevated;
    }
    return BpCategory.normal;
  }
}

/// The guideline Healthie ships with.
const BpGuideline defaultBpGuideline = AhaAcc2017Guideline();

/// The safety guidance attached to one reading.
class BpSafetyAssessment {
  const BpSafetyAssessment({
    required this.level,
    required this.headline,
    required this.guidance,
  });

  /// No special guidance needed.
  static const BpSafetyAssessment none = BpSafetyAssessment(
    level: BpSafetyLevel.none,
    headline: 'Clinical Safeguard Protocol',
    guidance:
        'Readings above 180 systolic or 120 diastolic prompt rapid '
        're-verification guidance and instant emergency consultation '
        'safeguards.',
  );

  /// How urgent the reading is.
  final BpSafetyLevel level;

  /// The headline shown with the alert.
  final String headline;

  /// The body copy shown with the alert.
  final String guidance;

  /// Whether the UI should surface this alert prominently.
  bool get requiresAttention => level != BpSafetyLevel.none;
}

/// Assesses a single reading for safety, independently of any trend or
/// average.
///
/// A reading is never softened because the user's 30-day average looks fine.
///
/// Either value may be absent while the user is still typing. A dangerous
/// systolic must raise the alert on its own, without waiting for the
/// diastolic to be entered.
BpSafetyAssessment assessBloodPressureSafety({
  int? systolic,
  int? diastolic,
}) {
  final crisis = (systolic != null && systolic > 180) ||
      (diastolic != null && diastolic > 120);
  if (crisis) {
    return const BpSafetyAssessment(
      level: BpSafetyLevel.urgent,
      headline: 'Immediate Action Guidance',
      guidance:
          'This reading is above 180/120. Wait at least one minute and repeat '
          'the measurement using the recommended technique. If it stays this '
          'high, contact your healthcare professional promptly. If you have '
          'chest pain, shortness of breath, weakness, numbness, vision '
          'changes, or difficulty speaking, seek emergency medical care '
          'immediately rather than waiting for another reading.',
    );
  }
  final high = (systolic != null && systolic >= 140) ||
      (diastolic != null && diastolic >= 90);
  if (high) {
    return const BpSafetyAssessment(
      level: BpSafetyLevel.caution,
      headline: 'Re-check With Correct Technique',
      guidance:
          'This reading is in a high range. Rest for five minutes, sit with '
          'your back supported and feet flat, keep your arm at heart level, '
          'and measure again before deciding what to do.',
    );
  }
  return BpSafetyAssessment.none;
}

/// Classifies a reading with the default guideline.
BpCategory classifyBloodPressure({
  required int systolic,
  required int diastolic,
}) =>
    defaultBpGuideline.classify(systolic: systolic, diastolic: diastolic);
