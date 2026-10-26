// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'medication.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Medication {

 String get id; String get name; String get dosageInstructions; String get schedule; DateTime get startDate; DateTime? get endDate; bool get active;
/// Create a copy of Medication
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicationCopyWith<Medication> get copyWith => _$MedicationCopyWithImpl<Medication>(this as Medication, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Medication;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Medication&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.dosageInstructions, _this.dosageInstructions) || other.dosageInstructions == _this.dosageInstructions)&&(identical(other.schedule, _this.schedule) || other.schedule == _this.schedule)&&(identical(other.startDate, _this.startDate) || other.startDate == _this.startDate)&&(identical(other.endDate, _this.endDate) || other.endDate == _this.endDate)&&(identical(other.active, _this.active) || other.active == _this.active));
}


@override
int get hashCode {
  final _this = this as Medication;
  return Object.hash(runtimeType,_this.id,_this.name,_this.dosageInstructions,_this.schedule,_this.startDate,_this.endDate,_this.active);
}

@override
String toString() {
  final _this = this as Medication;
  return 'Medication(id: ${_this.id}, name: ${_this.name}, dosageInstructions: ${_this.dosageInstructions}, schedule: ${_this.schedule}, startDate: ${_this.startDate}, endDate: ${_this.endDate}, active: ${_this.active})';
}


}

/// @nodoc
abstract mixin class $MedicationCopyWith<$Res>  {
  factory $MedicationCopyWith(Medication value, $Res Function(Medication) _then) = _$MedicationCopyWithImpl;
@useResult
$Res call({
 String id, String name, String dosageInstructions, String schedule, DateTime startDate, DateTime? endDate, bool active
});




}
/// @nodoc
class _$MedicationCopyWithImpl<$Res>
    implements $MedicationCopyWith<$Res> {
  _$MedicationCopyWithImpl(this._self, this._then);

  final Medication _self;
  final $Res Function(Medication) _then;

/// Create a copy of Medication
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? dosageInstructions = null,Object? schedule = null,Object? startDate = null,Object? endDate = freezed,Object? active = null,}) {
  return _then(Medication(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,dosageInstructions: null == dosageInstructions ? _self.dosageInstructions : dosageInstructions // ignore: cast_nullable_to_non_nullable
as String,schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Medication].
extension MedicationPatterns on Medication {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Medication value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Medication() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Medication value)  $default,){
final _that = this;
switch (_that) {
case _Medication():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Medication value)?  $default,){
final _that = this;
switch (_that) {
case _Medication() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String dosageInstructions,  String schedule,  DateTime startDate,  DateTime? endDate,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Medication() when $default != null:
return $default(_that.id,_that.name,_that.dosageInstructions,_that.schedule,_that.startDate,_that.endDate,_that.active);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String dosageInstructions,  String schedule,  DateTime startDate,  DateTime? endDate,  bool active)  $default,) {final _that = this;
switch (_that) {
case _Medication():
return $default(_that.id,_that.name,_that.dosageInstructions,_that.schedule,_that.startDate,_that.endDate,_that.active);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String dosageInstructions,  String schedule,  DateTime startDate,  DateTime? endDate,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _Medication() when $default != null:
return $default(_that.id,_that.name,_that.dosageInstructions,_that.schedule,_that.startDate,_that.endDate,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _Medication extends Medication {
  const _Medication({required this.id, required this.name, required this.dosageInstructions, required this.schedule, required this.startDate, required this.endDate, this.active = true}): super._();
  

@override final  String id;
@override final  String name;
@override final  String dosageInstructions;
@override final  String schedule;
@override final  DateTime startDate;
@override final  DateTime? endDate;
@override@JsonKey() final  bool active;

/// Create a copy of Medication
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicationCopyWith<_Medication> get copyWith => __$MedicationCopyWithImpl<_Medication>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Medication&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.dosageInstructions, dosageInstructions) || other.dosageInstructions == dosageInstructions)&&(identical(other.schedule, schedule) || other.schedule == schedule)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,dosageInstructions,schedule,startDate,endDate,active);
}

@override
String toString() {
    return 'Medication(id: $id, name: $name, dosageInstructions: $dosageInstructions, schedule: $schedule, startDate: $startDate, endDate: $endDate, active: $active)';
}


}

/// @nodoc
abstract mixin class _$MedicationCopyWith<$Res> implements $MedicationCopyWith<$Res> {
  factory _$MedicationCopyWith(_Medication value, $Res Function(_Medication) _then) = __$MedicationCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String dosageInstructions, String schedule, DateTime startDate, DateTime? endDate, bool active
});




}
/// @nodoc
class __$MedicationCopyWithImpl<$Res>
    implements _$MedicationCopyWith<$Res> {
  __$MedicationCopyWithImpl(this._self, this._then);

  final _Medication _self;
  final $Res Function(_Medication) _then;

/// Create a copy of Medication
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? dosageInstructions = null,Object? schedule = null,Object? startDate = null,Object? endDate = freezed,Object? active = null,}) {
  return _then(_Medication(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,dosageInstructions: null == dosageInstructions ? _self.dosageInstructions : dosageInstructions // ignore: cast_nullable_to_non_nullable
as String,schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as String,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$MedicationLog {

 String get id; String get medicationId; DateTime get scheduledAt; MedicationLogStatus get status; DateTime get recordedAt; String? get notes;
/// Create a copy of MedicationLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicationLogCopyWith<MedicationLog> get copyWith => _$MedicationLogCopyWithImpl<MedicationLog>(this as MedicationLog, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MedicationLog;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedicationLog&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.medicationId, _this.medicationId) || other.medicationId == _this.medicationId)&&(identical(other.scheduledAt, _this.scheduledAt) || other.scheduledAt == _this.scheduledAt)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.recordedAt, _this.recordedAt) || other.recordedAt == _this.recordedAt)&&(identical(other.notes, _this.notes) || other.notes == _this.notes));
}


@override
int get hashCode {
  final _this = this as MedicationLog;
  return Object.hash(runtimeType,_this.id,_this.medicationId,_this.scheduledAt,_this.status,_this.recordedAt,_this.notes);
}

@override
String toString() {
  final _this = this as MedicationLog;
  return 'MedicationLog(id: ${_this.id}, medicationId: ${_this.medicationId}, scheduledAt: ${_this.scheduledAt}, status: ${_this.status}, recordedAt: ${_this.recordedAt}, notes: ${_this.notes})';
}


}

/// @nodoc
abstract mixin class $MedicationLogCopyWith<$Res>  {
  factory $MedicationLogCopyWith(MedicationLog value, $Res Function(MedicationLog) _then) = _$MedicationLogCopyWithImpl;
@useResult
$Res call({
 String id, String medicationId, DateTime scheduledAt, MedicationLogStatus status, DateTime recordedAt, String? notes
});




}
/// @nodoc
class _$MedicationLogCopyWithImpl<$Res>
    implements $MedicationLogCopyWith<$Res> {
  _$MedicationLogCopyWithImpl(this._self, this._then);

  final MedicationLog _self;
  final $Res Function(MedicationLog) _then;

/// Create a copy of MedicationLog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? medicationId = null,Object? scheduledAt = null,Object? status = null,Object? recordedAt = null,Object? notes = freezed,}) {
  return _then(MedicationLog(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,medicationId: null == medicationId ? _self.medicationId : medicationId // ignore: cast_nullable_to_non_nullable
as String,scheduledAt: null == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MedicationLogStatus,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MedicationLog].
extension MedicationLogPatterns on MedicationLog {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedicationLog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedicationLog() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedicationLog value)  $default,){
final _that = this;
switch (_that) {
case _MedicationLog():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedicationLog value)?  $default,){
final _that = this;
switch (_that) {
case _MedicationLog() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String medicationId,  DateTime scheduledAt,  MedicationLogStatus status,  DateTime recordedAt,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedicationLog() when $default != null:
return $default(_that.id,_that.medicationId,_that.scheduledAt,_that.status,_that.recordedAt,_that.notes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String medicationId,  DateTime scheduledAt,  MedicationLogStatus status,  DateTime recordedAt,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _MedicationLog():
return $default(_that.id,_that.medicationId,_that.scheduledAt,_that.status,_that.recordedAt,_that.notes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String medicationId,  DateTime scheduledAt,  MedicationLogStatus status,  DateTime recordedAt,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _MedicationLog() when $default != null:
return $default(_that.id,_that.medicationId,_that.scheduledAt,_that.status,_that.recordedAt,_that.notes);case _:
  return null;

}
}

}

/// @nodoc


class _MedicationLog extends MedicationLog {
  const _MedicationLog({required this.id, required this.medicationId, required this.scheduledAt, required this.status, required this.recordedAt, this.notes}): super._();
  

@override final  String id;
@override final  String medicationId;
@override final  DateTime scheduledAt;
@override final  MedicationLogStatus status;
@override final  DateTime recordedAt;
@override final  String? notes;

/// Create a copy of MedicationLog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicationLogCopyWith<_MedicationLog> get copyWith => __$MedicationLogCopyWithImpl<_MedicationLog>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedicationLog&&(identical(other.id, id) || other.id == id)&&(identical(other.medicationId, medicationId) || other.medicationId == medicationId)&&(identical(other.scheduledAt, scheduledAt) || other.scheduledAt == scheduledAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.notes, notes) || other.notes == notes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,medicationId,scheduledAt,status,recordedAt,notes);
}

@override
String toString() {
    return 'MedicationLog(id: $id, medicationId: $medicationId, scheduledAt: $scheduledAt, status: $status, recordedAt: $recordedAt, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$MedicationLogCopyWith<$Res> implements $MedicationLogCopyWith<$Res> {
  factory _$MedicationLogCopyWith(_MedicationLog value, $Res Function(_MedicationLog) _then) = __$MedicationLogCopyWithImpl;
@override @useResult
$Res call({
 String id, String medicationId, DateTime scheduledAt, MedicationLogStatus status, DateTime recordedAt, String? notes
});




}
/// @nodoc
class __$MedicationLogCopyWithImpl<$Res>
    implements _$MedicationLogCopyWith<$Res> {
  __$MedicationLogCopyWithImpl(this._self, this._then);

  final _MedicationLog _self;
  final $Res Function(_MedicationLog) _then;

/// Create a copy of MedicationLog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? medicationId = null,Object? scheduledAt = null,Object? status = null,Object? recordedAt = null,Object? notes = freezed,}) {
  return _then(_MedicationLog(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,medicationId: null == medicationId ? _self.medicationId : medicationId // ignore: cast_nullable_to_non_nullable
as String,scheduledAt: null == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MedicationLogStatus,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
