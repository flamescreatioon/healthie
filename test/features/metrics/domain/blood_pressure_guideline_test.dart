import 'package:flutter_test/flutter_test.dart';
import 'package:healthie/features/metrics/domain/blood_pressure_guideline.dart';

void main() {
  const guideline = AhaAcc2017Guideline();

  group('AHA/ACC 2017 classification', () {
    test('classifies 118/76 as normal', () {
      expect(
        guideline.classify(systolic: 118, diastolic: 76),
        BpCategory.normal,
      );
    });

    test('classifies 119/79 as normal', () {
      expect(
        guideline.classify(systolic: 119, diastolic: 79),
        BpCategory.normal,
      );
    });

    test('classifies 120/79 as elevated', () {
      expect(
        guideline.classify(systolic: 120, diastolic: 79),
        BpCategory.elevated,
      );
    });

    test('classifies 129/79 as elevated', () {
      expect(
        guideline.classify(systolic: 129, diastolic: 79),
        BpCategory.elevated,
      );
    });

    test('classifies 125/85 as stage 1, not elevated', () {
      // "Or" governs the elevated stages: a diastolic of 85 is Stage 1 even
      // though the systolic is in the elevated band.
      expect(
        guideline.classify(systolic: 125, diastolic: 85),
        BpCategory.stage1Hypertension,
      );
    });

    test('classifies 118/85 as stage 1, not normal', () {
      expect(
        guideline.classify(systolic: 118, diastolic: 85),
        BpCategory.stage1Hypertension,
      );
    });

    test('classifies 130/79 as stage 1', () {
      expect(
        guideline.classify(systolic: 130, diastolic: 79),
        BpCategory.stage1Hypertension,
      );
    });

    test('classifies 139/89 as stage 1', () {
      expect(
        guideline.classify(systolic: 139, diastolic: 89),
        BpCategory.stage1Hypertension,
      );
    });

    test('classifies 140/79 as stage 2', () {
      expect(
        guideline.classify(systolic: 140, diastolic: 79),
        BpCategory.stage2Hypertension,
      );
    });

    test('classifies 119/90 as stage 2', () {
      expect(
        guideline.classify(systolic: 119, diastolic: 90),
        BpCategory.stage2Hypertension,
      );
    });

    test('classifies 181/79 as hypertensive crisis', () {
      expect(
        guideline.classify(systolic: 181, diastolic: 79),
        BpCategory.hypertensiveCrisis,
      );
    });

    test('classifies 119/121 as hypertensive crisis', () {
      expect(
        guideline.classify(systolic: 119, diastolic: 121),
        BpCategory.hypertensiveCrisis,
      );
    });

    test('treats exactly 180/120 as stage 2, not crisis', () {
      expect(
        guideline.classify(systolic: 180, diastolic: 120),
        BpCategory.stage2Hypertension,
      );
    });
  });

  group('safety assessment', () {
    test('a normal reading needs no special guidance', () {
      final assessment = assessBloodPressureSafety(
        systolic: 118,
        diastolic: 76,
      );
      expect(assessment.level, BpSafetyLevel.none);
      expect(assessment.requiresAttention, isFalse);
    });

    test('a stage 2 reading asks the user to re-check', () {
      final assessment = assessBloodPressureSafety(
        systolic: 150,
        diastolic: 95,
      );
      expect(assessment.level, BpSafetyLevel.caution);
    });

    test('a crisis reading asks for immediate action', () {
      final assessment = assessBloodPressureSafety(
        systolic: 185,
        diastolic: 120,
      );
      expect(assessment.level, BpSafetyLevel.urgent);
      expect(assessment.requiresAttention, isTrue);
    });

    test('crisis guidance names the emergency symptoms', () {
      final assessment = assessBloodPressureSafety(
        systolic: 200,
        diastolic: 130,
      );
      expect(assessment.guidance, contains('emergency'));
      expect(assessment.guidance, contains('chest pain'));
    });

    test('crisis guidance asks the user to repeat the measurement', () {
      final assessment = assessBloodPressureSafety(
        systolic: 200,
        diastolic: 130,
      );
      expect(assessment.guidance, contains('one minute'));
    });
  });

  group('guideline identity', () {
    test('identifies itself with a name and version', () {
      expect(guideline.id, 'aha_acc_2017');
      expect(guideline.name, 'AHA/ACC 2017');
    });

    test('exposes the reference target', () {
      expect(guideline.targetSystolic, 120);
      expect(guideline.targetDiastolic, 80);
    });
  });
}
