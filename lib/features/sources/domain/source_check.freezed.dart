// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_check.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SourceCheck {

/// The server's host, or the file's name: safe to show.
 String get where;/// How long the server took to answer, or the file to open.
 Duration get responseTime;/// Xtream only: the account the panel signed in.
 ProviderAccount? get account;/// M3U only: what the start of the playlist holds.
 PlaylistPreview? get playlist;
/// Create a copy of SourceCheck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceCheckCopyWith<SourceCheck> get copyWith => _$SourceCheckCopyWithImpl<SourceCheck>(this as SourceCheck, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceCheck;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceCheck&&(identical(other.where, _this.where) || other.where == _this.where)&&(identical(other.responseTime, _this.responseTime) || other.responseTime == _this.responseTime)&&(identical(other.account, _this.account) || other.account == _this.account)&&(identical(other.playlist, _this.playlist) || other.playlist == _this.playlist));
}


@override
int get hashCode {
  final _this = this as SourceCheck;
  return Object.hash(runtimeType,_this.where,_this.responseTime,_this.account,_this.playlist);
}

@override
String toString() {
  final _this = this as SourceCheck;
  return 'SourceCheck(where: ${_this.where}, responseTime: ${_this.responseTime}, account: ${_this.account}, playlist: ${_this.playlist})';
}


}

/// @nodoc
abstract mixin class $SourceCheckCopyWith<$Res>  {
  factory $SourceCheckCopyWith(SourceCheck value, $Res Function(SourceCheck) _then) = _$SourceCheckCopyWithImpl;
@useResult
$Res call({
 String where, Duration responseTime, ProviderAccount? account, PlaylistPreview? playlist
});


$ProviderAccountCopyWith<$Res>? get account;$PlaylistPreviewCopyWith<$Res>? get playlist;

}
/// @nodoc
class _$SourceCheckCopyWithImpl<$Res>
    implements $SourceCheckCopyWith<$Res> {
  _$SourceCheckCopyWithImpl(this._self, this._then);

  final SourceCheck _self;
  final $Res Function(SourceCheck) _then;

/// Create a copy of SourceCheck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? where = null,Object? responseTime = null,Object? account = freezed,Object? playlist = freezed,}) {
  return _then(SourceCheck(
where: null == where ? _self.where : where // ignore: cast_nullable_to_non_nullable
as String,responseTime: null == responseTime ? _self.responseTime : responseTime // ignore: cast_nullable_to_non_nullable
as Duration,account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as ProviderAccount?,playlist: freezed == playlist ? _self.playlist : playlist // ignore: cast_nullable_to_non_nullable
as PlaylistPreview?,
  ));
}
/// Create a copy of SourceCheck
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
}/// Create a copy of SourceCheck
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaylistPreviewCopyWith<$Res>? get playlist {
    if (_self.playlist == null) {
    return null;
  }

  return $PlaylistPreviewCopyWith<$Res>(_self.playlist!, (value) {
    return _then(_self.copyWith(playlist: value));
  });
}
}


/// Adds pattern-matching-related methods to [SourceCheck].
extension SourceCheckPatterns on SourceCheck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceCheck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceCheck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceCheck value)  $default,){
final _that = this;
switch (_that) {
case _SourceCheck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceCheck value)?  $default,){
final _that = this;
switch (_that) {
case _SourceCheck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String where,  Duration responseTime,  ProviderAccount? account,  PlaylistPreview? playlist)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceCheck() when $default != null:
return $default(_that.where,_that.responseTime,_that.account,_that.playlist);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String where,  Duration responseTime,  ProviderAccount? account,  PlaylistPreview? playlist)  $default,) {final _that = this;
switch (_that) {
case _SourceCheck():
return $default(_that.where,_that.responseTime,_that.account,_that.playlist);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String where,  Duration responseTime,  ProviderAccount? account,  PlaylistPreview? playlist)?  $default,) {final _that = this;
switch (_that) {
case _SourceCheck() when $default != null:
return $default(_that.where,_that.responseTime,_that.account,_that.playlist);case _:
  return null;

}
}

}

/// @nodoc


class _SourceCheck implements SourceCheck {
  const _SourceCheck({required this.where, required this.responseTime, this.account, this.playlist});
  

/// The server's host, or the file's name: safe to show.
@override final  String where;
/// How long the server took to answer, or the file to open.
@override final  Duration responseTime;
/// Xtream only: the account the panel signed in.
@override final  ProviderAccount? account;
/// M3U only: what the start of the playlist holds.
@override final  PlaylistPreview? playlist;

/// Create a copy of SourceCheck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceCheckCopyWith<_SourceCheck> get copyWith => __$SourceCheckCopyWithImpl<_SourceCheck>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceCheck&&(identical(other.where, where) || other.where == where)&&(identical(other.responseTime, responseTime) || other.responseTime == responseTime)&&(identical(other.account, account) || other.account == account)&&(identical(other.playlist, playlist) || other.playlist == playlist));
}


@override
int get hashCode {
    return Object.hash(runtimeType,where,responseTime,account,playlist);
}

@override
String toString() {
    return 'SourceCheck(where: $where, responseTime: $responseTime, account: $account, playlist: $playlist)';
}


}

/// @nodoc
abstract mixin class _$SourceCheckCopyWith<$Res> implements $SourceCheckCopyWith<$Res> {
  factory _$SourceCheckCopyWith(_SourceCheck value, $Res Function(_SourceCheck) _then) = __$SourceCheckCopyWithImpl;
@override @useResult
$Res call({
 String where, Duration responseTime, ProviderAccount? account, PlaylistPreview? playlist
});


@override $ProviderAccountCopyWith<$Res>? get account;@override $PlaylistPreviewCopyWith<$Res>? get playlist;

}
/// @nodoc
class __$SourceCheckCopyWithImpl<$Res>
    implements _$SourceCheckCopyWith<$Res> {
  __$SourceCheckCopyWithImpl(this._self, this._then);

  final _SourceCheck _self;
  final $Res Function(_SourceCheck) _then;

/// Create a copy of SourceCheck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? where = null,Object? responseTime = null,Object? account = freezed,Object? playlist = freezed,}) {
  return _then(_SourceCheck(
where: null == where ? _self.where : where // ignore: cast_nullable_to_non_nullable
as String,responseTime: null == responseTime ? _self.responseTime : responseTime // ignore: cast_nullable_to_non_nullable
as Duration,account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as ProviderAccount?,playlist: freezed == playlist ? _self.playlist : playlist // ignore: cast_nullable_to_non_nullable
as PlaylistPreview?,
  ));
}

/// Create a copy of SourceCheck
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
}/// Create a copy of SourceCheck
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaylistPreviewCopyWith<$Res>? get playlist {
    if (_self.playlist == null) {
    return null;
  }

  return $PlaylistPreviewCopyWith<$Res>(_self.playlist!, (value) {
    return _then(_self.copyWith(playlist: value));
  });
}
}

/// @nodoc
mixin _$PlaylistPreview {

 bool get complete; int get entries; int get live; int get movies; int get episodes;/// The file's size; null for a URL.
 int? get bytes;
/// Create a copy of PlaylistPreview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaylistPreviewCopyWith<PlaylistPreview> get copyWith => _$PlaylistPreviewCopyWithImpl<PlaylistPreview>(this as PlaylistPreview, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlaylistPreview;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaylistPreview&&(identical(other.complete, _this.complete) || other.complete == _this.complete)&&(identical(other.entries, _this.entries) || other.entries == _this.entries)&&(identical(other.live, _this.live) || other.live == _this.live)&&(identical(other.movies, _this.movies) || other.movies == _this.movies)&&(identical(other.episodes, _this.episodes) || other.episodes == _this.episodes)&&(identical(other.bytes, _this.bytes) || other.bytes == _this.bytes));
}


@override
int get hashCode {
  final _this = this as PlaylistPreview;
  return Object.hash(runtimeType,_this.complete,_this.entries,_this.live,_this.movies,_this.episodes,_this.bytes);
}

@override
String toString() {
  final _this = this as PlaylistPreview;
  return 'PlaylistPreview(complete: ${_this.complete}, entries: ${_this.entries}, live: ${_this.live}, movies: ${_this.movies}, episodes: ${_this.episodes}, bytes: ${_this.bytes})';
}


}

/// @nodoc
abstract mixin class $PlaylistPreviewCopyWith<$Res>  {
  factory $PlaylistPreviewCopyWith(PlaylistPreview value, $Res Function(PlaylistPreview) _then) = _$PlaylistPreviewCopyWithImpl;
@useResult
$Res call({
 bool complete, int entries, int live, int movies, int episodes, int? bytes
});




}
/// @nodoc
class _$PlaylistPreviewCopyWithImpl<$Res>
    implements $PlaylistPreviewCopyWith<$Res> {
  _$PlaylistPreviewCopyWithImpl(this._self, this._then);

  final PlaylistPreview _self;
  final $Res Function(PlaylistPreview) _then;

/// Create a copy of PlaylistPreview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? complete = null,Object? entries = null,Object? live = null,Object? movies = null,Object? episodes = null,Object? bytes = freezed,}) {
  return _then(PlaylistPreview(
complete: null == complete ? _self.complete : complete // ignore: cast_nullable_to_non_nullable
as bool,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as int,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int,bytes: freezed == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlaylistPreview].
extension PlaylistPreviewPatterns on PlaylistPreview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaylistPreview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaylistPreview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaylistPreview value)  $default,){
final _that = this;
switch (_that) {
case _PlaylistPreview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaylistPreview value)?  $default,){
final _that = this;
switch (_that) {
case _PlaylistPreview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool complete,  int entries,  int live,  int movies,  int episodes,  int? bytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaylistPreview() when $default != null:
return $default(_that.complete,_that.entries,_that.live,_that.movies,_that.episodes,_that.bytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool complete,  int entries,  int live,  int movies,  int episodes,  int? bytes)  $default,) {final _that = this;
switch (_that) {
case _PlaylistPreview():
return $default(_that.complete,_that.entries,_that.live,_that.movies,_that.episodes,_that.bytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool complete,  int entries,  int live,  int movies,  int episodes,  int? bytes)?  $default,) {final _that = this;
switch (_that) {
case _PlaylistPreview() when $default != null:
return $default(_that.complete,_that.entries,_that.live,_that.movies,_that.episodes,_that.bytes);case _:
  return null;

}
}

}

/// @nodoc


class _PlaylistPreview implements PlaylistPreview {
  const _PlaylistPreview({required this.complete, this.entries = 0, this.live = 0, this.movies = 0, this.episodes = 0, this.bytes});
  

@override final  bool complete;
@override@JsonKey() final  int entries;
@override@JsonKey() final  int live;
@override@JsonKey() final  int movies;
@override@JsonKey() final  int episodes;
/// The file's size; null for a URL.
@override final  int? bytes;

/// Create a copy of PlaylistPreview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaylistPreviewCopyWith<_PlaylistPreview> get copyWith => __$PlaylistPreviewCopyWithImpl<_PlaylistPreview>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaylistPreview&&(identical(other.complete, complete) || other.complete == complete)&&(identical(other.entries, entries) || other.entries == entries)&&(identical(other.live, live) || other.live == live)&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.episodes, episodes) || other.episodes == episodes)&&(identical(other.bytes, bytes) || other.bytes == bytes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,complete,entries,live,movies,episodes,bytes);
}

@override
String toString() {
    return 'PlaylistPreview(complete: $complete, entries: $entries, live: $live, movies: $movies, episodes: $episodes, bytes: $bytes)';
}


}

/// @nodoc
abstract mixin class _$PlaylistPreviewCopyWith<$Res> implements $PlaylistPreviewCopyWith<$Res> {
  factory _$PlaylistPreviewCopyWith(_PlaylistPreview value, $Res Function(_PlaylistPreview) _then) = __$PlaylistPreviewCopyWithImpl;
@override @useResult
$Res call({
 bool complete, int entries, int live, int movies, int episodes, int? bytes
});




}
/// @nodoc
class __$PlaylistPreviewCopyWithImpl<$Res>
    implements _$PlaylistPreviewCopyWith<$Res> {
  __$PlaylistPreviewCopyWithImpl(this._self, this._then);

  final _PlaylistPreview _self;
  final $Res Function(_PlaylistPreview) _then;

/// Create a copy of PlaylistPreview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? complete = null,Object? entries = null,Object? live = null,Object? movies = null,Object? episodes = null,Object? bytes = freezed,}) {
  return _then(_PlaylistPreview(
complete: null == complete ? _self.complete : complete // ignore: cast_nullable_to_non_nullable
as bool,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as int,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int,bytes: freezed == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
