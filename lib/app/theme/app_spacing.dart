/// The spacing scale.
///
/// One scale, used everywhere. If a value you want is not on this list, the
/// layout is wrong — not the scale.
library;

/// 8-point base rhythm, with a 4-point half step for tight pairs.
abstract final class AppSpacing {
  /// 4dp — between a label and its value.
  static const double xs = 4;

  /// 8dp — between related chips or small controls.
  static const double sm = 8;

  /// 12dp — inside compact controls.
  static const double md = 12;

  /// 16dp — screen padding, card padding, gap between cards.
  static const double lg = 16;

  /// 24dp — section separation.
  static const double xl = 24;

  /// 32dp — between major blocks.
  static const double xxl = 32;

  /// 48dp — minimum touch target, and the height of a primary button.
  static const double touchTarget = 48;
}

/// Corner radii.
abstract final class AppRadius {
  /// 12dp — inputs and buttons.
  static const double control = 12;

  /// 16dp — cards.
  static const double card = 16;

  /// 20dp — hero cards.
  static const double hero = 20;

  /// 9999dp — chips and pills.
  static const double pill = 9999;
}

/// The minimum tap target, per the accessibility guidelines.
const double kMinTouchTarget = 48;
