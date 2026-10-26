// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'measurement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Measurement {

/// Device-generated stable identifier. The server never assigns it.
 String get id;/// Which metric this row records.
 MetricType get metricType;/// The primary value, in [unit].
 double get value;/// The unit of [value]. Always the canonical unit for storage.
 Unit get unit;/// The optional second component: diastolic pressure, or body-fat percent.
 double? get secondaryValue;/// The unit of [secondaryValue].
 Unit? get secondaryUnit;/// The optional third component: pulse, or waist circumference.
 double? get tertiaryValue;/// The unit of [tertiaryValue].
 Unit? get tertiaryUnit;/// When the measurement happened, in UTC.
 DateTime get recordedAt;/// The local calendar day containing [recordedAt]. Stored, not computed, so
/// that day grouping survives timezone changes and DST.
 DateTime get localDay;/// When the row was written to this device, in UTC.
 DateTime get createdAt;/// When the row was last modified, in UTC.
 DateTime get updatedAt;/// Where the measurement came from.
 MeasurementSource get source;/// Whether the record has reached the server.
 bool get isSynced;/// Set when the user deletes the record. Soft-deleted rows are hidden from
/// the UI but retained so the deletion can sync and be undone.
 DateTime? get deletedAt;/// The circumstances surrounding the measurement.
 MeasurementContext get context;
/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MeasurementCopyWith<Measurement> get copyWith => _$MeasurementCopyWithImpl<Measurement>(this as Measurement, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Measurement;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Measurement&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.metricType, _this.metricType) || other.metricType == _this.metricType)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.unit, _this.unit) || other.unit == _this.unit)&&(identical(other.secondaryValue, _this.secondaryValue) || other.secondaryValue == _this.secondaryValue)&&(identical(other.secondaryUnit, _this.secondaryUnit) || other.secondaryUnit == _this.secondaryUnit)&&(identical(other.tertiaryValue, _this.tertiaryValue) || other.tertiaryValue == _this.tertiaryValue)&&(identical(other.tertiaryUnit, _this.tertiaryUnit) || other.tertiaryUnit == _this.tertiaryUnit)&&(identical(other.recordedAt, _this.recordedAt) || other.recordedAt == _this.recordedAt)&&(identical(other.localDay, _this.localDay) || other.localDay == _this.localDay)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.isSynced, _this.isSynced) || other.isSynced == _this.isSynced)&&(identical(other.deletedAt, _this.deletedAt) || other.deletedAt == _this.deletedAt)&&(identical(other.context, _this.context) || other.context == _this.context));
}


@override
int get hashCode {
  final _this = this as Measurement;
  return Object.hash(runtimeType,_this.id,_this.metricType,_this.value,_this.unit,_this.secondaryValue,_this.secondaryUnit,_this.tertiaryValue,_this.tertiaryUnit,_this.recordedAt,_this.localDay,_this.createdAt,_this.updatedAt,_this.source,_this.isSynced,_this.deletedAt,_this.context);
}

@override
String toString() {
  final _this = this as Measurement;
  return 'Measurement(id: ${_this.id}, metricType: ${_this.metricType}, value: ${_this.value}, unit: ${_this.unit}, secondaryValue: ${_this.secondaryValue}, secondaryUnit: ${_this.secondaryUnit}, tertiaryValue: ${_this.tertiaryValue}, tertiaryUnit: ${_this.tertiaryUnit}, recordedAt: ${_this.recordedAt}, localDay: ${_this.localDay}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, source: ${_this.source}, isSynced: ${_this.isSynced}, deletedAt: ${_this.deletedAt}, context: ${_this.context})';
}


}

/// @nodoc
abstract mixin class $MeasurementCopyWith<$Res>  {
  factory $MeasurementCopyWith(Measurement value, $Res Function(Measurement) _then) = _$MeasurementCopyWithImpl;
@useResult
$Res call({
 String id, MetricType metricType, double value, Unit unit, double? secondaryValue, Unit? secondaryUnit, double? tertiaryValue, Unit? tertiaryUnit, DateTime recordedAt, DateTime localDay, DateTime createdAt, DateTime updatedAt, MeasurementSource source, bool isSynced, DateTime? deletedAt, MeasurementContext context
});




}
/// @nodoc
class _$MeasurementCopyWithImpl<$Res>
    implements $MeasurementCopyWith<$Res> {
  _$MeasurementCopyWithImpl(this._self, this._then);

  final Measurement _self;
  final $Res Function(Measurement) _then;

/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? metricType = null,Object? value = null,Object? unit = null,Object? secondaryValue = freezed,Object? secondaryUnit = freezed,Object? tertiaryValue = freezed,Object? tertiaryUnit = freezed,Object? recordedAt = null,Object? localDay = null,Object? createdAt = null,Object? updatedAt = null,Object? source = null,Object? isSynced = null,Object? deletedAt = freezed,Object? context = null,}) {
  return _then(Measurement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,metricType: null == metricType ? _self.metricType : metricType // ignore: cast_nullable_to_non_nullable
as MetricType,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as Unit,secondaryValue: freezed == secondaryValue ? _self.secondaryValue : secondaryValue // ignore: cast_nullable_to_non_nullable
as double?,secondaryUnit: freezed == secondaryUnit ? _self.secondaryUnit : secondaryUnit // ignore: cast_nullable_to_non_nullable
as Unit?,tertiaryValue: freezed == tertiaryValue ? _self.tertiaryValue : tertiaryValue // ignore: cast_nullable_to_non_nullable
as double?,tertiaryUnit: freezed == tertiaryUnit ? _self.tertiaryUnit : tertiaryUnit // ignore: cast_nullable_to_non_nullable
as Unit?,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,localDay: null == localDay ? _self.localDay : localDay // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as MeasurementSource,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as MeasurementContext,
  ));
}

}


/// Adds pattern-matching-related methods to [Measurement].
extension MeasurementPatterns on Measurement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Measurement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Measurement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Measurement value)  $default,){
final _that = this;
switch (_that) {
case _Measurement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Measurement value)?  $default,){
final _that = this;
switch (_that) {
case _Measurement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  MetricType metricType,  double value,  Unit unit,  double? secondaryValue,  Unit? secondaryUnit,  double? tertiaryValue,  Unit? tertiaryUnit,  DateTime recordedAt,  DateTime localDay,  DateTime createdAt,  DateTime updatedAt,  MeasurementSource source,  bool isSynced,  DateTime? deletedAt,  MeasurementContext context)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Measurement() when $default != null:
return $default(_that.id,_that.metricType,_that.value,_that.unit,_that.secondaryValue,_that.secondaryUnit,_that.tertiaryValue,_that.tertiaryUnit,_that.recordedAt,_that.localDay,_that.createdAt,_that.updatedAt,_that.source,_that.isSynced,_that.deletedAt,_that.context);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  MetricType metricType,  double value,  Unit unit,  double? secondaryValue,  Unit? secondaryUnit,  double? tertiaryValue,  Unit? tertiaryUnit,  DateTime recordedAt,  DateTime localDay,  DateTime createdAt,  DateTime updatedAt,  MeasurementSource source,  bool isSynced,  DateTime? deletedAt,  MeasurementContext context)  $default,) {final _that = this;
switch (_that) {
case _Measurement():
return $default(_that.id,_that.metricType,_that.value,_that.unit,_that.secondaryValue,_that.secondaryUnit,_that.tertiaryValue,_that.tertiaryUnit,_that.recordedAt,_that.localDay,_that.createdAt,_that.updatedAt,_that.source,_that.isSynced,_that.deletedAt,_that.context);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  MetricType metricType,  double value,  Unit unit,  double? secondaryValue,  Unit? secondaryUnit,  double? tertiaryValue,  Unit? tertiaryUnit,  DateTime recordedAt,  DateTime localDay,  DateTime createdAt,  DateTime updatedAt,  MeasurementSource source,  bool isSynced,  DateTime? deletedAt,  MeasurementContext context)?  $default,) {final _that = this;
switch (_that) {
case _Measurement() when $default != null:
return $default(_that.id,_that.metricType,_that.value,_that.unit,_that.secondaryValue,_that.secondaryUnit,_that.tertiaryValue,_that.tertiaryUnit,_that.recordedAt,_that.localDay,_that.createdAt,_that.updatedAt,_that.source,_that.isSynced,_that.deletedAt,_that.context);case _:
  return null;

}
}

}

/// @nodoc


class _Measurement extends Measurement {
  const _Measurement({required this.id, required this.metricType, required this.value, required this.unit, this.secondaryValue, this.secondaryUnit, this.tertiaryValue, this.tertiaryUnit, required this.recordedAt, required this.localDay, required this.createdAt, required this.updatedAt, this.source = MeasurementSource.manual, this.isSynced = false, this.deletedAt, this.context = MeasurementContext.empty}): super._();
  

/// Device-generated stable identifier. The server never assigns it.
@override final  String id;
/// Which metric this row records.
@override final  MetricType metricType;
/// The primary value, in [unit].
@override final  double value;
/// The unit of [value]. Always the canonical unit for storage.
@override final  Unit unit;
/// The optional second component: diastolic pressure, or body-fat percent.
@override final  double? secondaryValue;
/// The unit of [secondaryValue].
@override final  Unit? secondaryUnit;
/// The optional third component: pulse, or waist circumference.
@override final  double? tertiaryValue;
/// The unit of [tertiaryValue].
@override final  Unit? tertiaryUnit;
/// When the measurement happened, in UTC.
@override final  DateTime recordedAt;
/// The local calendar day containing [recordedAt]. Stored, not computed, so
/// that day grouping survives timezone changes and DST.
@override final  DateTime localDay;
/// When the row was written to this device, in UTC.
@override final  DateTime createdAt;
/// When the row was last modified, in UTC.
@override final  DateTime updatedAt;
/// Where the measurement came from.
@override@JsonKey() final  MeasurementSource source;
/// Whether the record has reached the server.
@override@JsonKey() final  bool isSynced;
/// Set when the user deletes the record. Soft-deleted rows are hidden from
/// the UI but retained so the deletion can sync and be undone.
@override final  DateTime? deletedAt;
/// The circumstances surrounding the measurement.
@override@JsonKey() final  MeasurementContext context;

/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MeasurementCopyWith<_Measurement> get copyWith => __$MeasurementCopyWithImpl<_Measurement>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Measurement&&(identical(other.id, id) || other.id == id)&&(identical(other.metricType, metricType) || other.metricType == metricType)&&(identical(other.value, value) || other.value == value)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.secondaryValue, secondaryValue) || other.secondaryValue == secondaryValue)&&(identical(other.secondaryUnit, secondaryUnit) || other.secondaryUnit == secondaryUnit)&&(identical(other.tertiaryValue, tertiaryValue) || other.tertiaryValue == tertiaryValue)&&(identical(other.tertiaryUnit, tertiaryUnit) || other.tertiaryUnit == tertiaryUnit)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.localDay, localDay) || other.localDay == localDay)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.source, source) || other.source == source)&&(identical(other.isSynced, isSynced) || other.isSynced == isSynced)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.context, context) || other.context == context));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,metricType,value,unit,secondaryValue,secondaryUnit,tertiaryValue,tertiaryUnit,recordedAt,localDay,createdAt,updatedAt,source,isSynced,deletedAt,context);
}

@override
String toString() {
    return 'Measurement(id: $id, metricType: $metricType, value: $value, unit: $unit, secondaryValue: $secondaryValue, secondaryUnit: $secondaryUnit, tertiaryValue: $tertiaryValue, tertiaryUnit: $tertiaryUnit, recordedAt: $recordedAt, localDay: $localDay, createdAt: $createdAt, updatedAt: $updatedAt, source: $source, isSynced: $isSynced, deletedAt: $deletedAt, context: $context)';
}


}

/// @nodoc
abstract mixin class _$MeasurementCopyWith<$Res> implements $MeasurementCopyWith<$Res> {
  factory _$MeasurementCopyWith(_Measurement value, $Res Function(_Measurement) _then) = __$MeasurementCopyWithImpl;
@override @useResult
$Res call({
 String id, MetricType metricType, double value, Unit unit, double? secondaryValue, Unit? secondaryUnit, double? tertiaryValue, Unit? tertiaryUnit, DateTime recordedAt, DateTime localDay, DateTime createdAt, DateTime updatedAt, MeasurementSource source, bool isSynced, DateTime? deletedAt, MeasurementContext context
});




}
/// @nodoc
class __$MeasurementCopyWithImpl<$Res>
    implements _$MeasurementCopyWith<$Res> {
  __$MeasurementCopyWithImpl(this._self, this._then);

  final _Measurement _self;
  final $Res Function(_Measurement) _then;

/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? metricType = null,Object? value = null,Object? unit = null,Object? secondaryValue = freezed,Object? secondaryUnit = freezed,Object? tertiaryValue = freezed,Object? tertiaryUnit = freezed,Object? recordedAt = null,Object? localDay = null,Object? createdAt = null,Object? updatedAt = null,Object? source = null,Object? isSynced = null,Object? deletedAt = freezed,Object? context = null,}) {
  return _then(_Measurement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,metricType: null == metricType ? _self.metricType : metricType // ignore: cast_nullable_to_non_nullable
as MetricType,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as Unit,secondaryValue: freezed == secondaryValue ? _self.secondaryValue : secondaryValue // ignore: cast_nullable_to_non_nullable
as double?,secondaryUnit: freezed == secondaryUnit ? _self.secondaryUnit : secondaryUnit // ignore: cast_nullable_to_non_nullable
as Unit?,tertiaryValue: freezed == tertiaryValue ? _self.tertiaryValue : tertiaryValue // ignore: cast_nullable_to_non_nullable
as double?,tertiaryUnit: freezed == tertiaryUnit ? _self.tertiaryUnit : tertiaryUnit // ignore: cast_nullable_to_non_nullable
as Unit?,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,localDay: null == localDay ? _self.localDay : localDay // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as MeasurementSource,isSynced: null == isSynced ? _self.isSynced : isSynced // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as MeasurementContext,
  ));
}


}

// dart format on
