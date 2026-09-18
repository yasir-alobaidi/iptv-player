// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SyncProgress {

 SyncStage get stage;/// Set once the account stage is done (Xtream only).
 ProviderAccount? get account; int get categories; int get channels; int get movies; int get series; int get episodes;/// How many rows the current stage will write, once the list is in;
/// null while it downloads, and throughout an M3U playlist, whose
/// length is only known at its end.
 int? get stageTotal;
/// Create a copy of SyncProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncProgressCopyWith<SyncProgress> get copyWith => _$SyncProgressCopyWithImpl<SyncProgress>(this as SyncProgress, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SyncProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncProgress&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&(identical(other.account, _this.account) || other.account == _this.account)&&(identical(other.categories, _this.categories) || other.categories == _this.categories)&&(identical(other.channels, _this.channels) || other.channels == _this.channels)&&(identical(other.movies, _this.movies) || other.movies == _this.movies)&&(identical(other.series, _this.series) || other.series == _this.series)&&(identical(other.episodes, _this.episodes) || other.episodes == _this.episodes)&&(identical(other.stageTotal, _this.stageTotal) || other.stageTotal == _this.stageTotal));
}


@override
int get hashCode {
  final _this = this as SyncProgress;
  return Object.hash(runtimeType,_this.stage,_this.account,_this.categories,_this.channels,_this.movies,_this.series,_this.episodes,_this.stageTotal);
}

@override
String toString() {
  final _this = this as SyncProgress;
  return 'SyncProgress(stage: ${_this.stage}, account: ${_this.account}, categories: ${_this.categories}, channels: ${_this.channels}, movies: ${_this.movies}, series: ${_this.series}, episodes: ${_this.episodes}, stageTotal: ${_this.stageTotal})';
}


}

/// @nodoc
abstract mixin class $SyncProgressCopyWith<$Res>  {
  factory $SyncProgressCopyWith(SyncProgress value, $Res Function(SyncProgress) _then) = _$SyncProgressCopyWithImpl;
@useResult
$Res call({
 SyncStage stage, ProviderAccount? account, int categories, int channels, int movies, int series, int episodes, int? stageTotal
});


$ProviderAccountCopyWith<$Res>? get account;

}
/// @nodoc
class _$SyncProgressCopyWithImpl<$Res>
    implements $SyncProgressCopyWith<$Res> {
  _$SyncProgressCopyWithImpl(this._self, this._then);

  final SyncProgress _self;
  final $Res Function(SyncProgress) _then;

/// Create a copy of SyncProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stage = null,Object? account = freezed,Object? categories = null,Object? channels = null,Object? movies = null,Object? series = null,Object? episodes = null,Object? stageTotal = freezed,}) {
  return _then(SyncProgress(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as SyncStage,account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as ProviderAccount?,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,series: null == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int,stageTotal: freezed == stageTotal ? _self.stageTotal : stageTotal // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of SyncProgress
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
}
}


/// Adds pattern-matching-related methods to [SyncProgress].
extension SyncProgressPatterns on SyncProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncProgress value)  $default,){
final _that = this;
switch (_that) {
case _SyncProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncProgress value)?  $default,){
final _that = this;
switch (_that) {
case _SyncProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SyncStage stage,  ProviderAccount? account,  int categories,  int channels,  int movies,  int series,  int episodes,  int? stageTotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncProgress() when $default != null:
return $default(_that.stage,_that.account,_that.categories,_that.channels,_that.movies,_that.series,_that.episodes,_that.stageTotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SyncStage stage,  ProviderAccount? account,  int categories,  int channels,  int movies,  int series,  int episodes,  int? stageTotal)  $default,) {final _that = this;
switch (_that) {
case _SyncProgress():
return $default(_that.stage,_that.account,_that.categories,_that.channels,_that.movies,_that.series,_that.episodes,_that.stageTotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SyncStage stage,  ProviderAccount? account,  int categories,  int channels,  int movies,  int series,  int episodes,  int? stageTotal)?  $default,) {final _that = this;
switch (_that) {
case _SyncProgress() when $default != null:
return $default(_that.stage,_that.account,_that.categories,_that.channels,_that.movies,_that.series,_that.episodes,_that.stageTotal);case _:
  return null;

}
}

}

/// @nodoc


class _SyncProgress implements SyncProgress {
  const _SyncProgress({required this.stage, this.account, this.categories = 0, this.channels = 0, this.movies = 0, this.series = 0, this.episodes = 0, this.stageTotal});
  

@override final  SyncStage stage;
/// Set once the account stage is done (Xtream only).
@override final  ProviderAccount? account;
@override@JsonKey() final  int categories;
@override@JsonKey() final  int channels;
@override@JsonKey() final  int movies;
@override@JsonKey() final  int series;
@override@JsonKey() final  int episodes;
/// How many rows the current stage will write, once the list is in;
/// null while it downloads, and throughout an M3U playlist, whose
/// length is only known at its end.
@override final  int? stageTotal;

/// Create a copy of SyncProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncProgressCopyWith<_SyncProgress> get copyWith => __$SyncProgressCopyWithImpl<_SyncProgress>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncProgress&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.account, account) || other.account == account)&&(identical(other.categories, categories) || other.categories == categories)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.series, series) || other.series == series)&&(identical(other.episodes, episodes) || other.episodes == episodes)&&(identical(other.stageTotal, stageTotal) || other.stageTotal == stageTotal));
}


@override
int get hashCode {
    return Object.hash(runtimeType,stage,account,categories,channels,movies,series,episodes,stageTotal);
}

@override
String toString() {
    return 'SyncProgress(stage: $stage, account: $account, categories: $categories, channels: $channels, movies: $movies, series: $series, episodes: $episodes, stageTotal: $stageTotal)';
}


}

/// @nodoc
abstract mixin class _$SyncProgressCopyWith<$Res> implements $SyncProgressCopyWith<$Res> {
  factory _$SyncProgressCopyWith(_SyncProgress value, $Res Function(_SyncProgress) _then) = __$SyncProgressCopyWithImpl;
@override @useResult
$Res call({
 SyncStage stage, ProviderAccount? account, int categories, int channels, int movies, int series, int episodes, int? stageTotal
});


@override $ProviderAccountCopyWith<$Res>? get account;

}
/// @nodoc
class __$SyncProgressCopyWithImpl<$Res>
    implements _$SyncProgressCopyWith<$Res> {
  __$SyncProgressCopyWithImpl(this._self, this._then);

  final _SyncProgress _self;
  final $Res Function(_SyncProgress) _then;

/// Create a copy of SyncProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? account = freezed,Object? categories = null,Object? channels = null,Object? movies = null,Object? series = null,Object? episodes = null,Object? stageTotal = freezed,}) {
  return _then(_SyncProgress(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as SyncStage,account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as ProviderAccount?,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,series: null == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int,stageTotal: freezed == stageTotal ? _self.stageTotal : stageTotal // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of SyncProgress
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
}
}

/// @nodoc
mixin _$SyncReport {

 int get categories; int get channels; int get movies; int get series; int get episodes;/// Rows the provider sent that couldn't be used (hard rule 1).
 int get skipped;/// Items and categories deleted because the provider no longer has
/// them.
 int get removed; Duration get duration;
/// Create a copy of SyncReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncReportCopyWith<SyncReport> get copyWith => _$SyncReportCopyWithImpl<SyncReport>(this as SyncReport, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SyncReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncReport&&(identical(other.categories, _this.categories) || other.categories == _this.categories)&&(identical(other.channels, _this.channels) || other.channels == _this.channels)&&(identical(other.movies, _this.movies) || other.movies == _this.movies)&&(identical(other.series, _this.series) || other.series == _this.series)&&(identical(other.episodes, _this.episodes) || other.episodes == _this.episodes)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped)&&(identical(other.removed, _this.removed) || other.removed == _this.removed)&&(identical(other.duration, _this.duration) || other.duration == _this.duration));
}


@override
int get hashCode {
  final _this = this as SyncReport;
  return Object.hash(runtimeType,_this.categories,_this.channels,_this.movies,_this.series,_this.episodes,_this.skipped,_this.removed,_this.duration);
}

@override
String toString() {
  final _this = this as SyncReport;
  return 'SyncReport(categories: ${_this.categories}, channels: ${_this.channels}, movies: ${_this.movies}, series: ${_this.series}, episodes: ${_this.episodes}, skipped: ${_this.skipped}, removed: ${_this.removed}, duration: ${_this.duration})';
}


}

/// @nodoc
abstract mixin class $SyncReportCopyWith<$Res>  {
  factory $SyncReportCopyWith(SyncReport value, $Res Function(SyncReport) _then) = _$SyncReportCopyWithImpl;
@useResult
$Res call({
 int categories, int channels, int movies, int series, int episodes, int skipped, int removed, Duration duration
});




}
/// @nodoc
class _$SyncReportCopyWithImpl<$Res>
    implements $SyncReportCopyWith<$Res> {
  _$SyncReportCopyWithImpl(this._self, this._then);

  final SyncReport _self;
  final $Res Function(SyncReport) _then;

/// Create a copy of SyncReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? categories = null,Object? channels = null,Object? movies = null,Object? series = null,Object? episodes = null,Object? skipped = null,Object? removed = null,Object? duration = null,}) {
  return _then(SyncReport(
categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,series: null == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,removed: null == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncReport].
extension SyncReportPatterns on SyncReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncReport value)  $default,){
final _that = this;
switch (_that) {
case _SyncReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncReport value)?  $default,){
final _that = this;
switch (_that) {
case _SyncReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int categories,  int channels,  int movies,  int series,  int episodes,  int skipped,  int removed,  Duration duration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncReport() when $default != null:
return $default(_that.categories,_that.channels,_that.movies,_that.series,_that.episodes,_that.skipped,_that.removed,_that.duration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int categories,  int channels,  int movies,  int series,  int episodes,  int skipped,  int removed,  Duration duration)  $default,) {final _that = this;
switch (_that) {
case _SyncReport():
return $default(_that.categories,_that.channels,_that.movies,_that.series,_that.episodes,_that.skipped,_that.removed,_that.duration);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int categories,  int channels,  int movies,  int series,  int episodes,  int skipped,  int removed,  Duration duration)?  $default,) {final _that = this;
switch (_that) {
case _SyncReport() when $default != null:
return $default(_that.categories,_that.channels,_that.movies,_that.series,_that.episodes,_that.skipped,_that.removed,_that.duration);case _:
  return null;

}
}

}

/// @nodoc


class _SyncReport implements SyncReport {
  const _SyncReport({this.categories = 0, this.channels = 0, this.movies = 0, this.series = 0, this.episodes = 0, this.skipped = 0, this.removed = 0, this.duration = Duration.zero});
  

@override@JsonKey() final  int categories;
@override@JsonKey() final  int channels;
@override@JsonKey() final  int movies;
@override@JsonKey() final  int series;
@override@JsonKey() final  int episodes;
/// Rows the provider sent that couldn't be used (hard rule 1).
@override@JsonKey() final  int skipped;
/// Items and categories deleted because the provider no longer has
/// them.
@override@JsonKey() final  int removed;
@override@JsonKey() final  Duration duration;

/// Create a copy of SyncReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncReportCopyWith<_SyncReport> get copyWith => __$SyncReportCopyWithImpl<_SyncReport>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncReport&&(identical(other.categories, categories) || other.categories == categories)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.series, series) || other.series == series)&&(identical(other.episodes, episodes) || other.episodes == episodes)&&(identical(other.skipped, skipped) || other.skipped == skipped)&&(identical(other.removed, removed) || other.removed == removed)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode {
    return Object.hash(runtimeType,categories,channels,movies,series,episodes,skipped,removed,duration);
}

@override
String toString() {
    return 'SyncReport(categories: $categories, channels: $channels, movies: $movies, series: $series, episodes: $episodes, skipped: $skipped, removed: $removed, duration: $duration)';
}


}

/// @nodoc
abstract mixin class _$SyncReportCopyWith<$Res> implements $SyncReportCopyWith<$Res> {
  factory _$SyncReportCopyWith(_SyncReport value, $Res Function(_SyncReport) _then) = __$SyncReportCopyWithImpl;
@override @useResult
$Res call({
 int categories, int channels, int movies, int series, int episodes, int skipped, int removed, Duration duration
});




}
/// @nodoc
class __$SyncReportCopyWithImpl<$Res>
    implements _$SyncReportCopyWith<$Res> {
  __$SyncReportCopyWithImpl(this._self, this._then);

  final _SyncReport _self;
  final $Res Function(_SyncReport) _then;

/// Create a copy of SyncReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? categories = null,Object? channels = null,Object? movies = null,Object? series = null,Object? episodes = null,Object? skipped = null,Object? removed = null,Object? duration = null,}) {
  return _then(_SyncReport(
categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,series: null == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,removed: null == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

// dart format on
