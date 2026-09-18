// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'm3u_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$M3uEntry {

/// The stable identity: a hash of `tvg-id`, the name and the URL path
/// without credentials, so favourites and history survive a refresh
/// and a password change. The entry's `remote_key`.
 String get identity; M3uKind get kind; String get name;/// With the source's credentials replaced by `{username}`-style
/// placeholders (`M3uCredentials`), never the real values.
 String get streamUrl;/// Its position in the playlist, from 0.
 int get position; String? get tvgId; String? get tvgName; String? get logoUrl;/// `group-title`, or `#EXTGRP` when there is none.
 String? get group; int? get channelNumber;/// `catchup`: `default`, `append`, `shift`, `flussonic`, `xc`…
 String? get catchup; int? get catchupDays; String? get catchupSource;/// From `#EXTVLCOPT` lines just before the URL.
 String? get userAgent; String? get referrer;/// For episodes whose name says so (`Dark S01 E02`).
 String? get seriesName; int? get season; int? get episode;
/// Create a copy of M3uEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$M3uEntryCopyWith<M3uEntry> get copyWith => _$M3uEntryCopyWithImpl<M3uEntry>(this as M3uEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as M3uEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is M3uEntry&&(identical(other.identity, _this.identity) || other.identity == _this.identity)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.streamUrl, _this.streamUrl) || other.streamUrl == _this.streamUrl)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.tvgId, _this.tvgId) || other.tvgId == _this.tvgId)&&(identical(other.tvgName, _this.tvgName) || other.tvgName == _this.tvgName)&&(identical(other.logoUrl, _this.logoUrl) || other.logoUrl == _this.logoUrl)&&(identical(other.group, _this.group) || other.group == _this.group)&&(identical(other.channelNumber, _this.channelNumber) || other.channelNumber == _this.channelNumber)&&(identical(other.catchup, _this.catchup) || other.catchup == _this.catchup)&&(identical(other.catchupDays, _this.catchupDays) || other.catchupDays == _this.catchupDays)&&(identical(other.catchupSource, _this.catchupSource) || other.catchupSource == _this.catchupSource)&&(identical(other.userAgent, _this.userAgent) || other.userAgent == _this.userAgent)&&(identical(other.referrer, _this.referrer) || other.referrer == _this.referrer)&&(identical(other.seriesName, _this.seriesName) || other.seriesName == _this.seriesName)&&(identical(other.season, _this.season) || other.season == _this.season)&&(identical(other.episode, _this.episode) || other.episode == _this.episode));
}


@override
int get hashCode {
  final _this = this as M3uEntry;
  return Object.hash(runtimeType,_this.identity,_this.kind,_this.name,_this.streamUrl,_this.position,_this.tvgId,_this.tvgName,_this.logoUrl,_this.group,_this.channelNumber,_this.catchup,_this.catchupDays,_this.catchupSource,_this.userAgent,_this.referrer,_this.seriesName,_this.season,_this.episode);
}

@override
String toString() {
  final _this = this as M3uEntry;
  return 'M3uEntry(identity: ${_this.identity}, kind: ${_this.kind}, name: ${_this.name}, streamUrl: ${_this.streamUrl}, position: ${_this.position}, tvgId: ${_this.tvgId}, tvgName: ${_this.tvgName}, logoUrl: ${_this.logoUrl}, group: ${_this.group}, channelNumber: ${_this.channelNumber}, catchup: ${_this.catchup}, catchupDays: ${_this.catchupDays}, catchupSource: ${_this.catchupSource}, userAgent: ${_this.userAgent}, referrer: ${_this.referrer}, seriesName: ${_this.seriesName}, season: ${_this.season}, episode: ${_this.episode})';
}


}

/// @nodoc
abstract mixin class $M3uEntryCopyWith<$Res>  {
  factory $M3uEntryCopyWith(M3uEntry value, $Res Function(M3uEntry) _then) = _$M3uEntryCopyWithImpl;
@useResult
$Res call({
 String identity, M3uKind kind, String name, String streamUrl, int position, String? tvgId, String? tvgName, String? logoUrl, String? group, int? channelNumber, String? catchup, int? catchupDays, String? catchupSource, String? userAgent, String? referrer, String? seriesName, int? season, int? episode
});




}
/// @nodoc
class _$M3uEntryCopyWithImpl<$Res>
    implements $M3uEntryCopyWith<$Res> {
  _$M3uEntryCopyWithImpl(this._self, this._then);

  final M3uEntry _self;
  final $Res Function(M3uEntry) _then;

/// Create a copy of M3uEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? identity = null,Object? kind = null,Object? name = null,Object? streamUrl = null,Object? position = null,Object? tvgId = freezed,Object? tvgName = freezed,Object? logoUrl = freezed,Object? group = freezed,Object? channelNumber = freezed,Object? catchup = freezed,Object? catchupDays = freezed,Object? catchupSource = freezed,Object? userAgent = freezed,Object? referrer = freezed,Object? seriesName = freezed,Object? season = freezed,Object? episode = freezed,}) {
  return _then(M3uEntry(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as M3uKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,streamUrl: null == streamUrl ? _self.streamUrl : streamUrl // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,tvgId: freezed == tvgId ? _self.tvgId : tvgId // ignore: cast_nullable_to_non_nullable
as String?,tvgName: freezed == tvgName ? _self.tvgName : tvgName // ignore: cast_nullable_to_non_nullable
as String?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,channelNumber: freezed == channelNumber ? _self.channelNumber : channelNumber // ignore: cast_nullable_to_non_nullable
as int?,catchup: freezed == catchup ? _self.catchup : catchup // ignore: cast_nullable_to_non_nullable
as String?,catchupDays: freezed == catchupDays ? _self.catchupDays : catchupDays // ignore: cast_nullable_to_non_nullable
as int?,catchupSource: freezed == catchupSource ? _self.catchupSource : catchupSource // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,referrer: freezed == referrer ? _self.referrer : referrer // ignore: cast_nullable_to_non_nullable
as String?,seriesName: freezed == seriesName ? _self.seriesName : seriesName // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [M3uEntry].
extension M3uEntryPatterns on M3uEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _M3uEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _M3uEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _M3uEntry value)  $default,){
final _that = this;
switch (_that) {
case _M3uEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _M3uEntry value)?  $default,){
final _that = this;
switch (_that) {
case _M3uEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String identity,  M3uKind kind,  String name,  String streamUrl,  int position,  String? tvgId,  String? tvgName,  String? logoUrl,  String? group,  int? channelNumber,  String? catchup,  int? catchupDays,  String? catchupSource,  String? userAgent,  String? referrer,  String? seriesName,  int? season,  int? episode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _M3uEntry() when $default != null:
return $default(_that.identity,_that.kind,_that.name,_that.streamUrl,_that.position,_that.tvgId,_that.tvgName,_that.logoUrl,_that.group,_that.channelNumber,_that.catchup,_that.catchupDays,_that.catchupSource,_that.userAgent,_that.referrer,_that.seriesName,_that.season,_that.episode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String identity,  M3uKind kind,  String name,  String streamUrl,  int position,  String? tvgId,  String? tvgName,  String? logoUrl,  String? group,  int? channelNumber,  String? catchup,  int? catchupDays,  String? catchupSource,  String? userAgent,  String? referrer,  String? seriesName,  int? season,  int? episode)  $default,) {final _that = this;
switch (_that) {
case _M3uEntry():
return $default(_that.identity,_that.kind,_that.name,_that.streamUrl,_that.position,_that.tvgId,_that.tvgName,_that.logoUrl,_that.group,_that.channelNumber,_that.catchup,_that.catchupDays,_that.catchupSource,_that.userAgent,_that.referrer,_that.seriesName,_that.season,_that.episode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String identity,  M3uKind kind,  String name,  String streamUrl,  int position,  String? tvgId,  String? tvgName,  String? logoUrl,  String? group,  int? channelNumber,  String? catchup,  int? catchupDays,  String? catchupSource,  String? userAgent,  String? referrer,  String? seriesName,  int? season,  int? episode)?  $default,) {final _that = this;
switch (_that) {
case _M3uEntry() when $default != null:
return $default(_that.identity,_that.kind,_that.name,_that.streamUrl,_that.position,_that.tvgId,_that.tvgName,_that.logoUrl,_that.group,_that.channelNumber,_that.catchup,_that.catchupDays,_that.catchupSource,_that.userAgent,_that.referrer,_that.seriesName,_that.season,_that.episode);case _:
  return null;

}
}

}

/// @nodoc


class _M3uEntry implements M3uEntry {
  const _M3uEntry({required this.identity, required this.kind, required this.name, required this.streamUrl, required this.position, this.tvgId, this.tvgName, this.logoUrl, this.group, this.channelNumber, this.catchup, this.catchupDays, this.catchupSource, this.userAgent, this.referrer, this.seriesName, this.season, this.episode});
  

/// The stable identity: a hash of `tvg-id`, the name and the URL path
/// without credentials, so favourites and history survive a refresh
/// and a password change. The entry's `remote_key`.
@override final  String identity;
@override final  M3uKind kind;
@override final  String name;
/// With the source's credentials replaced by `{username}`-style
/// placeholders (`M3uCredentials`), never the real values.
@override final  String streamUrl;
/// Its position in the playlist, from 0.
@override final  int position;
@override final  String? tvgId;
@override final  String? tvgName;
@override final  String? logoUrl;
/// `group-title`, or `#EXTGRP` when there is none.
@override final  String? group;
@override final  int? channelNumber;
/// `catchup`: `default`, `append`, `shift`, `flussonic`, `xc`…
@override final  String? catchup;
@override final  int? catchupDays;
@override final  String? catchupSource;
/// From `#EXTVLCOPT` lines just before the URL.
@override final  String? userAgent;
@override final  String? referrer;
/// For episodes whose name says so (`Dark S01 E02`).
@override final  String? seriesName;
@override final  int? season;
@override final  int? episode;

/// Create a copy of M3uEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$M3uEntryCopyWith<_M3uEntry> get copyWith => __$M3uEntryCopyWithImpl<_M3uEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _M3uEntry&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.streamUrl, streamUrl) || other.streamUrl == streamUrl)&&(identical(other.position, position) || other.position == position)&&(identical(other.tvgId, tvgId) || other.tvgId == tvgId)&&(identical(other.tvgName, tvgName) || other.tvgName == tvgName)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.group, group) || other.group == group)&&(identical(other.channelNumber, channelNumber) || other.channelNumber == channelNumber)&&(identical(other.catchup, catchup) || other.catchup == catchup)&&(identical(other.catchupDays, catchupDays) || other.catchupDays == catchupDays)&&(identical(other.catchupSource, catchupSource) || other.catchupSource == catchupSource)&&(identical(other.userAgent, userAgent) || other.userAgent == userAgent)&&(identical(other.referrer, referrer) || other.referrer == referrer)&&(identical(other.seriesName, seriesName) || other.seriesName == seriesName)&&(identical(other.season, season) || other.season == season)&&(identical(other.episode, episode) || other.episode == episode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,identity,kind,name,streamUrl,position,tvgId,tvgName,logoUrl,group,channelNumber,catchup,catchupDays,catchupSource,userAgent,referrer,seriesName,season,episode);
}

@override
String toString() {
    return 'M3uEntry(identity: $identity, kind: $kind, name: $name, streamUrl: $streamUrl, position: $position, tvgId: $tvgId, tvgName: $tvgName, logoUrl: $logoUrl, group: $group, channelNumber: $channelNumber, catchup: $catchup, catchupDays: $catchupDays, catchupSource: $catchupSource, userAgent: $userAgent, referrer: $referrer, seriesName: $seriesName, season: $season, episode: $episode)';
}


}

/// @nodoc
abstract mixin class _$M3uEntryCopyWith<$Res> implements $M3uEntryCopyWith<$Res> {
  factory _$M3uEntryCopyWith(_M3uEntry value, $Res Function(_M3uEntry) _then) = __$M3uEntryCopyWithImpl;
@override @useResult
$Res call({
 String identity, M3uKind kind, String name, String streamUrl, int position, String? tvgId, String? tvgName, String? logoUrl, String? group, int? channelNumber, String? catchup, int? catchupDays, String? catchupSource, String? userAgent, String? referrer, String? seriesName, int? season, int? episode
});




}
/// @nodoc
class __$M3uEntryCopyWithImpl<$Res>
    implements _$M3uEntryCopyWith<$Res> {
  __$M3uEntryCopyWithImpl(this._self, this._then);

  final _M3uEntry _self;
  final $Res Function(_M3uEntry) _then;

/// Create a copy of M3uEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? identity = null,Object? kind = null,Object? name = null,Object? streamUrl = null,Object? position = null,Object? tvgId = freezed,Object? tvgName = freezed,Object? logoUrl = freezed,Object? group = freezed,Object? channelNumber = freezed,Object? catchup = freezed,Object? catchupDays = freezed,Object? catchupSource = freezed,Object? userAgent = freezed,Object? referrer = freezed,Object? seriesName = freezed,Object? season = freezed,Object? episode = freezed,}) {
  return _then(_M3uEntry(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as M3uKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,streamUrl: null == streamUrl ? _self.streamUrl : streamUrl // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,tvgId: freezed == tvgId ? _self.tvgId : tvgId // ignore: cast_nullable_to_non_nullable
as String?,tvgName: freezed == tvgName ? _self.tvgName : tvgName // ignore: cast_nullable_to_non_nullable
as String?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,channelNumber: freezed == channelNumber ? _self.channelNumber : channelNumber // ignore: cast_nullable_to_non_nullable
as int?,catchup: freezed == catchup ? _self.catchup : catchup // ignore: cast_nullable_to_non_nullable
as String?,catchupDays: freezed == catchupDays ? _self.catchupDays : catchupDays // ignore: cast_nullable_to_non_nullable
as int?,catchupSource: freezed == catchupSource ? _self.catchupSource : catchupSource // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,referrer: freezed == referrer ? _self.referrer : referrer // ignore: cast_nullable_to_non_nullable
as String?,seriesName: freezed == seriesName ? _self.seriesName : seriesName // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$M3uSummary {

/// `url-tvg` / `x-tvg-url` / `tvg-url` from the `#EXTM3U` line; a
/// comma-separated list is split. Credentials in them are left as
/// sent: the caller keeps these in the secure store (ADR-009).
 List<String> get epgUrls; int get entries; int get live; int get movies; int get episodes;/// Lines that couldn't become an entry: an `#EXTINF` with no URL, a
/// URL that isn't one, a repeated identity.
 int get skipped;
/// Create a copy of M3uSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$M3uSummaryCopyWith<M3uSummary> get copyWith => _$M3uSummaryCopyWithImpl<M3uSummary>(this as M3uSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as M3uSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is M3uSummary&&const DeepCollectionEquality().equals(other.epgUrls, _this.epgUrls)&&(identical(other.entries, _this.entries) || other.entries == _this.entries)&&(identical(other.live, _this.live) || other.live == _this.live)&&(identical(other.movies, _this.movies) || other.movies == _this.movies)&&(identical(other.episodes, _this.episodes) || other.episodes == _this.episodes)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped));
}


@override
int get hashCode {
  final _this = this as M3uSummary;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.epgUrls),_this.entries,_this.live,_this.movies,_this.episodes,_this.skipped);
}

@override
String toString() {
  final _this = this as M3uSummary;
  return 'M3uSummary(epgUrls: ${_this.epgUrls}, entries: ${_this.entries}, live: ${_this.live}, movies: ${_this.movies}, episodes: ${_this.episodes}, skipped: ${_this.skipped})';
}


}

/// @nodoc
abstract mixin class $M3uSummaryCopyWith<$Res>  {
  factory $M3uSummaryCopyWith(M3uSummary value, $Res Function(M3uSummary) _then) = _$M3uSummaryCopyWithImpl;
@useResult
$Res call({
 List<String> epgUrls, int entries, int live, int movies, int episodes, int skipped
});




}
/// @nodoc
class _$M3uSummaryCopyWithImpl<$Res>
    implements $M3uSummaryCopyWith<$Res> {
  _$M3uSummaryCopyWithImpl(this._self, this._then);

  final M3uSummary _self;
  final $Res Function(M3uSummary) _then;

/// Create a copy of M3uSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? epgUrls = null,Object? entries = null,Object? live = null,Object? movies = null,Object? episodes = null,Object? skipped = null,}) {
  return _then(M3uSummary(
epgUrls: null == epgUrls ? _self.epgUrls : epgUrls // ignore: cast_nullable_to_non_nullable
as List<String>,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as int,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [M3uSummary].
extension M3uSummaryPatterns on M3uSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _M3uSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _M3uSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _M3uSummary value)  $default,){
final _that = this;
switch (_that) {
case _M3uSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _M3uSummary value)?  $default,){
final _that = this;
switch (_that) {
case _M3uSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> epgUrls,  int entries,  int live,  int movies,  int episodes,  int skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _M3uSummary() when $default != null:
return $default(_that.epgUrls,_that.entries,_that.live,_that.movies,_that.episodes,_that.skipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> epgUrls,  int entries,  int live,  int movies,  int episodes,  int skipped)  $default,) {final _that = this;
switch (_that) {
case _M3uSummary():
return $default(_that.epgUrls,_that.entries,_that.live,_that.movies,_that.episodes,_that.skipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> epgUrls,  int entries,  int live,  int movies,  int episodes,  int skipped)?  $default,) {final _that = this;
switch (_that) {
case _M3uSummary() when $default != null:
return $default(_that.epgUrls,_that.entries,_that.live,_that.movies,_that.episodes,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc


class _M3uSummary implements M3uSummary {
  const _M3uSummary({ List<String> epgUrls = const <String>[], this.entries = 0, this.live = 0, this.movies = 0, this.episodes = 0, this.skipped = 0}): _epgUrls = epgUrls;
  

/// `url-tvg` / `x-tvg-url` / `tvg-url` from the `#EXTM3U` line; a
/// comma-separated list is split. Credentials in them are left as
/// sent: the caller keeps these in the secure store (ADR-009).
 final  List<String> _epgUrls;
/// `url-tvg` / `x-tvg-url` / `tvg-url` from the `#EXTM3U` line; a
/// comma-separated list is split. Credentials in them are left as
/// sent: the caller keeps these in the secure store (ADR-009).
@override@JsonKey() List<String> get epgUrls {
  if (_epgUrls is EqualUnmodifiableListView) return _epgUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_epgUrls);
}

@override@JsonKey() final  int entries;
@override@JsonKey() final  int live;
@override@JsonKey() final  int movies;
@override@JsonKey() final  int episodes;
/// Lines that couldn't become an entry: an `#EXTINF` with no URL, a
/// URL that isn't one, a repeated identity.
@override@JsonKey() final  int skipped;

/// Create a copy of M3uSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$M3uSummaryCopyWith<_M3uSummary> get copyWith => __$M3uSummaryCopyWithImpl<_M3uSummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _M3uSummary&&const DeepCollectionEquality().equals(other.epgUrls, _epgUrls)&&(identical(other.entries, entries) || other.entries == entries)&&(identical(other.live, live) || other.live == live)&&(identical(other.movies, movies) || other.movies == movies)&&(identical(other.episodes, episodes) || other.episodes == episodes)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_epgUrls),entries,live,movies,episodes,skipped);
}

@override
String toString() {
    return 'M3uSummary(epgUrls: $epgUrls, entries: $entries, live: $live, movies: $movies, episodes: $episodes, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$M3uSummaryCopyWith<$Res> implements $M3uSummaryCopyWith<$Res> {
  factory _$M3uSummaryCopyWith(_M3uSummary value, $Res Function(_M3uSummary) _then) = __$M3uSummaryCopyWithImpl;
@override @useResult
$Res call({
 List<String> epgUrls, int entries, int live, int movies, int episodes, int skipped
});




}
/// @nodoc
class __$M3uSummaryCopyWithImpl<$Res>
    implements _$M3uSummaryCopyWith<$Res> {
  __$M3uSummaryCopyWithImpl(this._self, this._then);

  final _M3uSummary _self;
  final $Res Function(_M3uSummary) _then;

/// Create a copy of M3uSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? epgUrls = null,Object? entries = null,Object? live = null,Object? movies = null,Object? episodes = null,Object? skipped = null,}) {
  return _then(_M3uSummary(
epgUrls: null == epgUrls ? _self._epgUrls : epgUrls // ignore: cast_nullable_to_non_nullable
as List<String>,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as int,live: null == live ? _self.live : live // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
