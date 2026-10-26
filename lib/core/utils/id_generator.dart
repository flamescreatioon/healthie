/// Device-generated identifiers.
///
/// The device, not the server, is the authority for a record's identifier: the
/// phone may be offline for days, and a record created on it must have a
/// stable identity before it ever reaches a backend.
library;

import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// A new random identifier.
String newId() => _uuid.v4();
