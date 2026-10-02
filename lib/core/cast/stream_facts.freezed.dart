// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stream_facts.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StreamFacts {

/// Where the facts came from (Phase 7 decision 4).
 StreamFactsOrigin get origin;/// Null when not known (the laptop's player doesn't say).
 MediaContainer? get container;/// The first picture that isn't a cover image; null when there is
/// none (a radio channel).
 VideoFacts? get video;/// Every audio track, in the stream's order.
 List<AudioFacts> get audio;/// A file's length.
 Duration? get duration;/// The whole stream's bits per second.
 int? get bitRate;
/// Create a copy of StreamFacts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreamFactsCopyWith<StreamFacts> get copyWith => _$StreamFactsCopyWithImpl<StreamFacts>(this as StreamFacts, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StreamFacts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreamFacts&&(identical(other.origin, _this.origin) || other.origin == _this.origin)&&(identical(other.container, _this.container) || other.container == _this.container)&&(identical(other.video, _this.video) || other.video == _this.video)&&const DeepCollectionEquality().equals(other.audio, _this.audio)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.bitRate, _this.bitRate) || other.bitRate == _this.bitRate));
}


@override
int get hashCode {
  final _this = this as StreamFacts;
  return Object.hash(runtimeType,_this.origin,_this.container,_this.video,const DeepCollectionEquality().hash(_this.audio),_this.duration,_this.bitRate);
}

@override
String toString() {
  final _this = this as StreamFacts;
  return 'StreamFacts(origin: ${_this.origin}, container: ${_this.container}, video: ${_this.video}, audio: ${_this.audio}, duration: ${_this.duration}, bitRate: ${_this.bitRate})';
}


}

/// @nodoc
abstract mixin class $StreamFactsCopyWith<$Res>  {
  factory $StreamFactsCopyWith(StreamFacts value, $Res Function(StreamFacts) _then) = _$StreamFactsCopyWithImpl;
@useResult
$Res call({
 StreamFactsOrigin origin, MediaContainer? container, VideoFacts? video, List<AudioFacts> audio, Duration? duration, int? bitRate
});


$VideoFactsCopyWith<$Res>? get video;

}
/// @nodoc
class _$StreamFactsCopyWithImpl<$Res>
    implements $StreamFactsCopyWith<$Res> {
  _$StreamFactsCopyWithImpl(this._self, this._then);

  final StreamFacts _self;
  final $Res Function(StreamFacts) _then;

/// Create a copy of StreamFacts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? origin = null,Object? container = freezed,Object? video = freezed,Object? audio = null,Object? duration = freezed,Object? bitRate = freezed,}) {
  return _then(StreamFacts(
origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as StreamFactsOrigin,container: freezed == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as MediaContainer?,video: freezed == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as VideoFacts?,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as List<AudioFacts>,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,bitRate: freezed == bitRate ? _self.bitRate : bitRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of StreamFacts
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VideoFactsCopyWith<$Res>? get video {
    if (_self.video == null) {
    return null;
  }

  return $VideoFactsCopyWith<$Res>(_self.video!, (value) {
    return _then(_self.copyWith(video: value));
  });
}
}


/// Adds pattern-matching-related methods to [StreamFacts].
extension StreamFactsPatterns on StreamFacts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StreamFacts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StreamFacts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StreamFacts value)  $default,){
final _that = this;
switch (_that) {
case _StreamFacts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StreamFacts value)?  $default,){
final _that = this;
switch (_that) {
case _StreamFacts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StreamFactsOrigin origin,  MediaContainer? container,  VideoFacts? video,  List<AudioFacts> audio,  Duration? duration,  int? bitRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StreamFacts() when $default != null:
return $default(_that.origin,_that.container,_that.video,_that.audio,_that.duration,_that.bitRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StreamFactsOrigin origin,  MediaContainer? container,  VideoFacts? video,  List<AudioFacts> audio,  Duration? duration,  int? bitRate)  $default,) {final _that = this;
switch (_that) {
case _StreamFacts():
return $default(_that.origin,_that.container,_that.video,_that.audio,_that.duration,_that.bitRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StreamFactsOrigin origin,  MediaContainer? container,  VideoFacts? video,  List<AudioFacts> audio,  Duration? duration,  int? bitRate)?  $default,) {final _that = this;
switch (_that) {
case _StreamFacts() when $default != null:
return $default(_that.origin,_that.container,_that.video,_that.audio,_that.duration,_that.bitRate);case _:
  return null;

}
}

}

/// @nodoc


class _StreamFacts implements StreamFacts {
  const _StreamFacts({required this.origin, this.container, this.video,  List<AudioFacts> audio = const <AudioFacts>[], this.duration, this.bitRate}): _audio = audio;
  

/// Where the facts came from (Phase 7 decision 4).
@override final  StreamFactsOrigin origin;
/// Null when not known (the laptop's player doesn't say).
@override final  MediaContainer? container;
/// The first picture that isn't a cover image; null when there is
/// none (a radio channel).
@override final  VideoFacts? video;
/// Every audio track, in the stream's order.
 final  List<AudioFacts> _audio;
/// Every audio track, in the stream's order.
@override@JsonKey() List<AudioFacts> get audio {
  if (_audio is EqualUnmodifiableListView) return _audio;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audio);
}

/// A file's length.
@override final  Duration? duration;
/// The whole stream's bits per second.
@override final  int? bitRate;

/// Create a copy of StreamFacts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StreamFactsCopyWith<_StreamFacts> get copyWith => __$StreamFactsCopyWithImpl<_StreamFacts>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StreamFacts&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.container, container) || other.container == container)&&(identical(other.video, video) || other.video == video)&&const DeepCollectionEquality().equals(other.audio, _audio)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.bitRate, bitRate) || other.bitRate == bitRate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,origin,container,video,const DeepCollectionEquality().hash(_audio),duration,bitRate);
}

@override
String toString() {
    return 'StreamFacts(origin: $origin, container: $container, video: $video, audio: $audio, duration: $duration, bitRate: $bitRate)';
}


}

/// @nodoc
abstract mixin class _$StreamFactsCopyWith<$Res> implements $StreamFactsCopyWith<$Res> {
  factory _$StreamFactsCopyWith(_StreamFacts value, $Res Function(_StreamFacts) _then) = __$StreamFactsCopyWithImpl;
@override @useResult
$Res call({
 StreamFactsOrigin origin, MediaContainer? container, VideoFacts? video, List<AudioFacts> audio, Duration? duration, int? bitRate
});


@override $VideoFactsCopyWith<$Res>? get video;

}
/// @nodoc
class __$StreamFactsCopyWithImpl<$Res>
    implements _$StreamFactsCopyWith<$Res> {
  __$StreamFactsCopyWithImpl(this._self, this._then);

  final _StreamFacts _self;
  final $Res Function(_StreamFacts) _then;

/// Create a copy of StreamFacts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? origin = null,Object? container = freezed,Object? video = freezed,Object? audio = null,Object? duration = freezed,Object? bitRate = freezed,}) {
  return _then(_StreamFacts(
origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as StreamFactsOrigin,container: freezed == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as MediaContainer?,video: freezed == video ? _self.video : video // ignore: cast_nullable_to_non_nullable
as VideoFacts?,audio: null == audio ? _self._audio : audio // ignore: cast_nullable_to_non_nullable
as List<AudioFacts>,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,bitRate: freezed == bitRate ? _self.bitRate : bitRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of StreamFacts
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VideoFactsCopyWith<$Res>? get video {
    if (_self.video == null) {
    return null;
  }

  return $VideoFactsCopyWith<$Res>(_self.video!, (value) {
    return _then(_self.copyWith(video: value));
  });
}
}

/// @nodoc
mixin _$VideoFacts {

/// ffprobe's codec name in lower case: `h264`, `hevc`, `mpeg2video`…
 String? get codec;/// ffprobe's profile, such as `High`, `High 10` or `Main 10`.
 String? get profile; int? get width; int? get height;/// Pictures per second: 25 for 1080i50, whose fields come at 50.
 double? get fps;/// Null when not known, which reads as progressive.
 bool? get interlaced;/// Bits per sample, from the pixel format: 8, 10, 12.
 int? get bitDepth; int? get bitRate;
/// Create a copy of VideoFacts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoFactsCopyWith<VideoFacts> get copyWith => _$VideoFactsCopyWithImpl<VideoFacts>(this as VideoFacts, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoFacts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoFacts&&(identical(other.codec, _this.codec) || other.codec == _this.codec)&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.fps, _this.fps) || other.fps == _this.fps)&&(identical(other.interlaced, _this.interlaced) || other.interlaced == _this.interlaced)&&(identical(other.bitDepth, _this.bitDepth) || other.bitDepth == _this.bitDepth)&&(identical(other.bitRate, _this.bitRate) || other.bitRate == _this.bitRate));
}


@override
int get hashCode {
  final _this = this as VideoFacts;
  return Object.hash(runtimeType,_this.codec,_this.profile,_this.width,_this.height,_this.fps,_this.interlaced,_this.bitDepth,_this.bitRate);
}

@override
String toString() {
  final _this = this as VideoFacts;
  return 'VideoFacts(codec: ${_this.codec}, profile: ${_this.profile}, width: ${_this.width}, height: ${_this.height}, fps: ${_this.fps}, interlaced: ${_this.interlaced}, bitDepth: ${_this.bitDepth}, bitRate: ${_this.bitRate})';
}


}

/// @nodoc
abstract mixin class $VideoFactsCopyWith<$Res>  {
  factory $VideoFactsCopyWith(VideoFacts value, $Res Function(VideoFacts) _then) = _$VideoFactsCopyWithImpl;
@useResult
$Res call({
 String? codec, String? profile, int? width, int? height, double? fps, bool? interlaced, int? bitDepth, int? bitRate
});




}
/// @nodoc
class _$VideoFactsCopyWithImpl<$Res>
    implements $VideoFactsCopyWith<$Res> {
  _$VideoFactsCopyWithImpl(this._self, this._then);

  final VideoFacts _self;
  final $Res Function(VideoFacts) _then;

/// Create a copy of VideoFacts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? codec = freezed,Object? profile = freezed,Object? width = freezed,Object? height = freezed,Object? fps = freezed,Object? interlaced = freezed,Object? bitDepth = freezed,Object? bitRate = freezed,}) {
  return _then(VideoFacts(
codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String?,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,fps: freezed == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double?,interlaced: freezed == interlaced ? _self.interlaced : interlaced // ignore: cast_nullable_to_non_nullable
as bool?,bitDepth: freezed == bitDepth ? _self.bitDepth : bitDepth // ignore: cast_nullable_to_non_nullable
as int?,bitRate: freezed == bitRate ? _self.bitRate : bitRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoFacts].
extension VideoFactsPatterns on VideoFacts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoFacts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoFacts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoFacts value)  $default,){
final _that = this;
switch (_that) {
case _VideoFacts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoFacts value)?  $default,){
final _that = this;
switch (_that) {
case _VideoFacts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? codec,  String? profile,  int? width,  int? height,  double? fps,  bool? interlaced,  int? bitDepth,  int? bitRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoFacts() when $default != null:
return $default(_that.codec,_that.profile,_that.width,_that.height,_that.fps,_that.interlaced,_that.bitDepth,_that.bitRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? codec,  String? profile,  int? width,  int? height,  double? fps,  bool? interlaced,  int? bitDepth,  int? bitRate)  $default,) {final _that = this;
switch (_that) {
case _VideoFacts():
return $default(_that.codec,_that.profile,_that.width,_that.height,_that.fps,_that.interlaced,_that.bitDepth,_that.bitRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? codec,  String? profile,  int? width,  int? height,  double? fps,  bool? interlaced,  int? bitDepth,  int? bitRate)?  $default,) {final _that = this;
switch (_that) {
case _VideoFacts() when $default != null:
return $default(_that.codec,_that.profile,_that.width,_that.height,_that.fps,_that.interlaced,_that.bitDepth,_that.bitRate);case _:
  return null;

}
}

}

/// @nodoc


class _VideoFacts implements VideoFacts {
  const _VideoFacts({this.codec, this.profile, this.width, this.height, this.fps, this.interlaced, this.bitDepth, this.bitRate});
  

/// ffprobe's codec name in lower case: `h264`, `hevc`, `mpeg2video`…
@override final  String? codec;
/// ffprobe's profile, such as `High`, `High 10` or `Main 10`.
@override final  String? profile;
@override final  int? width;
@override final  int? height;
/// Pictures per second: 25 for 1080i50, whose fields come at 50.
@override final  double? fps;
/// Null when not known, which reads as progressive.
@override final  bool? interlaced;
/// Bits per sample, from the pixel format: 8, 10, 12.
@override final  int? bitDepth;
@override final  int? bitRate;

/// Create a copy of VideoFacts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoFactsCopyWith<_VideoFacts> get copyWith => __$VideoFactsCopyWithImpl<_VideoFacts>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoFacts&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.interlaced, interlaced) || other.interlaced == interlaced)&&(identical(other.bitDepth, bitDepth) || other.bitDepth == bitDepth)&&(identical(other.bitRate, bitRate) || other.bitRate == bitRate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,codec,profile,width,height,fps,interlaced,bitDepth,bitRate);
}

@override
String toString() {
    return 'VideoFacts(codec: $codec, profile: $profile, width: $width, height: $height, fps: $fps, interlaced: $interlaced, bitDepth: $bitDepth, bitRate: $bitRate)';
}


}

/// @nodoc
abstract mixin class _$VideoFactsCopyWith<$Res> implements $VideoFactsCopyWith<$Res> {
  factory _$VideoFactsCopyWith(_VideoFacts value, $Res Function(_VideoFacts) _then) = __$VideoFactsCopyWithImpl;
@override @useResult
$Res call({
 String? codec, String? profile, int? width, int? height, double? fps, bool? interlaced, int? bitDepth, int? bitRate
});




}
/// @nodoc
class __$VideoFactsCopyWithImpl<$Res>
    implements _$VideoFactsCopyWith<$Res> {
  __$VideoFactsCopyWithImpl(this._self, this._then);

  final _VideoFacts _self;
  final $Res Function(_VideoFacts) _then;

/// Create a copy of VideoFacts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? codec = freezed,Object? profile = freezed,Object? width = freezed,Object? height = freezed,Object? fps = freezed,Object? interlaced = freezed,Object? bitDepth = freezed,Object? bitRate = freezed,}) {
  return _then(_VideoFacts(
codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String?,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,fps: freezed == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double?,interlaced: freezed == interlaced ? _self.interlaced : interlaced // ignore: cast_nullable_to_non_nullable
as bool?,bitDepth: freezed == bitDepth ? _self.bitDepth : bitDepth // ignore: cast_nullable_to_non_nullable
as int?,bitRate: freezed == bitRate ? _self.bitRate : bitRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$AudioFacts {

/// Its place among the audio tracks, from 0: FFmpeg's `0:a:<index>`.
 int get index;/// ffprobe's codec name in lower case: `aac`, `ac3`, `eac3`, `mp2`…
 String? get codec; int? get channels;/// ISO 639 code, lower case.
 String? get language; String? get title; bool get isDefault; int? get bitRate;
/// Create a copy of AudioFacts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioFactsCopyWith<AudioFacts> get copyWith => _$AudioFactsCopyWithImpl<AudioFacts>(this as AudioFacts, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AudioFacts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioFacts&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.codec, _this.codec) || other.codec == _this.codec)&&(identical(other.channels, _this.channels) || other.channels == _this.channels)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.isDefault, _this.isDefault) || other.isDefault == _this.isDefault)&&(identical(other.bitRate, _this.bitRate) || other.bitRate == _this.bitRate));
}


@override
int get hashCode {
  final _this = this as AudioFacts;
  return Object.hash(runtimeType,_this.index,_this.codec,_this.channels,_this.language,_this.title,_this.isDefault,_this.bitRate);
}

@override
String toString() {
  final _this = this as AudioFacts;
  return 'AudioFacts(index: ${_this.index}, codec: ${_this.codec}, channels: ${_this.channels}, language: ${_this.language}, title: ${_this.title}, isDefault: ${_this.isDefault}, bitRate: ${_this.bitRate})';
}


}

/// @nodoc
abstract mixin class $AudioFactsCopyWith<$Res>  {
  factory $AudioFactsCopyWith(AudioFacts value, $Res Function(AudioFacts) _then) = _$AudioFactsCopyWithImpl;
@useResult
$Res call({
 int index, String? codec, int? channels, String? language, String? title, bool isDefault, int? bitRate
});




}
/// @nodoc
class _$AudioFactsCopyWithImpl<$Res>
    implements $AudioFactsCopyWith<$Res> {
  _$AudioFactsCopyWithImpl(this._self, this._then);

  final AudioFacts _self;
  final $Res Function(AudioFacts) _then;

/// Create a copy of AudioFacts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? codec = freezed,Object? channels = freezed,Object? language = freezed,Object? title = freezed,Object? isDefault = null,Object? bitRate = freezed,}) {
  return _then(AudioFacts(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String?,channels: freezed == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,bitRate: freezed == bitRate ? _self.bitRate : bitRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioFacts].
extension AudioFactsPatterns on AudioFacts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioFacts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioFacts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioFacts value)  $default,){
final _that = this;
switch (_that) {
case _AudioFacts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioFacts value)?  $default,){
final _that = this;
switch (_that) {
case _AudioFacts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String? codec,  int? channels,  String? language,  String? title,  bool isDefault,  int? bitRate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioFacts() when $default != null:
return $default(_that.index,_that.codec,_that.channels,_that.language,_that.title,_that.isDefault,_that.bitRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String? codec,  int? channels,  String? language,  String? title,  bool isDefault,  int? bitRate)  $default,) {final _that = this;
switch (_that) {
case _AudioFacts():
return $default(_that.index,_that.codec,_that.channels,_that.language,_that.title,_that.isDefault,_that.bitRate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String? codec,  int? channels,  String? language,  String? title,  bool isDefault,  int? bitRate)?  $default,) {final _that = this;
switch (_that) {
case _AudioFacts() when $default != null:
return $default(_that.index,_that.codec,_that.channels,_that.language,_that.title,_that.isDefault,_that.bitRate);case _:
  return null;

}
}

}

/// @nodoc


class _AudioFacts implements AudioFacts {
  const _AudioFacts({required this.index, this.codec, this.channels, this.language, this.title, this.isDefault = false, this.bitRate});
  

/// Its place among the audio tracks, from 0: FFmpeg's `0:a:<index>`.
@override final  int index;
/// ffprobe's codec name in lower case: `aac`, `ac3`, `eac3`, `mp2`…
@override final  String? codec;
@override final  int? channels;
/// ISO 639 code, lower case.
@override final  String? language;
@override final  String? title;
@override@JsonKey() final  bool isDefault;
@override final  int? bitRate;

/// Create a copy of AudioFacts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioFactsCopyWith<_AudioFacts> get copyWith => __$AudioFactsCopyWithImpl<_AudioFacts>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioFacts&&(identical(other.index, index) || other.index == index)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.language, language) || other.language == language)&&(identical(other.title, title) || other.title == title)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.bitRate, bitRate) || other.bitRate == bitRate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,index,codec,channels,language,title,isDefault,bitRate);
}

@override
String toString() {
    return 'AudioFacts(index: $index, codec: $codec, channels: $channels, language: $language, title: $title, isDefault: $isDefault, bitRate: $bitRate)';
}


}

/// @nodoc
abstract mixin class _$AudioFactsCopyWith<$Res> implements $AudioFactsCopyWith<$Res> {
  factory _$AudioFactsCopyWith(_AudioFacts value, $Res Function(_AudioFacts) _then) = __$AudioFactsCopyWithImpl;
@override @useResult
$Res call({
 int index, String? codec, int? channels, String? language, String? title, bool isDefault, int? bitRate
});




}
/// @nodoc
class __$AudioFactsCopyWithImpl<$Res>
    implements _$AudioFactsCopyWith<$Res> {
  __$AudioFactsCopyWithImpl(this._self, this._then);

  final _AudioFacts _self;
  final $Res Function(_AudioFacts) _then;

/// Create a copy of AudioFacts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? codec = freezed,Object? channels = freezed,Object? language = freezed,Object? title = freezed,Object? isDefault = null,Object? bitRate = freezed,}) {
  return _then(_AudioFacts(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String?,channels: freezed == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,bitRate: freezed == bitRate ? _self.bitRate : bitRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
