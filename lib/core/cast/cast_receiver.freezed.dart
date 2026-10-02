// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cast_receiver.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CastSessionState {

 CastLink get link;/// Why the session ended, once [link] is [CastLink.ended].
 CastEnd? get end;/// The app that took the device over, for [CastEnd.otherApp]: what
/// "Living Room TV started YouTube" names.
 String? get otherApp;/// The media session on the device; null before the first LOAD, and
/// when the device has none.
 CastMediaStatus? get media; CastVolume get volume;
/// Create a copy of CastSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CastSessionStateCopyWith<CastSessionState> get copyWith => _$CastSessionStateCopyWithImpl<CastSessionState>(this as CastSessionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CastSessionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CastSessionState&&(identical(other.link, _this.link) || other.link == _this.link)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.otherApp, _this.otherApp) || other.otherApp == _this.otherApp)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.volume, _this.volume) || other.volume == _this.volume));
}


@override
int get hashCode {
  final _this = this as CastSessionState;
  return Object.hash(runtimeType,_this.link,_this.end,_this.otherApp,_this.media,_this.volume);
}

@override
String toString() {
  final _this = this as CastSessionState;
  return 'CastSessionState(link: ${_this.link}, end: ${_this.end}, otherApp: ${_this.otherApp}, media: ${_this.media}, volume: ${_this.volume})';
}


}

/// @nodoc
abstract mixin class $CastSessionStateCopyWith<$Res>  {
  factory $CastSessionStateCopyWith(CastSessionState value, $Res Function(CastSessionState) _then) = _$CastSessionStateCopyWithImpl;
@useResult
$Res call({
 CastLink link, CastEnd? end, String? otherApp, CastMediaStatus? media, CastVolume volume
});


$CastMediaStatusCopyWith<$Res>? get media;$CastVolumeCopyWith<$Res> get volume;

}
/// @nodoc
class _$CastSessionStateCopyWithImpl<$Res>
    implements $CastSessionStateCopyWith<$Res> {
  _$CastSessionStateCopyWithImpl(this._self, this._then);

  final CastSessionState _self;
  final $Res Function(CastSessionState) _then;

/// Create a copy of CastSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? link = null,Object? end = freezed,Object? otherApp = freezed,Object? media = freezed,Object? volume = null,}) {
  return _then(CastSessionState(
link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as CastLink,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as CastEnd?,otherApp: freezed == otherApp ? _self.otherApp : otherApp // ignore: cast_nullable_to_non_nullable
as String?,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as CastMediaStatus?,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as CastVolume,
  ));
}
/// Create a copy of CastSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastMediaStatusCopyWith<$Res>? get media {
    if (_self.media == null) {
    return null;
  }

  return $CastMediaStatusCopyWith<$Res>(_self.media!, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of CastSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastVolumeCopyWith<$Res> get volume {
  
  return $CastVolumeCopyWith<$Res>(_self.volume, (value) {
    return _then(_self.copyWith(volume: value));
  });
}
}


/// Adds pattern-matching-related methods to [CastSessionState].
extension CastSessionStatePatterns on CastSessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CastSessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CastSessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CastSessionState value)  $default,){
final _that = this;
switch (_that) {
case _CastSessionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CastSessionState value)?  $default,){
final _that = this;
switch (_that) {
case _CastSessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CastLink link,  CastEnd? end,  String? otherApp,  CastMediaStatus? media,  CastVolume volume)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CastSessionState() when $default != null:
return $default(_that.link,_that.end,_that.otherApp,_that.media,_that.volume);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CastLink link,  CastEnd? end,  String? otherApp,  CastMediaStatus? media,  CastVolume volume)  $default,) {final _that = this;
switch (_that) {
case _CastSessionState():
return $default(_that.link,_that.end,_that.otherApp,_that.media,_that.volume);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CastLink link,  CastEnd? end,  String? otherApp,  CastMediaStatus? media,  CastVolume volume)?  $default,) {final _that = this;
switch (_that) {
case _CastSessionState() when $default != null:
return $default(_that.link,_that.end,_that.otherApp,_that.media,_that.volume);case _:
  return null;

}
}

}

/// @nodoc


class _CastSessionState implements CastSessionState {
  const _CastSessionState({this.link = CastLink.connected, this.end, this.otherApp, this.media, this.volume = const CastVolume()});
  

@override@JsonKey() final  CastLink link;
/// Why the session ended, once [link] is [CastLink.ended].
@override final  CastEnd? end;
/// The app that took the device over, for [CastEnd.otherApp]: what
/// "Living Room TV started YouTube" names.
@override final  String? otherApp;
/// The media session on the device; null before the first LOAD, and
/// when the device has none.
@override final  CastMediaStatus? media;
@override@JsonKey() final  CastVolume volume;

/// Create a copy of CastSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CastSessionStateCopyWith<_CastSessionState> get copyWith => __$CastSessionStateCopyWithImpl<_CastSessionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CastSessionState&&(identical(other.link, link) || other.link == link)&&(identical(other.end, end) || other.end == end)&&(identical(other.otherApp, otherApp) || other.otherApp == otherApp)&&(identical(other.media, media) || other.media == media)&&(identical(other.volume, volume) || other.volume == volume));
}


@override
int get hashCode {
    return Object.hash(runtimeType,link,end,otherApp,media,volume);
}

@override
String toString() {
    return 'CastSessionState(link: $link, end: $end, otherApp: $otherApp, media: $media, volume: $volume)';
}


}

/// @nodoc
abstract mixin class _$CastSessionStateCopyWith<$Res> implements $CastSessionStateCopyWith<$Res> {
  factory _$CastSessionStateCopyWith(_CastSessionState value, $Res Function(_CastSessionState) _then) = __$CastSessionStateCopyWithImpl;
@override @useResult
$Res call({
 CastLink link, CastEnd? end, String? otherApp, CastMediaStatus? media, CastVolume volume
});


@override $CastMediaStatusCopyWith<$Res>? get media;@override $CastVolumeCopyWith<$Res> get volume;

}
/// @nodoc
class __$CastSessionStateCopyWithImpl<$Res>
    implements _$CastSessionStateCopyWith<$Res> {
  __$CastSessionStateCopyWithImpl(this._self, this._then);

  final _CastSessionState _self;
  final $Res Function(_CastSessionState) _then;

/// Create a copy of CastSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? link = null,Object? end = freezed,Object? otherApp = freezed,Object? media = freezed,Object? volume = null,}) {
  return _then(_CastSessionState(
link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as CastLink,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as CastEnd?,otherApp: freezed == otherApp ? _self.otherApp : otherApp // ignore: cast_nullable_to_non_nullable
as String?,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as CastMediaStatus?,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as CastVolume,
  ));
}

/// Create a copy of CastSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastMediaStatusCopyWith<$Res>? get media {
    if (_self.media == null) {
    return null;
  }

  return $CastMediaStatusCopyWith<$Res>(_self.media!, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of CastSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastVolumeCopyWith<$Res> get volume {
  
  return $CastVolumeCopyWith<$Res>(_self.volume, (value) {
    return _then(_self.copyWith(volume: value));
  });
}
}

/// @nodoc
mixin _$CastVolume {

 double get level; bool get muted;/// The device's volume follows the TV's own (`controlType: fixed`):
/// setting it changes nothing.
 bool get fixed;
/// Create a copy of CastVolume
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CastVolumeCopyWith<CastVolume> get copyWith => _$CastVolumeCopyWithImpl<CastVolume>(this as CastVolume, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CastVolume;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CastVolume&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.muted, _this.muted) || other.muted == _this.muted)&&(identical(other.fixed, _this.fixed) || other.fixed == _this.fixed));
}


@override
int get hashCode {
  final _this = this as CastVolume;
  return Object.hash(runtimeType,_this.level,_this.muted,_this.fixed);
}

@override
String toString() {
  final _this = this as CastVolume;
  return 'CastVolume(level: ${_this.level}, muted: ${_this.muted}, fixed: ${_this.fixed})';
}


}

/// @nodoc
abstract mixin class $CastVolumeCopyWith<$Res>  {
  factory $CastVolumeCopyWith(CastVolume value, $Res Function(CastVolume) _then) = _$CastVolumeCopyWithImpl;
@useResult
$Res call({
 double level, bool muted, bool fixed
});




}
/// @nodoc
class _$CastVolumeCopyWithImpl<$Res>
    implements $CastVolumeCopyWith<$Res> {
  _$CastVolumeCopyWithImpl(this._self, this._then);

  final CastVolume _self;
  final $Res Function(CastVolume) _then;

/// Create a copy of CastVolume
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? muted = null,Object? fixed = null,}) {
  return _then(CastVolume(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as double,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,fixed: null == fixed ? _self.fixed : fixed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CastVolume].
extension CastVolumePatterns on CastVolume {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CastVolume value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CastVolume() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CastVolume value)  $default,){
final _that = this;
switch (_that) {
case _CastVolume():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CastVolume value)?  $default,){
final _that = this;
switch (_that) {
case _CastVolume() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double level,  bool muted,  bool fixed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CastVolume() when $default != null:
return $default(_that.level,_that.muted,_that.fixed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double level,  bool muted,  bool fixed)  $default,) {final _that = this;
switch (_that) {
case _CastVolume():
return $default(_that.level,_that.muted,_that.fixed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double level,  bool muted,  bool fixed)?  $default,) {final _that = this;
switch (_that) {
case _CastVolume() when $default != null:
return $default(_that.level,_that.muted,_that.fixed);case _:
  return null;

}
}

}

/// @nodoc


class _CastVolume implements CastVolume {
  const _CastVolume({this.level = 1.0, this.muted = false, this.fixed = false});
  

@override@JsonKey() final  double level;
@override@JsonKey() final  bool muted;
/// The device's volume follows the TV's own (`controlType: fixed`):
/// setting it changes nothing.
@override@JsonKey() final  bool fixed;

/// Create a copy of CastVolume
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CastVolumeCopyWith<_CastVolume> get copyWith => __$CastVolumeCopyWithImpl<_CastVolume>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CastVolume&&(identical(other.level, level) || other.level == level)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.fixed, fixed) || other.fixed == fixed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,level,muted,fixed);
}

@override
String toString() {
    return 'CastVolume(level: $level, muted: $muted, fixed: $fixed)';
}


}

/// @nodoc
abstract mixin class _$CastVolumeCopyWith<$Res> implements $CastVolumeCopyWith<$Res> {
  factory _$CastVolumeCopyWith(_CastVolume value, $Res Function(_CastVolume) _then) = __$CastVolumeCopyWithImpl;
@override @useResult
$Res call({
 double level, bool muted, bool fixed
});




}
/// @nodoc
class __$CastVolumeCopyWithImpl<$Res>
    implements _$CastVolumeCopyWith<$Res> {
  __$CastVolumeCopyWithImpl(this._self, this._then);

  final _CastVolume _self;
  final $Res Function(_CastVolume) _then;

/// Create a copy of CastVolume
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? muted = null,Object? fixed = null,}) {
  return _then(_CastVolume(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as double,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,fixed: null == fixed ? _self.fixed : fixed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$CastMediaStatus {

/// The device's id for this media session; a new LOAD makes another.
 int get sessionId; CastPlayerState get playerState;/// Why it is idle, when [playerState] is [CastPlayerState.idle].
 CastIdleReason? get idleReason;/// Where it is, as of the report.
 Duration get position;/// A file's length; null for live streams and until the device knows.
 Duration? get duration;/// 1 while playing.
 double get rate;/// The URL loaded.
 String? get contentId;/// The picture's size, once the device decodes it.
 int? get videoWidth; int? get videoHeight;
/// Create a copy of CastMediaStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CastMediaStatusCopyWith<CastMediaStatus> get copyWith => _$CastMediaStatusCopyWithImpl<CastMediaStatus>(this as CastMediaStatus, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CastMediaStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CastMediaStatus&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.playerState, _this.playerState) || other.playerState == _this.playerState)&&(identical(other.idleReason, _this.idleReason) || other.idleReason == _this.idleReason)&&(identical(other.position, _this.position) || other.position == _this.position)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.rate, _this.rate) || other.rate == _this.rate)&&(identical(other.contentId, _this.contentId) || other.contentId == _this.contentId)&&(identical(other.videoWidth, _this.videoWidth) || other.videoWidth == _this.videoWidth)&&(identical(other.videoHeight, _this.videoHeight) || other.videoHeight == _this.videoHeight));
}


@override
int get hashCode {
  final _this = this as CastMediaStatus;
  return Object.hash(runtimeType,_this.sessionId,_this.playerState,_this.idleReason,_this.position,_this.duration,_this.rate,_this.contentId,_this.videoWidth,_this.videoHeight);
}

@override
String toString() {
  final _this = this as CastMediaStatus;
  return 'CastMediaStatus(sessionId: ${_this.sessionId}, playerState: ${_this.playerState}, idleReason: ${_this.idleReason}, position: ${_this.position}, duration: ${_this.duration}, rate: ${_this.rate}, contentId: ${_this.contentId}, videoWidth: ${_this.videoWidth}, videoHeight: ${_this.videoHeight})';
}


}

/// @nodoc
abstract mixin class $CastMediaStatusCopyWith<$Res>  {
  factory $CastMediaStatusCopyWith(CastMediaStatus value, $Res Function(CastMediaStatus) _then) = _$CastMediaStatusCopyWithImpl;
@useResult
$Res call({
 int sessionId, CastPlayerState playerState, CastIdleReason? idleReason, Duration position, Duration? duration, double rate, String? contentId, int? videoWidth, int? videoHeight
});




}
/// @nodoc
class _$CastMediaStatusCopyWithImpl<$Res>
    implements $CastMediaStatusCopyWith<$Res> {
  _$CastMediaStatusCopyWithImpl(this._self, this._then);

  final CastMediaStatus _self;
  final $Res Function(CastMediaStatus) _then;

/// Create a copy of CastMediaStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? playerState = null,Object? idleReason = freezed,Object? position = null,Object? duration = freezed,Object? rate = null,Object? contentId = freezed,Object? videoWidth = freezed,Object? videoHeight = freezed,}) {
  return _then(CastMediaStatus(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as int,playerState: null == playerState ? _self.playerState : playerState // ignore: cast_nullable_to_non_nullable
as CastPlayerState,idleReason: freezed == idleReason ? _self.idleReason : idleReason // ignore: cast_nullable_to_non_nullable
as CastIdleReason?,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,contentId: freezed == contentId ? _self.contentId : contentId // ignore: cast_nullable_to_non_nullable
as String?,videoWidth: freezed == videoWidth ? _self.videoWidth : videoWidth // ignore: cast_nullable_to_non_nullable
as int?,videoHeight: freezed == videoHeight ? _self.videoHeight : videoHeight // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [CastMediaStatus].
extension CastMediaStatusPatterns on CastMediaStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CastMediaStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CastMediaStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CastMediaStatus value)  $default,){
final _that = this;
switch (_that) {
case _CastMediaStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CastMediaStatus value)?  $default,){
final _that = this;
switch (_that) {
case _CastMediaStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sessionId,  CastPlayerState playerState,  CastIdleReason? idleReason,  Duration position,  Duration? duration,  double rate,  String? contentId,  int? videoWidth,  int? videoHeight)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CastMediaStatus() when $default != null:
return $default(_that.sessionId,_that.playerState,_that.idleReason,_that.position,_that.duration,_that.rate,_that.contentId,_that.videoWidth,_that.videoHeight);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sessionId,  CastPlayerState playerState,  CastIdleReason? idleReason,  Duration position,  Duration? duration,  double rate,  String? contentId,  int? videoWidth,  int? videoHeight)  $default,) {final _that = this;
switch (_that) {
case _CastMediaStatus():
return $default(_that.sessionId,_that.playerState,_that.idleReason,_that.position,_that.duration,_that.rate,_that.contentId,_that.videoWidth,_that.videoHeight);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sessionId,  CastPlayerState playerState,  CastIdleReason? idleReason,  Duration position,  Duration? duration,  double rate,  String? contentId,  int? videoWidth,  int? videoHeight)?  $default,) {final _that = this;
switch (_that) {
case _CastMediaStatus() when $default != null:
return $default(_that.sessionId,_that.playerState,_that.idleReason,_that.position,_that.duration,_that.rate,_that.contentId,_that.videoWidth,_that.videoHeight);case _:
  return null;

}
}

}

/// @nodoc


class _CastMediaStatus implements CastMediaStatus {
  const _CastMediaStatus({required this.sessionId, required this.playerState, this.idleReason, this.position = Duration.zero, this.duration, this.rate = 1.0, this.contentId, this.videoWidth, this.videoHeight});
  

/// The device's id for this media session; a new LOAD makes another.
@override final  int sessionId;
@override final  CastPlayerState playerState;
/// Why it is idle, when [playerState] is [CastPlayerState.idle].
@override final  CastIdleReason? idleReason;
/// Where it is, as of the report.
@override@JsonKey() final  Duration position;
/// A file's length; null for live streams and until the device knows.
@override final  Duration? duration;
/// 1 while playing.
@override@JsonKey() final  double rate;
/// The URL loaded.
@override final  String? contentId;
/// The picture's size, once the device decodes it.
@override final  int? videoWidth;
@override final  int? videoHeight;

/// Create a copy of CastMediaStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CastMediaStatusCopyWith<_CastMediaStatus> get copyWith => __$CastMediaStatusCopyWithImpl<_CastMediaStatus>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CastMediaStatus&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.playerState, playerState) || other.playerState == playerState)&&(identical(other.idleReason, idleReason) || other.idleReason == idleReason)&&(identical(other.position, position) || other.position == position)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.contentId, contentId) || other.contentId == contentId)&&(identical(other.videoWidth, videoWidth) || other.videoWidth == videoWidth)&&(identical(other.videoHeight, videoHeight) || other.videoHeight == videoHeight));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,playerState,idleReason,position,duration,rate,contentId,videoWidth,videoHeight);
}

@override
String toString() {
    return 'CastMediaStatus(sessionId: $sessionId, playerState: $playerState, idleReason: $idleReason, position: $position, duration: $duration, rate: $rate, contentId: $contentId, videoWidth: $videoWidth, videoHeight: $videoHeight)';
}


}

/// @nodoc
abstract mixin class _$CastMediaStatusCopyWith<$Res> implements $CastMediaStatusCopyWith<$Res> {
  factory _$CastMediaStatusCopyWith(_CastMediaStatus value, $Res Function(_CastMediaStatus) _then) = __$CastMediaStatusCopyWithImpl;
@override @useResult
$Res call({
 int sessionId, CastPlayerState playerState, CastIdleReason? idleReason, Duration position, Duration? duration, double rate, String? contentId, int? videoWidth, int? videoHeight
});




}
/// @nodoc
class __$CastMediaStatusCopyWithImpl<$Res>
    implements _$CastMediaStatusCopyWith<$Res> {
  __$CastMediaStatusCopyWithImpl(this._self, this._then);

  final _CastMediaStatus _self;
  final $Res Function(_CastMediaStatus) _then;

/// Create a copy of CastMediaStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? playerState = null,Object? idleReason = freezed,Object? position = null,Object? duration = freezed,Object? rate = null,Object? contentId = freezed,Object? videoWidth = freezed,Object? videoHeight = freezed,}) {
  return _then(_CastMediaStatus(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as int,playerState: null == playerState ? _self.playerState : playerState // ignore: cast_nullable_to_non_nullable
as CastPlayerState,idleReason: freezed == idleReason ? _self.idleReason : idleReason // ignore: cast_nullable_to_non_nullable
as CastIdleReason?,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as Duration,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,contentId: freezed == contentId ? _self.contentId : contentId // ignore: cast_nullable_to_non_nullable
as String?,videoWidth: freezed == videoWidth ? _self.videoWidth : videoWidth // ignore: cast_nullable_to_non_nullable
as int?,videoHeight: freezed == videoHeight ? _self.videoHeight : videoHeight // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
