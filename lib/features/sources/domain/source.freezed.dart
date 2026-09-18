// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Source {

 String get id; SourceType get type; String get name;/// The Xtream server, the playlist URL's origin (`http://host/…`), or
/// the local file path, depending on [type].
 String get displayUrl; LiveFormat get liveFormat; int get epgOffsetMinutes; int get refreshHours; int get sortOrder; DateTime get createdAt; DateTime get updatedAt; String? get username;/// The EPG URL override's origin, like [displayUrl].
 String? get epgUrlDisplay; String? get userAgent; int? get maxConnectionsOverride; DateTime? get expiresAt; DateTime? get lastSyncedAt;
/// Create a copy of Source
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceCopyWith<Source> get copyWith => _$SourceCopyWithImpl<Source>(this as Source, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Source;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Source&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.displayUrl, _this.displayUrl) || other.displayUrl == _this.displayUrl)&&(identical(other.liveFormat, _this.liveFormat) || other.liveFormat == _this.liveFormat)&&(identical(other.epgOffsetMinutes, _this.epgOffsetMinutes) || other.epgOffsetMinutes == _this.epgOffsetMinutes)&&(identical(other.refreshHours, _this.refreshHours) || other.refreshHours == _this.refreshHours)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.epgUrlDisplay, _this.epgUrlDisplay) || other.epgUrlDisplay == _this.epgUrlDisplay)&&(identical(other.userAgent, _this.userAgent) || other.userAgent == _this.userAgent)&&(identical(other.maxConnectionsOverride, _this.maxConnectionsOverride) || other.maxConnectionsOverride == _this.maxConnectionsOverride)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.lastSyncedAt, _this.lastSyncedAt) || other.lastSyncedAt == _this.lastSyncedAt));
}


@override
int get hashCode {
  final _this = this as Source;
  return Object.hash(runtimeType,_this.id,_this.type,_this.name,_this.displayUrl,_this.liveFormat,_this.epgOffsetMinutes,_this.refreshHours,_this.sortOrder,_this.createdAt,_this.updatedAt,_this.username,_this.epgUrlDisplay,_this.userAgent,_this.maxConnectionsOverride,_this.expiresAt,_this.lastSyncedAt);
}

@override
String toString() {
  final _this = this as Source;
  return 'Source(id: ${_this.id}, type: ${_this.type}, name: ${_this.name}, displayUrl: ${_this.displayUrl}, liveFormat: ${_this.liveFormat}, epgOffsetMinutes: ${_this.epgOffsetMinutes}, refreshHours: ${_this.refreshHours}, sortOrder: ${_this.sortOrder}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, username: ${_this.username}, epgUrlDisplay: ${_this.epgUrlDisplay}, userAgent: ${_this.userAgent}, maxConnectionsOverride: ${_this.maxConnectionsOverride}, expiresAt: ${_this.expiresAt}, lastSyncedAt: ${_this.lastSyncedAt})';
}


}

/// @nodoc
abstract mixin class $SourceCopyWith<$Res>  {
  factory $SourceCopyWith(Source value, $Res Function(Source) _then) = _$SourceCopyWithImpl;
@useResult
$Res call({
 String id, SourceType type, String name, String displayUrl, LiveFormat liveFormat, int epgOffsetMinutes, int refreshHours, int sortOrder, DateTime createdAt, DateTime updatedAt, String? username, String? epgUrlDisplay, String? userAgent, int? maxConnectionsOverride, DateTime? expiresAt, DateTime? lastSyncedAt
});




}
/// @nodoc
class _$SourceCopyWithImpl<$Res>
    implements $SourceCopyWith<$Res> {
  _$SourceCopyWithImpl(this._self, this._then);

  final Source _self;
  final $Res Function(Source) _then;

/// Create a copy of Source
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? name = null,Object? displayUrl = null,Object? liveFormat = null,Object? epgOffsetMinutes = null,Object? refreshHours = null,Object? sortOrder = null,Object? createdAt = null,Object? updatedAt = null,Object? username = freezed,Object? epgUrlDisplay = freezed,Object? userAgent = freezed,Object? maxConnectionsOverride = freezed,Object? expiresAt = freezed,Object? lastSyncedAt = freezed,}) {
  return _then(Source(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SourceType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayUrl: null == displayUrl ? _self.displayUrl : displayUrl // ignore: cast_nullable_to_non_nullable
as String,liveFormat: null == liveFormat ? _self.liveFormat : liveFormat // ignore: cast_nullable_to_non_nullable
as LiveFormat,epgOffsetMinutes: null == epgOffsetMinutes ? _self.epgOffsetMinutes : epgOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,refreshHours: null == refreshHours ? _self.refreshHours : refreshHours // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,epgUrlDisplay: freezed == epgUrlDisplay ? _self.epgUrlDisplay : epgUrlDisplay // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,maxConnectionsOverride: freezed == maxConnectionsOverride ? _self.maxConnectionsOverride : maxConnectionsOverride // ignore: cast_nullable_to_non_nullable
as int?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Source].
extension SourcePatterns on Source {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Source value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Source() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Source value)  $default,){
final _that = this;
switch (_that) {
case _Source():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Source value)?  $default,){
final _that = this;
switch (_that) {
case _Source() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  SourceType type,  String name,  String displayUrl,  LiveFormat liveFormat,  int epgOffsetMinutes,  int refreshHours,  int sortOrder,  DateTime createdAt,  DateTime updatedAt,  String? username,  String? epgUrlDisplay,  String? userAgent,  int? maxConnectionsOverride,  DateTime? expiresAt,  DateTime? lastSyncedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Source() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.displayUrl,_that.liveFormat,_that.epgOffsetMinutes,_that.refreshHours,_that.sortOrder,_that.createdAt,_that.updatedAt,_that.username,_that.epgUrlDisplay,_that.userAgent,_that.maxConnectionsOverride,_that.expiresAt,_that.lastSyncedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  SourceType type,  String name,  String displayUrl,  LiveFormat liveFormat,  int epgOffsetMinutes,  int refreshHours,  int sortOrder,  DateTime createdAt,  DateTime updatedAt,  String? username,  String? epgUrlDisplay,  String? userAgent,  int? maxConnectionsOverride,  DateTime? expiresAt,  DateTime? lastSyncedAt)  $default,) {final _that = this;
switch (_that) {
case _Source():
return $default(_that.id,_that.type,_that.name,_that.displayUrl,_that.liveFormat,_that.epgOffsetMinutes,_that.refreshHours,_that.sortOrder,_that.createdAt,_that.updatedAt,_that.username,_that.epgUrlDisplay,_that.userAgent,_that.maxConnectionsOverride,_that.expiresAt,_that.lastSyncedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  SourceType type,  String name,  String displayUrl,  LiveFormat liveFormat,  int epgOffsetMinutes,  int refreshHours,  int sortOrder,  DateTime createdAt,  DateTime updatedAt,  String? username,  String? epgUrlDisplay,  String? userAgent,  int? maxConnectionsOverride,  DateTime? expiresAt,  DateTime? lastSyncedAt)?  $default,) {final _that = this;
switch (_that) {
case _Source() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.displayUrl,_that.liveFormat,_that.epgOffsetMinutes,_that.refreshHours,_that.sortOrder,_that.createdAt,_that.updatedAt,_that.username,_that.epgUrlDisplay,_that.userAgent,_that.maxConnectionsOverride,_that.expiresAt,_that.lastSyncedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Source implements Source {
  const _Source({required this.id, required this.type, required this.name, required this.displayUrl, required this.liveFormat, required this.epgOffsetMinutes, required this.refreshHours, required this.sortOrder, required this.createdAt, required this.updatedAt, this.username, this.epgUrlDisplay, this.userAgent, this.maxConnectionsOverride, this.expiresAt, this.lastSyncedAt});
  

@override final  String id;
@override final  SourceType type;
@override final  String name;
/// The Xtream server, the playlist URL's origin (`http://host/…`), or
/// the local file path, depending on [type].
@override final  String displayUrl;
@override final  LiveFormat liveFormat;
@override final  int epgOffsetMinutes;
@override final  int refreshHours;
@override final  int sortOrder;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  String? username;
/// The EPG URL override's origin, like [displayUrl].
@override final  String? epgUrlDisplay;
@override final  String? userAgent;
@override final  int? maxConnectionsOverride;
@override final  DateTime? expiresAt;
@override final  DateTime? lastSyncedAt;

/// Create a copy of Source
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceCopyWith<_Source> get copyWith => __$SourceCopyWithImpl<_Source>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Source&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayUrl, displayUrl) || other.displayUrl == displayUrl)&&(identical(other.liveFormat, liveFormat) || other.liveFormat == liveFormat)&&(identical(other.epgOffsetMinutes, epgOffsetMinutes) || other.epgOffsetMinutes == epgOffsetMinutes)&&(identical(other.refreshHours, refreshHours) || other.refreshHours == refreshHours)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.username, username) || other.username == username)&&(identical(other.epgUrlDisplay, epgUrlDisplay) || other.epgUrlDisplay == epgUrlDisplay)&&(identical(other.userAgent, userAgent) || other.userAgent == userAgent)&&(identical(other.maxConnectionsOverride, maxConnectionsOverride) || other.maxConnectionsOverride == maxConnectionsOverride)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,type,name,displayUrl,liveFormat,epgOffsetMinutes,refreshHours,sortOrder,createdAt,updatedAt,username,epgUrlDisplay,userAgent,maxConnectionsOverride,expiresAt,lastSyncedAt);
}

@override
String toString() {
    return 'Source(id: $id, type: $type, name: $name, displayUrl: $displayUrl, liveFormat: $liveFormat, epgOffsetMinutes: $epgOffsetMinutes, refreshHours: $refreshHours, sortOrder: $sortOrder, createdAt: $createdAt, updatedAt: $updatedAt, username: $username, epgUrlDisplay: $epgUrlDisplay, userAgent: $userAgent, maxConnectionsOverride: $maxConnectionsOverride, expiresAt: $expiresAt, lastSyncedAt: $lastSyncedAt)';
}


}

/// @nodoc
abstract mixin class _$SourceCopyWith<$Res> implements $SourceCopyWith<$Res> {
  factory _$SourceCopyWith(_Source value, $Res Function(_Source) _then) = __$SourceCopyWithImpl;
@override @useResult
$Res call({
 String id, SourceType type, String name, String displayUrl, LiveFormat liveFormat, int epgOffsetMinutes, int refreshHours, int sortOrder, DateTime createdAt, DateTime updatedAt, String? username, String? epgUrlDisplay, String? userAgent, int? maxConnectionsOverride, DateTime? expiresAt, DateTime? lastSyncedAt
});




}
/// @nodoc
class __$SourceCopyWithImpl<$Res>
    implements _$SourceCopyWith<$Res> {
  __$SourceCopyWithImpl(this._self, this._then);

  final _Source _self;
  final $Res Function(_Source) _then;

/// Create a copy of Source
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? name = null,Object? displayUrl = null,Object? liveFormat = null,Object? epgOffsetMinutes = null,Object? refreshHours = null,Object? sortOrder = null,Object? createdAt = null,Object? updatedAt = null,Object? username = freezed,Object? epgUrlDisplay = freezed,Object? userAgent = freezed,Object? maxConnectionsOverride = freezed,Object? expiresAt = freezed,Object? lastSyncedAt = freezed,}) {
  return _then(_Source(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SourceType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayUrl: null == displayUrl ? _self.displayUrl : displayUrl // ignore: cast_nullable_to_non_nullable
as String,liveFormat: null == liveFormat ? _self.liveFormat : liveFormat // ignore: cast_nullable_to_non_nullable
as LiveFormat,epgOffsetMinutes: null == epgOffsetMinutes ? _self.epgOffsetMinutes : epgOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,refreshHours: null == refreshHours ? _self.refreshHours : refreshHours // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,epgUrlDisplay: freezed == epgUrlDisplay ? _self.epgUrlDisplay : epgUrlDisplay // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,maxConnectionsOverride: freezed == maxConnectionsOverride ? _self.maxConnectionsOverride : maxConnectionsOverride // ignore: cast_nullable_to_non_nullable
as int?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$SourceDraft {

 SourceType get type; String get name;/// The Xtream server, the playlist URL, or the local file path.
 String get url; String? get username; String? get password; String? get epgUrl; String? get userAgent; LiveFormat get liveFormat; int get epgOffsetMinutes; int get refreshHours; int? get maxConnectionsOverride;
/// Create a copy of SourceDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceDraftCopyWith<SourceDraft> get copyWith => _$SourceDraftCopyWithImpl<SourceDraft>(this as SourceDraft, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceDraft&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.password, _this.password) || other.password == _this.password)&&(identical(other.epgUrl, _this.epgUrl) || other.epgUrl == _this.epgUrl)&&(identical(other.userAgent, _this.userAgent) || other.userAgent == _this.userAgent)&&(identical(other.liveFormat, _this.liveFormat) || other.liveFormat == _this.liveFormat)&&(identical(other.epgOffsetMinutes, _this.epgOffsetMinutes) || other.epgOffsetMinutes == _this.epgOffsetMinutes)&&(identical(other.refreshHours, _this.refreshHours) || other.refreshHours == _this.refreshHours)&&(identical(other.maxConnectionsOverride, _this.maxConnectionsOverride) || other.maxConnectionsOverride == _this.maxConnectionsOverride));
}


@override
int get hashCode {
  final _this = this as SourceDraft;
  return Object.hash(runtimeType,_this.type,_this.name,_this.url,_this.username,_this.password,_this.epgUrl,_this.userAgent,_this.liveFormat,_this.epgOffsetMinutes,_this.refreshHours,_this.maxConnectionsOverride);
}

@override
String toString() {
  final _this = this as SourceDraft;
  return 'SourceDraft(type: ${_this.type}, name: ${_this.name}, url: ${_this.url}, username: ${_this.username}, password: ${_this.password}, epgUrl: ${_this.epgUrl}, userAgent: ${_this.userAgent}, liveFormat: ${_this.liveFormat}, epgOffsetMinutes: ${_this.epgOffsetMinutes}, refreshHours: ${_this.refreshHours}, maxConnectionsOverride: ${_this.maxConnectionsOverride})';
}


}

/// @nodoc
abstract mixin class $SourceDraftCopyWith<$Res>  {
  factory $SourceDraftCopyWith(SourceDraft value, $Res Function(SourceDraft) _then) = _$SourceDraftCopyWithImpl;
@useResult
$Res call({
 SourceType type, String name, String url, String? username, String? password, String? epgUrl, String? userAgent, LiveFormat liveFormat, int epgOffsetMinutes, int refreshHours, int? maxConnectionsOverride
});




}
/// @nodoc
class _$SourceDraftCopyWithImpl<$Res>
    implements $SourceDraftCopyWith<$Res> {
  _$SourceDraftCopyWithImpl(this._self, this._then);

  final SourceDraft _self;
  final $Res Function(SourceDraft) _then;

/// Create a copy of SourceDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? name = null,Object? url = null,Object? username = freezed,Object? password = freezed,Object? epgUrl = freezed,Object? userAgent = freezed,Object? liveFormat = null,Object? epgOffsetMinutes = null,Object? refreshHours = null,Object? maxConnectionsOverride = freezed,}) {
  return _then(SourceDraft(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SourceType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,epgUrl: freezed == epgUrl ? _self.epgUrl : epgUrl // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,liveFormat: null == liveFormat ? _self.liveFormat : liveFormat // ignore: cast_nullable_to_non_nullable
as LiveFormat,epgOffsetMinutes: null == epgOffsetMinutes ? _self.epgOffsetMinutes : epgOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,refreshHours: null == refreshHours ? _self.refreshHours : refreshHours // ignore: cast_nullable_to_non_nullable
as int,maxConnectionsOverride: freezed == maxConnectionsOverride ? _self.maxConnectionsOverride : maxConnectionsOverride // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceDraft].
extension SourceDraftPatterns on SourceDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceDraft value)  $default,){
final _that = this;
switch (_that) {
case _SourceDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceDraft value)?  $default,){
final _that = this;
switch (_that) {
case _SourceDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SourceType type,  String name,  String url,  String? username,  String? password,  String? epgUrl,  String? userAgent,  LiveFormat liveFormat,  int epgOffsetMinutes,  int refreshHours,  int? maxConnectionsOverride)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceDraft() when $default != null:
return $default(_that.type,_that.name,_that.url,_that.username,_that.password,_that.epgUrl,_that.userAgent,_that.liveFormat,_that.epgOffsetMinutes,_that.refreshHours,_that.maxConnectionsOverride);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SourceType type,  String name,  String url,  String? username,  String? password,  String? epgUrl,  String? userAgent,  LiveFormat liveFormat,  int epgOffsetMinutes,  int refreshHours,  int? maxConnectionsOverride)  $default,) {final _that = this;
switch (_that) {
case _SourceDraft():
return $default(_that.type,_that.name,_that.url,_that.username,_that.password,_that.epgUrl,_that.userAgent,_that.liveFormat,_that.epgOffsetMinutes,_that.refreshHours,_that.maxConnectionsOverride);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SourceType type,  String name,  String url,  String? username,  String? password,  String? epgUrl,  String? userAgent,  LiveFormat liveFormat,  int epgOffsetMinutes,  int refreshHours,  int? maxConnectionsOverride)?  $default,) {final _that = this;
switch (_that) {
case _SourceDraft() when $default != null:
return $default(_that.type,_that.name,_that.url,_that.username,_that.password,_that.epgUrl,_that.userAgent,_that.liveFormat,_that.epgOffsetMinutes,_that.refreshHours,_that.maxConnectionsOverride);case _:
  return null;

}
}

}

/// @nodoc


class _SourceDraft implements SourceDraft {
  const _SourceDraft({required this.type, required this.name, required this.url, this.username, this.password, this.epgUrl, this.userAgent, this.liveFormat = LiveFormat.ts, this.epgOffsetMinutes = 0, this.refreshHours = 12, this.maxConnectionsOverride});
  

@override final  SourceType type;
@override final  String name;
/// The Xtream server, the playlist URL, or the local file path.
@override final  String url;
@override final  String? username;
@override final  String? password;
@override final  String? epgUrl;
@override final  String? userAgent;
@override@JsonKey() final  LiveFormat liveFormat;
@override@JsonKey() final  int epgOffsetMinutes;
@override@JsonKey() final  int refreshHours;
@override final  int? maxConnectionsOverride;

/// Create a copy of SourceDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceDraftCopyWith<_SourceDraft> get copyWith => __$SourceDraftCopyWithImpl<_SourceDraft>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceDraft&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url)&&(identical(other.username, username) || other.username == username)&&(identical(other.password, password) || other.password == password)&&(identical(other.epgUrl, epgUrl) || other.epgUrl == epgUrl)&&(identical(other.userAgent, userAgent) || other.userAgent == userAgent)&&(identical(other.liveFormat, liveFormat) || other.liveFormat == liveFormat)&&(identical(other.epgOffsetMinutes, epgOffsetMinutes) || other.epgOffsetMinutes == epgOffsetMinutes)&&(identical(other.refreshHours, refreshHours) || other.refreshHours == refreshHours)&&(identical(other.maxConnectionsOverride, maxConnectionsOverride) || other.maxConnectionsOverride == maxConnectionsOverride));
}


@override
int get hashCode {
    return Object.hash(runtimeType,type,name,url,username,password,epgUrl,userAgent,liveFormat,epgOffsetMinutes,refreshHours,maxConnectionsOverride);
}

@override
String toString() {
    return 'SourceDraft(type: $type, name: $name, url: $url, username: $username, password: $password, epgUrl: $epgUrl, userAgent: $userAgent, liveFormat: $liveFormat, epgOffsetMinutes: $epgOffsetMinutes, refreshHours: $refreshHours, maxConnectionsOverride: $maxConnectionsOverride)';
}


}

/// @nodoc
abstract mixin class _$SourceDraftCopyWith<$Res> implements $SourceDraftCopyWith<$Res> {
  factory _$SourceDraftCopyWith(_SourceDraft value, $Res Function(_SourceDraft) _then) = __$SourceDraftCopyWithImpl;
@override @useResult
$Res call({
 SourceType type, String name, String url, String? username, String? password, String? epgUrl, String? userAgent, LiveFormat liveFormat, int epgOffsetMinutes, int refreshHours, int? maxConnectionsOverride
});




}
/// @nodoc
class __$SourceDraftCopyWithImpl<$Res>
    implements _$SourceDraftCopyWith<$Res> {
  __$SourceDraftCopyWithImpl(this._self, this._then);

  final _SourceDraft _self;
  final $Res Function(_SourceDraft) _then;

/// Create a copy of SourceDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? name = null,Object? url = null,Object? username = freezed,Object? password = freezed,Object? epgUrl = freezed,Object? userAgent = freezed,Object? liveFormat = null,Object? epgOffsetMinutes = null,Object? refreshHours = null,Object? maxConnectionsOverride = freezed,}) {
  return _then(_SourceDraft(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SourceType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,epgUrl: freezed == epgUrl ? _self.epgUrl : epgUrl // ignore: cast_nullable_to_non_nullable
as String?,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,liveFormat: null == liveFormat ? _self.liveFormat : liveFormat // ignore: cast_nullable_to_non_nullable
as LiveFormat,epgOffsetMinutes: null == epgOffsetMinutes ? _self.epgOffsetMinutes : epgOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,refreshHours: null == refreshHours ? _self.refreshHours : refreshHours // ignore: cast_nullable_to_non_nullable
as int,maxConnectionsOverride: freezed == maxConnectionsOverride ? _self.maxConnectionsOverride : maxConnectionsOverride // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
