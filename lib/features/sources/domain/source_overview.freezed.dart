// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_overview.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LastSync {

 LastSyncOutcome get outcome; DateTime get startedAt; DateTime? get finishedAt;/// An `AppFailure.code`, or [interruptedSyncCode]; null unless the run
/// failed. The UI phrases it; it is never raw exception text.
 String? get failureCode;/// The HTTP status the server answered the failed run with, if any.
 int? get failureStatus;
/// Create a copy of LastSync
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LastSyncCopyWith<LastSync> get copyWith => _$LastSyncCopyWithImpl<LastSync>(this as LastSync, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LastSync;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LastSync&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.finishedAt, _this.finishedAt) || other.finishedAt == _this.finishedAt)&&(identical(other.failureCode, _this.failureCode) || other.failureCode == _this.failureCode)&&(identical(other.failureStatus, _this.failureStatus) || other.failureStatus == _this.failureStatus));
}


@override
int get hashCode {
  final _this = this as LastSync;
  return Object.hash(runtimeType,_this.outcome,_this.startedAt,_this.finishedAt,_this.failureCode,_this.failureStatus);
}

@override
String toString() {
  final _this = this as LastSync;
  return 'LastSync(outcome: ${_this.outcome}, startedAt: ${_this.startedAt}, finishedAt: ${_this.finishedAt}, failureCode: ${_this.failureCode}, failureStatus: ${_this.failureStatus})';
}


}

/// @nodoc
abstract mixin class $LastSyncCopyWith<$Res>  {
  factory $LastSyncCopyWith(LastSync value, $Res Function(LastSync) _then) = _$LastSyncCopyWithImpl;
@useResult
$Res call({
 LastSyncOutcome outcome, DateTime startedAt, DateTime? finishedAt, String? failureCode, int? failureStatus
});




}
/// @nodoc
class _$LastSyncCopyWithImpl<$Res>
    implements $LastSyncCopyWith<$Res> {
  _$LastSyncCopyWithImpl(this._self, this._then);

  final LastSync _self;
  final $Res Function(LastSync) _then;

/// Create a copy of LastSync
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? outcome = null,Object? startedAt = null,Object? finishedAt = freezed,Object? failureCode = freezed,Object? failureStatus = freezed,}) {
  return _then(LastSync(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as LastSyncOutcome,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,failureCode: freezed == failureCode ? _self.failureCode : failureCode // ignore: cast_nullable_to_non_nullable
as String?,failureStatus: freezed == failureStatus ? _self.failureStatus : failureStatus // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LastSync].
extension LastSyncPatterns on LastSync {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LastSync value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LastSync() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LastSync value)  $default,){
final _that = this;
switch (_that) {
case _LastSync():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LastSync value)?  $default,){
final _that = this;
switch (_that) {
case _LastSync() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LastSyncOutcome outcome,  DateTime startedAt,  DateTime? finishedAt,  String? failureCode,  int? failureStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LastSync() when $default != null:
return $default(_that.outcome,_that.startedAt,_that.finishedAt,_that.failureCode,_that.failureStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LastSyncOutcome outcome,  DateTime startedAt,  DateTime? finishedAt,  String? failureCode,  int? failureStatus)  $default,) {final _that = this;
switch (_that) {
case _LastSync():
return $default(_that.outcome,_that.startedAt,_that.finishedAt,_that.failureCode,_that.failureStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LastSyncOutcome outcome,  DateTime startedAt,  DateTime? finishedAt,  String? failureCode,  int? failureStatus)?  $default,) {final _that = this;
switch (_that) {
case _LastSync() when $default != null:
return $default(_that.outcome,_that.startedAt,_that.finishedAt,_that.failureCode,_that.failureStatus);case _:
  return null;

}
}

}

/// @nodoc


class _LastSync implements LastSync {
  const _LastSync({required this.outcome, required this.startedAt, this.finishedAt, this.failureCode, this.failureStatus});
  

@override final  LastSyncOutcome outcome;
@override final  DateTime startedAt;
@override final  DateTime? finishedAt;
/// An `AppFailure.code`, or [interruptedSyncCode]; null unless the run
/// failed. The UI phrases it; it is never raw exception text.
@override final  String? failureCode;
/// The HTTP status the server answered the failed run with, if any.
@override final  int? failureStatus;

/// Create a copy of LastSync
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LastSyncCopyWith<_LastSync> get copyWith => __$LastSyncCopyWithImpl<_LastSync>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LastSync&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.failureCode, failureCode) || other.failureCode == failureCode)&&(identical(other.failureStatus, failureStatus) || other.failureStatus == failureStatus));
}


@override
int get hashCode {
    return Object.hash(runtimeType,outcome,startedAt,finishedAt,failureCode,failureStatus);
}

@override
String toString() {
    return 'LastSync(outcome: $outcome, startedAt: $startedAt, finishedAt: $finishedAt, failureCode: $failureCode, failureStatus: $failureStatus)';
}


}

/// @nodoc
abstract mixin class _$LastSyncCopyWith<$Res> implements $LastSyncCopyWith<$Res> {
  factory _$LastSyncCopyWith(_LastSync value, $Res Function(_LastSync) _then) = __$LastSyncCopyWithImpl;
@override @useResult
$Res call({
 LastSyncOutcome outcome, DateTime startedAt, DateTime? finishedAt, String? failureCode, int? failureStatus
});




}
/// @nodoc
class __$LastSyncCopyWithImpl<$Res>
    implements _$LastSyncCopyWith<$Res> {
  __$LastSyncCopyWithImpl(this._self, this._then);

  final _LastSync _self;
  final $Res Function(_LastSync) _then;

/// Create a copy of LastSync
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? outcome = null,Object? startedAt = null,Object? finishedAt = freezed,Object? failureCode = freezed,Object? failureStatus = freezed,}) {
  return _then(_LastSync(
outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as LastSyncOutcome,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,failureCode: freezed == failureCode ? _self.failureCode : failureCode // ignore: cast_nullable_to_non_nullable
as String?,failureStatus: freezed == failureStatus ? _self.failureStatus : failureStatus // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$SourceCounts {

 int get channels; int get movies; int get series;
/// Create a copy of SourceCounts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceCountsCopyWith<SourceCounts> get copyWith => _$SourceCountsCopyWithImpl<SourceCounts>(this as SourceCounts, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceCounts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceCounts&&(identical(other.channels, _this.channels) || other.channels == _this.channels)&&(identical(other.movies, _this.movies) || other.movies == _this.movies)&&(identical(other.series, _this.series) || other.series == _this.series));
}


@override
int get hashCode {
  final _this = this as SourceCounts;
  return Object.hash(runtimeType,_this.channels,_this.movies,_this.series);
}

@override
String toString() {
  final _this = this as SourceCounts;
  return 'SourceCounts(channels: ${_this.channels}, movies: ${_this.movies}, series: ${_this.series})';
}


}

/// @nodoc
abstract mixin class $SourceCountsCopyWith<$Res>  {
  factory $SourceCountsCopyWith(SourceCounts value, $Res Function(SourceCounts) _then) = _$SourceCountsCopyWithImpl;
@useResult
$Res call({
 int channels, int movies, int series
});




}
/// @nodoc
class _$SourceCountsCopyWithImpl<$Res>
    implements $SourceCountsCopyWith<$Res> {
  _$SourceCountsCopyWithImpl(this._self, this._then);

  final SourceCounts _self;
  final $Res Function(SourceCounts) _then;

/// Create a copy of SourceCounts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? channels = null,Object? movies = null,Object? series = null,}) {
  return _then(SourceCounts(
channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,series: null == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceCounts].
extension SourceCountsPatterns on SourceCounts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceCounts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceCounts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceCounts value)  $default,){
final _that = this;
switch (_that) {
case _SourceCounts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceCounts value)?  $default,){
final _that = this;
switch (_that) {
case _SourceCounts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int channels,  int movies,  int series)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceCounts() when $default != null:
return $default(_that.channels,_that.movies,_that.series);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int channels,  int movies,  int series)  $default,) {final _that = this;
switch (_that) {
case _SourceCounts():
return $default(_that.channels,_that.movies,_that.series);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int channels,  int movies,  int series)?  $default,) {final _that = this;
switch (_that) {
case _SourceCounts() when $default != null:
return $default(_that.channels,_that.movies,_that.series);case _:
  return null;

}
}

}

/// @nodoc


class _SourceCounts extends SourceCounts {
  const _SourceCounts({this.channels = 0, this.movies = 0, this.series = 0}): super._();
  

@override@JsonKey() final  int channels;
@override@JsonKey() final  int movies;
@override@JsonKey() final  int series;

/// Create a copy of SourceCounts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceCountsCopyWith<_SourceCounts> get copyWith => __$SourceCountsCopyWithImpl<_SourceCounts>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceCounts&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.series, series) || other.series == series));
}


@override
int get hashCode {
    return Object.hash(runtimeType,channels,movies,series);
}

@override
String toString() {
    return 'SourceCounts(channels: $channels, movies: $movies, series: $series)';
}


}

/// @nodoc
abstract mixin class _$SourceCountsCopyWith<$Res> implements $SourceCountsCopyWith<$Res> {
  factory _$SourceCountsCopyWith(_SourceCounts value, $Res Function(_SourceCounts) _then) = __$SourceCountsCopyWithImpl;
@override @useResult
$Res call({
 int channels, int movies, int series
});




}
/// @nodoc
class __$SourceCountsCopyWithImpl<$Res>
    implements _$SourceCountsCopyWith<$Res> {
  __$SourceCountsCopyWithImpl(this._self, this._then);

  final _SourceCounts _self;
  final $Res Function(_SourceCounts) _then;

/// Create a copy of SourceCounts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channels = null,Object? movies = null,Object? series = null,}) {
  return _then(_SourceCounts(
channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,series: null == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$SourceOverview {

/// Xtream only, from the latest sign-in; null for a playlist or before
/// the first sync.
 ProviderAccount? get account; SourceCounts get counts; LastSync? get lastSync;
/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceOverviewCopyWith<SourceOverview> get copyWith => _$SourceOverviewCopyWithImpl<SourceOverview>(this as SourceOverview, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceOverview;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceOverview&&(identical(other.account, _this.account) || other.account == _this.account)&&(identical(other.counts, _this.counts) || other.counts == _this.counts)&&(identical(other.lastSync, _this.lastSync) || other.lastSync == _this.lastSync));
}


@override
int get hashCode {
  final _this = this as SourceOverview;
  return Object.hash(runtimeType,_this.account,_this.counts,_this.lastSync);
}

@override
String toString() {
  final _this = this as SourceOverview;
  return 'SourceOverview(account: ${_this.account}, counts: ${_this.counts}, lastSync: ${_this.lastSync})';
}


}

/// @nodoc
abstract mixin class $SourceOverviewCopyWith<$Res>  {
  factory $SourceOverviewCopyWith(SourceOverview value, $Res Function(SourceOverview) _then) = _$SourceOverviewCopyWithImpl;
@useResult
$Res call({
 ProviderAccount? account, SourceCounts counts, LastSync? lastSync
});


$ProviderAccountCopyWith<$Res>? get account;$SourceCountsCopyWith<$Res> get counts;$LastSyncCopyWith<$Res>? get lastSync;

}
/// @nodoc
class _$SourceOverviewCopyWithImpl<$Res>
    implements $SourceOverviewCopyWith<$Res> {
  _$SourceOverviewCopyWithImpl(this._self, this._then);

  final SourceOverview _self;
  final $Res Function(SourceOverview) _then;

/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? account = freezed,Object? counts = null,Object? lastSync = freezed,}) {
  return _then(SourceOverview(
account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as ProviderAccount?,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as SourceCounts,lastSync: freezed == lastSync ? _self.lastSync : lastSync // ignore: cast_nullable_to_non_nullable
as LastSync?,
  ));
}
/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderAccountCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $ProviderAccountCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SourceCountsCopyWith<$Res> get counts {
  
  return $SourceCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LastSyncCopyWith<$Res>? get lastSync {
    if (_self.lastSync == null) {
    return null;
  }

  return $LastSyncCopyWith<$Res>(_self.lastSync!, (value) {
    return _then(_self.copyWith(lastSync: value));
  });
}
}


/// Adds pattern-matching-related methods to [SourceOverview].
extension SourceOverviewPatterns on SourceOverview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceOverview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceOverview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceOverview value)  $default,){
final _that = this;
switch (_that) {
case _SourceOverview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceOverview value)?  $default,){
final _that = this;
switch (_that) {
case _SourceOverview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProviderAccount? account,  SourceCounts counts,  LastSync? lastSync)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceOverview() when $default != null:
return $default(_that.account,_that.counts,_that.lastSync);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProviderAccount? account,  SourceCounts counts,  LastSync? lastSync)  $default,) {final _that = this;
switch (_that) {
case _SourceOverview():
return $default(_that.account,_that.counts,_that.lastSync);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProviderAccount? account,  SourceCounts counts,  LastSync? lastSync)?  $default,) {final _that = this;
switch (_that) {
case _SourceOverview() when $default != null:
return $default(_that.account,_that.counts,_that.lastSync);case _:
  return null;

}
}

}

/// @nodoc


class _SourceOverview implements SourceOverview {
  const _SourceOverview({this.account, this.counts = const SourceCounts(), this.lastSync});
  

/// Xtream only, from the latest sign-in; null for a playlist or before
/// the first sync.
@override final  ProviderAccount? account;
@override@JsonKey() final  SourceCounts counts;
@override final  LastSync? lastSync;

/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceOverviewCopyWith<_SourceOverview> get copyWith => __$SourceOverviewCopyWithImpl<_SourceOverview>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceOverview&&(identical(other.account, account) || other.account == account)&&(identical(other.counts, counts) || other.counts == counts)&&(identical(other.lastSync, lastSync) || other.lastSync == lastSync));
}


@override
int get hashCode {
    return Object.hash(runtimeType,account,counts,lastSync);
}

@override
String toString() {
    return 'SourceOverview(account: $account, counts: $counts, lastSync: $lastSync)';
}


}

/// @nodoc
abstract mixin class _$SourceOverviewCopyWith<$Res> implements $SourceOverviewCopyWith<$Res> {
  factory _$SourceOverviewCopyWith(_SourceOverview value, $Res Function(_SourceOverview) _then) = __$SourceOverviewCopyWithImpl;
@override @useResult
$Res call({
 ProviderAccount? account, SourceCounts counts, LastSync? lastSync
});


@override $ProviderAccountCopyWith<$Res>? get account;@override $SourceCountsCopyWith<$Res> get counts;@override $LastSyncCopyWith<$Res>? get lastSync;

}
/// @nodoc
class __$SourceOverviewCopyWithImpl<$Res>
    implements _$SourceOverviewCopyWith<$Res> {
  __$SourceOverviewCopyWithImpl(this._self, this._then);

  final _SourceOverview _self;
  final $Res Function(_SourceOverview) _then;

/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? account = freezed,Object? counts = null,Object? lastSync = freezed,}) {
  return _then(_SourceOverview(
account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as ProviderAccount?,counts: null == counts ? _self.counts : counts // ignore: cast_nullable_to_non_nullable
as SourceCounts,lastSync: freezed == lastSync ? _self.lastSync : lastSync // ignore: cast_nullable_to_non_nullable
as LastSync?,
  ));
}

/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderAccountCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $ProviderAccountCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SourceCountsCopyWith<$Res> get counts {
  
  return $SourceCountsCopyWith<$Res>(_self.counts, (value) {
    return _then(_self.copyWith(counts: value));
  });
}/// Create a copy of SourceOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LastSyncCopyWith<$Res>? get lastSync {
    if (_self.lastSync == null) {
    return null;
  }

  return $LastSyncCopyWith<$Res>(_self.lastSync!, (value) {
    return _then(_self.copyWith(lastSync: value));
  });
}
}

// dart format on
