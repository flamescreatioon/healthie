// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HealthProfile {

 String get id; String? get displayName; DateTime? get dateOfBirth; String? get sex; double? get heightCm; Unit get preferredMassUnit; Unit get preferredLengthUnit; Unit get preferredTemperatureUnit; String? get timeZone; WeightGoalKind get weightGoalKind; int? get targetSystolic; int? get targetDiastolic; DateTime? get targetWeightKg;
/// Create a copy of HealthProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthProfileCopyWith<HealthProfile> get copyWith => _$HealthProfileCopyWithImpl<HealthProfile>(this as HealthProfile, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as HealthProfile;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthProfile&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.dateOfBirth, _this.dateOfBirth) || other.dateOfBirth == _this.dateOfBirth)&&(identical(other.sex, _this.sex) || other.sex == _this.sex)&&(identical(other.heightCm, _this.heightCm) || other.heightCm == _this.heightCm)&&(identical(other.preferredMassUnit, _this.preferredMassUnit) || other.preferredMassUnit == _this.preferredMassUnit)&&(identical(other.preferredLengthUnit, _this.preferredLengthUnit) || other.preferredLengthUnit == _this.preferredLengthUnit)&&(identical(other.preferredTemperatureUnit, _this.preferredTemperatureUnit) || other.preferredTemperatureUnit == _this.preferredTemperatureUnit)&&(identical(other.timeZone, _this.timeZone) || other.timeZone == _this.timeZone)&&(identical(other.weightGoalKind, _this.weightGoalKind) || other.weightGoalKind == _this.weightGoalKind)&&(identical(other.targetSystolic, _this.targetSystolic) || other.targetSystolic == _this.targetSystolic)&&(identical(other.targetDiastolic, _this.targetDiastolic) || other.targetDiastolic == _this.targetDiastolic)&&(identical(other.targetWeightKg, _this.targetWeightKg) || other.targetWeightKg == _this.targetWeightKg));
}


@override
int get hashCode {
  final _this = this as HealthProfile;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.dateOfBirth,_this.sex,_this.heightCm,_this.preferredMassUnit,_this.preferredLengthUnit,_this.preferredTemperatureUnit,_this.timeZone,_this.weightGoalKind,_this.targetSystolic,_this.targetDiastolic,_this.targetWeightKg);
}

@override
String toString() {
  final _this = this as HealthProfile;
  return 'HealthProfile(id: ${_this.id}, displayName: ${_this.displayName}, dateOfBirth: ${_this.dateOfBirth}, sex: ${_this.sex}, heightCm: ${_this.heightCm}, preferredMassUnit: ${_this.preferredMassUnit}, preferredLengthUnit: ${_this.preferredLengthUnit}, preferredTemperatureUnit: ${_this.preferredTemperatureUnit}, timeZone: ${_this.timeZone}, weightGoalKind: ${_this.weightGoalKind}, targetSystolic: ${_this.targetSystolic}, targetDiastolic: ${_this.targetDiastolic}, targetWeightKg: ${_this.targetWeightKg})';
}


}

/// @nodoc
abstract mixin class $HealthProfileCopyWith<$Res>  {
  factory $HealthProfileCopyWith(HealthProfile value, $Res Function(HealthProfile) _then) = _$HealthProfileCopyWithImpl;
@useResult
$Res call({
 String id, String? displayName, DateTime? dateOfBirth, String? sex, double? heightCm, Unit preferredMassUnit, Unit preferredLengthUnit, Unit preferredTemperatureUnit, String? timeZone, WeightGoalKind weightGoalKind, int? targetSystolic, int? targetDiastolic, DateTime? targetWeightKg
});




}
/// @nodoc
class _$HealthProfileCopyWithImpl<$Res>
    implements $HealthProfileCopyWith<$Res> {
  _$HealthProfileCopyWithImpl(this._self, this._then);

  final HealthProfile _self;
  final $Res Function(HealthProfile) _then;

/// Create a copy of HealthProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = freezed,Object? dateOfBirth = freezed,Object? sex = freezed,Object? heightCm = freezed,Object? preferredMassUnit = null,Object? preferredLengthUnit = null,Object? preferredTemperatureUnit = null,Object? timeZone = freezed,Object? weightGoalKind = null,Object? targetSystolic = freezed,Object? targetDiastolic = freezed,Object? targetWeightKg = freezed,}) {
  return _then(HealthProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,sex: freezed == sex ? _self.sex : sex // ignore: cast_nullable_to_non_nullable
as String?,heightCm: freezed == heightCm ? _self.heightCm : heightCm // ignore: cast_nullable_to_non_nullable
as double?,preferredMassUnit: null == preferredMassUnit ? _self.preferredMassUnit : preferredMassUnit // ignore: cast_nullable_to_non_nullable
as Unit,preferredLengthUnit: null == preferredLengthUnit ? _self.preferredLengthUnit : preferredLengthUnit // ignore: cast_nullable_to_non_nullable
as Unit,preferredTemperatureUnit: null == preferredTemperatureUnit ? _self.preferredTemperatureUnit : preferredTemperatureUnit // ignore: cast_nullable_to_non_nullable
as Unit,timeZone: freezed == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String?,weightGoalKind: null == weightGoalKind ? _self.weightGoalKind : weightGoalKind // ignore: cast_nullable_to_non_nullable
as WeightGoalKind,targetSystolic: freezed == targetSystolic ? _self.targetSystolic : targetSystolic // ignore: cast_nullable_to_non_nullable
as int?,targetDiastolic: freezed == targetDiastolic ? _self.targetDiastolic : targetDiastolic // ignore: cast_nullable_to_non_nullable
as int?,targetWeightKg: freezed == targetWeightKg ? _self.targetWeightKg : targetWeightKg // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthProfile].
extension HealthProfilePatterns on HealthProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthProfile value)  $default,){
final _that = this;
switch (_that) {
case _HealthProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthProfile value)?  $default,){
final _that = this;
switch (_that) {
case _HealthProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? displayName,  DateTime? dateOfBirth,  String? sex,  double? heightCm,  Unit preferredMassUnit,  Unit preferredLengthUnit,  Unit preferredTemperatureUnit,  String? timeZone,  WeightGoalKind weightGoalKind,  int? targetSystolic,  int? targetDiastolic,  DateTime? targetWeightKg)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthProfile() when $default != null:
return $default(_that.id,_that.displayName,_that.dateOfBirth,_that.sex,_that.heightCm,_that.preferredMassUnit,_that.preferredLengthUnit,_that.preferredTemperatureUnit,_that.timeZone,_that.weightGoalKind,_that.targetSystolic,_that.targetDiastolic,_that.targetWeightKg);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? displayName,  DateTime? dateOfBirth,  String? sex,  double? heightCm,  Unit preferredMassUnit,  Unit preferredLengthUnit,  Unit preferredTemperatureUnit,  String? timeZone,  WeightGoalKind weightGoalKind,  int? targetSystolic,  int? targetDiastolic,  DateTime? targetWeightKg)  $default,) {final _that = this;
switch (_that) {
case _HealthProfile():
return $default(_that.id,_that.displayName,_that.dateOfBirth,_that.sex,_that.heightCm,_that.preferredMassUnit,_that.preferredLengthUnit,_that.preferredTemperatureUnit,_that.timeZone,_that.weightGoalKind,_that.targetSystolic,_that.targetDiastolic,_that.targetWeightKg);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? displayName,  DateTime? dateOfBirth,  String? sex,  double? heightCm,  Unit preferredMassUnit,  Unit preferredLengthUnit,  Unit preferredTemperatureUnit,  String? timeZone,  WeightGoalKind weightGoalKind,  int? targetSystolic,  int? targetDiastolic,  DateTime? targetWeightKg)?  $default,) {final _that = this;
switch (_that) {
case _HealthProfile() when $default != null:
return $default(_that.id,_that.displayName,_that.dateOfBirth,_that.sex,_that.heightCm,_that.preferredMassUnit,_that.preferredLengthUnit,_that.preferredTemperatureUnit,_that.timeZone,_that.weightGoalKind,_that.targetSystolic,_that.targetDiastolic,_that.targetWeightKg);case _:
  return null;

}
}

}

/// @nodoc


class _HealthProfile implements HealthProfile {
  const _HealthProfile({required this.id, this.displayName, this.dateOfBirth, this.sex, this.heightCm, this.preferredMassUnit = Unit.kilogram, this.preferredLengthUnit = Unit.centimetre, this.preferredTemperatureUnit = Unit.celsius, this.timeZone, this.weightGoalKind = WeightGoalKind.none, this.targetSystolic, this.targetDiastolic, this.targetWeightKg});
  

@override final  String id;
@override final  String? displayName;
@override final  DateTime? dateOfBirth;
@override final  String? sex;
@override final  double? heightCm;
@override@JsonKey() final  Unit preferredMassUnit;
@override@JsonKey() final  Unit preferredLengthUnit;
@override@JsonKey() final  Unit preferredTemperatureUnit;
@override final  String? timeZone;
@override@JsonKey() final  WeightGoalKind weightGoalKind;
@override final  int? targetSystolic;
@override final  int? targetDiastolic;
@override final  DateTime? targetWeightKg;

/// Create a copy of HealthProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthProfileCopyWith<_HealthProfile> get copyWith => __$HealthProfileCopyWithImpl<_HealthProfile>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth)&&(identical(other.sex, sex) || other.sex == sex)&&(identical(other.heightCm, heightCm) || other.heightCm == heightCm)&&(identical(other.preferredMassUnit, preferredMassUnit) || other.preferredMassUnit == preferredMassUnit)&&(identical(other.preferredLengthUnit, preferredLengthUnit) || other.preferredLengthUnit == preferredLengthUnit)&&(identical(other.preferredTemperatureUnit, preferredTemperatureUnit) || other.preferredTemperatureUnit == preferredTemperatureUnit)&&(identical(other.timeZone, timeZone) || other.timeZone == timeZone)&&(identical(other.weightGoalKind, weightGoalKind) || other.weightGoalKind == weightGoalKind)&&(identical(other.targetSystolic, targetSystolic) || other.targetSystolic == targetSystolic)&&(identical(other.targetDiastolic, targetDiastolic) || other.targetDiastolic == targetDiastolic)&&(identical(other.targetWeightKg, targetWeightKg) || other.targetWeightKg == targetWeightKg));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,dateOfBirth,sex,heightCm,preferredMassUnit,preferredLengthUnit,preferredTemperatureUnit,timeZone,weightGoalKind,targetSystolic,targetDiastolic,targetWeightKg);
}

@override
String toString() {
    return 'HealthProfile(id: $id, displayName: $displayName, dateOfBirth: $dateOfBirth, sex: $sex, heightCm: $heightCm, preferredMassUnit: $preferredMassUnit, preferredLengthUnit: $preferredLengthUnit, preferredTemperatureUnit: $preferredTemperatureUnit, timeZone: $timeZone, weightGoalKind: $weightGoalKind, targetSystolic: $targetSystolic, targetDiastolic: $targetDiastolic, targetWeightKg: $targetWeightKg)';
}


}

/// @nodoc
abstract mixin class _$HealthProfileCopyWith<$Res> implements $HealthProfileCopyWith<$Res> {
  factory _$HealthProfileCopyWith(_HealthProfile value, $Res Function(_HealthProfile) _then) = __$HealthProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String? displayName, DateTime? dateOfBirth, String? sex, double? heightCm, Unit preferredMassUnit, Unit preferredLengthUnit, Unit preferredTemperatureUnit, String? timeZone, WeightGoalKind weightGoalKind, int? targetSystolic, int? targetDiastolic, DateTime? targetWeightKg
});




}
/// @nodoc
class __$HealthProfileCopyWithImpl<$Res>
    implements _$HealthProfileCopyWith<$Res> {
  __$HealthProfileCopyWithImpl(this._self, this._then);

  final _HealthProfile _self;
  final $Res Function(_HealthProfile) _then;

/// Create a copy of HealthProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = freezed,Object? dateOfBirth = freezed,Object? sex = freezed,Object? heightCm = freezed,Object? preferredMassUnit = null,Object? preferredLengthUnit = null,Object? preferredTemperatureUnit = null,Object? timeZone = freezed,Object? weightGoalKind = null,Object? targetSystolic = freezed,Object? targetDiastolic = freezed,Object? targetWeightKg = freezed,}) {
  return _then(_HealthProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,sex: freezed == sex ? _self.sex : sex // ignore: cast_nullable_to_non_nullable
as String?,heightCm: freezed == heightCm ? _self.heightCm : heightCm // ignore: cast_nullable_to_non_nullable
as double?,preferredMassUnit: null == preferredMassUnit ? _self.preferredMassUnit : preferredMassUnit // ignore: cast_nullable_to_non_nullable
as Unit,preferredLengthUnit: null == preferredLengthUnit ? _self.preferredLengthUnit : preferredLengthUnit // ignore: cast_nullable_to_non_nullable
as Unit,preferredTemperatureUnit: null == preferredTemperatureUnit ? _self.preferredTemperatureUnit : preferredTemperatureUnit // ignore: cast_nullable_to_non_nullable
as Unit,timeZone: freezed == timeZone ? _self.timeZone : timeZone // ignore: cast_nullable_to_non_nullable
as String?,weightGoalKind: null == weightGoalKind ? _self.weightGoalKind : weightGoalKind // ignore: cast_nullable_to_non_nullable
as WeightGoalKind,targetSystolic: freezed == targetSystolic ? _self.targetSystolic : targetSystolic // ignore: cast_nullable_to_non_nullable
as int?,targetDiastolic: freezed == targetDiastolic ? _self.targetDiastolic : targetDiastolic // ignore: cast_nullable_to_non_nullable
as int?,targetWeightKg: freezed == targetWeightKg ? _self.targetWeightKg : targetWeightKg // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$HealthGoal {

 String get id; String get metricType; double get targetValue; Unit get unit; DateTime? get targetDate; bool get active;
/// Create a copy of HealthGoal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthGoalCopyWith<HealthGoal> get copyWith => _$HealthGoalCopyWithImpl<HealthGoal>(this as HealthGoal, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as HealthGoal;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthGoal&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.metricType, _this.metricType) || other.metricType == _this.metricType)&&(identical(other.targetValue, _this.targetValue) || other.targetValue == _this.targetValue)&&(identical(other.unit, _this.unit) || other.unit == _this.unit)&&(identical(other.targetDate, _this.targetDate) || other.targetDate == _this.targetDate)&&(identical(other.active, _this.active) || other.active == _this.active));
}


@override
int get hashCode {
  final _this = this as HealthGoal;
  return Object.hash(runtimeType,_this.id,_this.metricType,_this.targetValue,_this.unit,_this.targetDate,_this.active);
}

@override
String toString() {
  final _this = this as HealthGoal;
  return 'HealthGoal(id: ${_this.id}, metricType: ${_this.metricType}, targetValue: ${_this.targetValue}, unit: ${_this.unit}, targetDate: ${_this.targetDate}, active: ${_this.active})';
}


}

/// @nodoc
abstract mixin class $HealthGoalCopyWith<$Res>  {
  factory $HealthGoalCopyWith(HealthGoal value, $Res Function(HealthGoal) _then) = _$HealthGoalCopyWithImpl;
@useResult
$Res call({
 String id, String metricType, double targetValue, Unit unit, DateTime? targetDate, bool active
});




}
/// @nodoc
class _$HealthGoalCopyWithImpl<$Res>
    implements $HealthGoalCopyWith<$Res> {
  _$HealthGoalCopyWithImpl(this._self, this._then);

  final HealthGoal _self;
  final $Res Function(HealthGoal) _then;

/// Create a copy of HealthGoal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? metricType = null,Object? targetValue = null,Object? unit = null,Object? targetDate = freezed,Object? active = null,}) {
  return _then(HealthGoal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,metricType: null == metricType ? _self.metricType : metricType // ignore: cast_nullable_to_non_nullable
as String,targetValue: null == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as Unit,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [HealthGoal].
extension HealthGoalPatterns on HealthGoal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HealthGoal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HealthGoal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HealthGoal value)  $default,){
final _that = this;
switch (_that) {
case _HealthGoal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HealthGoal value)?  $default,){
final _that = this;
switch (_that) {
case _HealthGoal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String metricType,  double targetValue,  Unit unit,  DateTime? targetDate,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HealthGoal() when $default != null:
return $default(_that.id,_that.metricType,_that.targetValue,_that.unit,_that.targetDate,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String metricType,  double targetValue,  Unit unit,  DateTime? targetDate,  bool active)  $default,) {final _that = this;
switch (_that) {
case _HealthGoal():
return $default(_that.id,_that.metricType,_that.targetValue,_that.unit,_that.targetDate,_that.active);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String metricType,  double targetValue,  Unit unit,  DateTime? targetDate,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _HealthGoal() when $default != null:
return $default(_that.id,_that.metricType,_that.targetValue,_that.unit,_that.targetDate,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _HealthGoal implements HealthGoal {
  const _HealthGoal({required this.id, required this.metricType, required this.targetValue, required this.unit, this.targetDate, this.active = true});
  

@override final  String id;
@override final  String metricType;
@override final  double targetValue;
@override final  Unit unit;
@override final  DateTime? targetDate;
@override@JsonKey() final  bool active;

/// Create a copy of HealthGoal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthGoalCopyWith<_HealthGoal> get copyWith => __$HealthGoalCopyWithImpl<_HealthGoal>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthGoal&&(identical(other.id, id) || other.id == id)&&(identical(other.metricType, metricType) || other.metricType == metricType)&&(identical(other.targetValue, targetValue) || other.targetValue == targetValue)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,metricType,targetValue,unit,targetDate,active);
}

@override
String toString() {
    return 'HealthGoal(id: $id, metricType: $metricType, targetValue: $targetValue, unit: $unit, targetDate: $targetDate, active: $active)';
}


}

/// @nodoc
abstract mixin class _$HealthGoalCopyWith<$Res> implements $HealthGoalCopyWith<$Res> {
  factory _$HealthGoalCopyWith(_HealthGoal value, $Res Function(_HealthGoal) _then) = __$HealthGoalCopyWithImpl;
@override @useResult
$Res call({
 String id, String metricType, double targetValue, Unit unit, DateTime? targetDate, bool active
});




}
/// @nodoc
class __$HealthGoalCopyWithImpl<$Res>
    implements _$HealthGoalCopyWith<$Res> {
  __$HealthGoalCopyWithImpl(this._self, this._then);

  final _HealthGoal _self;
  final $Res Function(_HealthGoal) _then;

/// Create a copy of HealthGoal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? metricType = null,Object? targetValue = null,Object? unit = null,Object? targetDate = freezed,Object? active = null,}) {
  return _then(_HealthGoal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,metricType: null == metricType ? _self.metricType : metricType // ignore: cast_nullable_to_non_nullable
as String,targetValue: null == targetValue ? _self.targetValue : targetValue // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as Unit,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
