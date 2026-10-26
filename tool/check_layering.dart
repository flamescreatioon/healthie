/// Checks that the architecture's layering rule holds.
///
/// The rule is simple: dependencies point inward.
///
/// ```
/// presentation  ->  domain  <-  data
/// ```
///
/// - `presentation` may import `domain`, never `data`.
/// - `domain` may import the **pure** core helpers (`core/units`,
///   `core/utils`, `core/error`) but never `data`, never `presentation`, and
///   never the infrastructure in `core/database` or `core/sync`.
/// - `data` may import `domain` and `core`, never `presentation`.
/// - `lib/app/` is the composition root. It is the only place that wires
///   concrete implementations to abstractions, so it may import anything.
///
/// `import_linter` is no longer published on pub.dev, so this is a
/// dependency-free stand-in that runs the same check from the command line:
///
/// ```
/// dart run tool/check_layering.dart
/// ```
library;

import 'dart:io';

/// A layer, and the layers it is allowed to import.
enum Layer {
  composition,
  presentation,
  domain,
  data,
  core,
}

/// Core packages that hold pure helpers with no infrastructure in them.
///
/// The domain layer may depend on these. The purity is verified below: a
/// package listed here must not import anything outside `dart:` and
/// `package:flutter/foundation.dart`.
const Set<String> pureCorePaths = {
  'core/units',
  'core/utils',
  'core/error',
};

/// Core packages that are infrastructure. Nothing but the data layer may
/// depend on these.
const Set<String> infrastructureCorePaths = {
  'core/database',
  'core/sync',
};

/// The layers a layer may not import.
const Map<Layer, Set<Layer>> forbidden = {
  Layer.presentation: {Layer.data},
  Layer.domain: {Layer.data, Layer.presentation},
  Layer.data: {Layer.presentation},
};

/// Normalizes a path to forward slashes so checks are platform-independent.
String normalize(String path) => path.replaceAll(Platform.pathSeparator, '/');

/// Which layer a file belongs to, decided by exact path-segment match.
Layer? layerOf(String path) {
  final segments = normalize(path).split('/');
  if (segments.contains('app')) return Layer.composition;
  if (segments.contains('presentation')) return Layer.presentation;
  if (segments.contains('domain')) return Layer.domain;
  if (segments.contains('data')) return Layer.data;
  if (segments.contains('core')) return Layer.core;
  return null;
}

bool matchesAny(String path, Set<String> candidates) {
  final normalized = normalize(path);
  return candidates.any((candidate) => normalized.contains(candidate));
}

void main(List<String> arguments) {
  final root = Directory.current;
  final lib = Directory('${root.path}${Platform.pathSeparator}lib');
  if (!lib.existsSync()) {
    stderr.writeln('Run this from the project root.');
    exitCode = 2;
    return;
  }

  final violations = <String>[];
  final files = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.endsWith('.g.dart'))
      .where((file) => !file.path.endsWith('.freezed.dart'))
      .toList();

  for (final file in files) {
    final relative = normalize(file.path.substring(lib.parent.path.length + 1));
    final layer = layerOf(relative);
    if (layer == null) continue;

    final content = file.readAsStringSync();
    final importPattern = RegExp(r'''import\s+['"]([^'"]+)['"]''');

    for (final match in importPattern.allMatches(content)) {
      final target = match.group(1)!;
      if (!target.startsWith('.')) continue;

      final resolved = normalize(_resolve(relative, target));
      final targetLayer = layerOf(resolved);
      if (targetLayer == null) continue;

      if (forbidden[layer]?.contains(targetLayer) ?? false) {
        violations.add(
          '$relative imports $resolved — '
          '${layer.name} may not depend on ${targetLayer.name}.',
        );
      }

      if (layer == Layer.domain &&
          matchesAny(resolved, infrastructureCorePaths)) {
        violations.add(
          '$relative imports $resolved — the domain layer may not reach into '
          'the persistence or sync machinery.',
        );
      }
    }
  }

  violations.addAll(_checkPurity(lib, files));

  if (violations.isEmpty) {
    stdout.writeln('Layering check passed: no inward-pointing violations.');
    return;
  }

  for (final violation in violations) {
    stderr.writeln(violation);
  }
  stderr.writeln('${violations.length} layering violation(s).');
  exitCode = 1;
}

/// Verifies that the packages the domain layer is allowed to depend on are
/// genuinely pure — no Drift, no Supabase, no Riverpod, no Flutter widgets.
List<String> _checkPurity(Directory lib, List<File> files) {
  final violations = <String>[];
  final allowed = RegExp(
    r'''^import\s+['"](dart:[^'"]+|package:flutter/foundation\.dart)['"]''',
  );

  for (final file in files) {
    final relative = normalize(file.path.substring(lib.parent.path.length + 1));
    if (!pureCorePaths.any((path) => relative.startsWith(path))) continue;

    final content = file.readAsStringSync();
    final importPattern = RegExp(r'''^import\s+['"]([^'"]+)['"]''',
        multiLine: true);
    for (final match in importPattern.allMatches(content)) {
      final target = match.group(1)!;
      if (allowed.hasMatch(target)) continue;
      violations.add(
        '$relative imports $target — a pure core package may not depend on '
        'anything outside dart: and package:flutter/foundation.dart.',
      );
    }
  }
  return violations;
}

/// Resolves a relative import against the importing file's directory.
String _resolve(String fromFile, String target) {
  final parts = fromFile.split('/')..removeLast();
  for (final segment in target.split('/')) {
    if (segment == '.') continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(segment);
  }
  return parts.join('/');
}
