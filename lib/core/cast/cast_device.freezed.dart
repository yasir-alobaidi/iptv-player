// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cast_device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CastDevice {

/// The device's own id (TXT `id`, 32 hex digits), the same whichever
/// way it was found; the key everything else is stored under.
 String get id;/// What the user named it (TXT `fn`), such as "Living Room TV".
 String get name;/// The address to connect to, IPv4 whenever the device has one.
 String get host; int get port;/// TXT `md`, such as "Chromecast". The capability profile starts
/// from it (docs/04).
 String? get model;/// TXT `ca`, the capability bits; null when the device sent none, or
/// nothing that reads as a number.
 int? get capabilities;/// What the device says it is running (TXT `rs`), such as "YouTube";
/// null when it runs nothing.
 String? get status;/// Added by the user by its address; listed even when discovery
/// doesn't see it (another subnet, multicast blocked).
 bool get manual;/// False for a device added by address that didn't answer the last
/// check. Found devices always answer: they drop out when they stop.
 bool get answering;
/// Create a copy of CastDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CastDeviceCopyWith<CastDevice> get copyWith => _$CastDeviceCopyWithImpl<CastDevice>(this as CastDevice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CastDevice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CastDevice&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.capabilities, _this.capabilities) || other.capabilities == _this.capabilities)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.manual, _this.manual) || other.manual == _this.manual)&&(identical(other.answering, _this.answering) || other.answering == _this.answering));
}


@override
int get hashCode {
  final _this = this as CastDevice;
  return Object.hash(runtimeType,_this.id,_this.name,_this.host,_this.port,_this.model,_this.capabilities,_this.status,_this.manual,_this.answering);
}

@override
String toString() {
  final _this = this as CastDevice;
  return 'CastDevice(id: ${_this.id}, name: ${_this.name}, host: ${_this.host}, port: ${_this.port}, model: ${_this.model}, capabilities: ${_this.capabilities}, status: ${_this.status}, manual: ${_this.manual}, answering: ${_this.answering})';
}


}

/// @nodoc
abstract mixin class $CastDeviceCopyWith<$Res>  {
  factory $CastDeviceCopyWith(CastDevice value, $Res Function(CastDevice) _then) = _$CastDeviceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String host, int port, String? model, int? capabilities, String? status, bool manual, bool answering
});




}
/// @nodoc
class _$CastDeviceCopyWithImpl<$Res>
    implements $CastDeviceCopyWith<$Res> {
  _$CastDeviceCopyWithImpl(this._self, this._then);

  final CastDevice _self;
  final $Res Function(CastDevice) _then;

/// Create a copy of CastDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? host = null,Object? port = null,Object? model = freezed,Object? capabilities = freezed,Object? status = freezed,Object? manual = null,Object? answering = null,}) {
  return _then(CastDevice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,capabilities: freezed == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as int?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,manual: null == manual ? _self.manual : manual // ignore: cast_nullable_to_non_nullable
as bool,answering: null == answering ? _self.answering : answering // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CastDevice].
extension CastDevicePatterns on CastDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CastDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CastDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CastDevice value)  $default,){
final _that = this;
switch (_that) {
case _CastDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CastDevice value)?  $default,){
final _that = this;
switch (_that) {
case _CastDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String host,  int port,  String? model,  int? capabilities,  String? status,  bool manual,  bool answering)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CastDevice() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.model,_that.capabilities,_that.status,_that.manual,_that.answering);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String host,  int port,  String? model,  int? capabilities,  String? status,  bool manual,  bool answering)  $default,) {final _that = this;
switch (_that) {
case _CastDevice():
return $default(_that.id,_that.name,_that.host,_that.port,_that.model,_that.capabilities,_that.status,_that.manual,_that.answering);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String host,  int port,  String? model,  int? capabilities,  String? status,  bool manual,  bool answering)?  $default,) {final _that = this;
switch (_that) {
case _CastDevice() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.model,_that.capabilities,_that.status,_that.manual,_that.answering);case _:
  return null;

}
}

}

/// @nodoc


class _CastDevice implements CastDevice {
  const _CastDevice({required this.id, required this.name, required this.host, this.port = castPort, this.model, this.capabilities, this.status, this.manual = false, this.answering = true});
  

/// The device's own id (TXT `id`, 32 hex digits), the same whichever
/// way it was found; the key everything else is stored under.
@override final  String id;
/// What the user named it (TXT `fn`), such as "Living Room TV".
@override final  String name;
/// The address to connect to, IPv4 whenever the device has one.
@override final  String host;
@override@JsonKey() final  int port;
/// TXT `md`, such as "Chromecast". The capability profile starts
/// from it (docs/04).
@override final  String? model;
/// TXT `ca`, the capability bits; null when the device sent none, or
/// nothing that reads as a number.
@override final  int? capabilities;
/// What the device says it is running (TXT `rs`), such as "YouTube";
/// null when it runs nothing.
@override final  String? status;
/// Added by the user by its address; listed even when discovery
/// doesn't see it (another subnet, multicast blocked).
@override@JsonKey() final  bool manual;
/// False for a device added by address that didn't answer the last
/// check. Found devices always answer: they drop out when they stop.
@override@JsonKey() final  bool answering;

/// Create a copy of CastDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CastDeviceCopyWith<_CastDevice> get copyWith => __$CastDeviceCopyWithImpl<_CastDevice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CastDevice&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.model, model) || other.model == model)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities)&&(identical(other.status, status) || other.status == status)&&(identical(other.manual, manual) || other.manual == manual)&&(identical(other.answering, answering) || other.answering == answering));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,host,port,model,capabilities,status,manual,answering);
}

@override
String toString() {
    return 'CastDevice(id: $id, name: $name, host: $host, port: $port, model: $model, capabilities: $capabilities, status: $status, manual: $manual, answering: $answering)';
}


}

/// @nodoc
abstract mixin class _$CastDeviceCopyWith<$Res> implements $CastDeviceCopyWith<$Res> {
  factory _$CastDeviceCopyWith(_CastDevice value, $Res Function(_CastDevice) _then) = __$CastDeviceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String host, int port, String? model, int? capabilities, String? status, bool manual, bool answering
});




}
/// @nodoc
class __$CastDeviceCopyWithImpl<$Res>
    implements _$CastDeviceCopyWith<$Res> {
  __$CastDeviceCopyWithImpl(this._self, this._then);

  final _CastDevice _self;
  final $Res Function(_CastDevice) _then;

/// Create a copy of CastDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? host = null,Object? port = null,Object? model = freezed,Object? capabilities = freezed,Object? status = freezed,Object? manual = null,Object? answering = null,}) {
  return _then(_CastDevice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,capabilities: freezed == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as int?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,manual: null == manual ? _self.manual : manual // ignore: cast_nullable_to_non_nullable
as bool,answering: null == answering ? _self.answering : answering // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$CastLearned {

/// The tallest picture the device took; null until one was refused.
 int? get maxHeight;/// Video and audio codecs it refused (ffprobe's names, such as
/// `hevc`), transcoded from then on.
 Set<String> get refusedCodecs;/// Sources whose streams it could not play directly (docs/04 rule 1);
/// they go through the relay from then on.
 Set<String> get directRefusedSources;
/// Create a copy of CastLearned
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CastLearnedCopyWith<CastLearned> get copyWith => _$CastLearnedCopyWithImpl<CastLearned>(this as CastLearned, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CastLearned;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CastLearned&&(identical(other.maxHeight, _this.maxHeight) || other.maxHeight == _this.maxHeight)&&const DeepCollectionEquality().equals(other.refusedCodecs, _this.refusedCodecs)&&const DeepCollectionEquality().equals(other.directRefusedSources, _this.directRefusedSources));
}


@override
int get hashCode {
  final _this = this as CastLearned;
  return Object.hash(runtimeType,_this.maxHeight,const DeepCollectionEquality().hash(_this.refusedCodecs),const DeepCollectionEquality().hash(_this.directRefusedSources));
}

@override
String toString() {
  final _this = this as CastLearned;
  return 'CastLearned(maxHeight: ${_this.maxHeight}, refusedCodecs: ${_this.refusedCodecs}, directRefusedSources: ${_this.directRefusedSources})';
}


}

/// @nodoc
abstract mixin class $CastLearnedCopyWith<$Res>  {
  factory $CastLearnedCopyWith(CastLearned value, $Res Function(CastLearned) _then) = _$CastLearnedCopyWithImpl;
@useResult
$Res call({
 int? maxHeight, Set<String> refusedCodecs, Set<String> directRefusedSources
});




}
/// @nodoc
class _$CastLearnedCopyWithImpl<$Res>
    implements $CastLearnedCopyWith<$Res> {
  _$CastLearnedCopyWithImpl(this._self, this._then);

  final CastLearned _self;
  final $Res Function(CastLearned) _then;

/// Create a copy of CastLearned
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? maxHeight = freezed,Object? refusedCodecs = null,Object? directRefusedSources = null,}) {
  return _then(CastLearned(
maxHeight: freezed == maxHeight ? _self.maxHeight : maxHeight // ignore: cast_nullable_to_non_nullable
as int?,refusedCodecs: null == refusedCodecs ? _self.refusedCodecs : refusedCodecs // ignore: cast_nullable_to_non_nullable
as Set<String>,directRefusedSources: null == directRefusedSources ? _self.directRefusedSources : directRefusedSources // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [CastLearned].
extension CastLearnedPatterns on CastLearned {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CastLearned value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CastLearned() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CastLearned value)  $default,){
final _that = this;
switch (_that) {
case _CastLearned():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CastLearned value)?  $default,){
final _that = this;
switch (_that) {
case _CastLearned() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? maxHeight,  Set<String> refusedCodecs,  Set<String> directRefusedSources)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CastLearned() when $default != null:
return $default(_that.maxHeight,_that.refusedCodecs,_that.directRefusedSources);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? maxHeight,  Set<String> refusedCodecs,  Set<String> directRefusedSources)  $default,) {final _that = this;
switch (_that) {
case _CastLearned():
return $default(_that.maxHeight,_that.refusedCodecs,_that.directRefusedSources);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? maxHeight,  Set<String> refusedCodecs,  Set<String> directRefusedSources)?  $default,) {final _that = this;
switch (_that) {
case _CastLearned() when $default != null:
return $default(_that.maxHeight,_that.refusedCodecs,_that.directRefusedSources);case _:
  return null;

}
}

}

/// @nodoc


class _CastLearned implements CastLearned {
  const _CastLearned({this.maxHeight,  Set<String> refusedCodecs = const <String>{},  Set<String> directRefusedSources = const <String>{}}): _refusedCodecs = refusedCodecs,_directRefusedSources = directRefusedSources;
  

/// The tallest picture the device took; null until one was refused.
@override final  int? maxHeight;
/// Video and audio codecs it refused (ffprobe's names, such as
/// `hevc`), transcoded from then on.
 final  Set<String> _refusedCodecs;
/// Video and audio codecs it refused (ffprobe's names, such as
/// `hevc`), transcoded from then on.
@override@JsonKey() Set<String> get refusedCodecs {
  if (_refusedCodecs is EqualUnmodifiableSetView) return _refusedCodecs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_refusedCodecs);
}

/// Sources whose streams it could not play directly (docs/04 rule 1);
/// they go through the relay from then on.
 final  Set<String> _directRefusedSources;
/// Sources whose streams it could not play directly (docs/04 rule 1);
/// they go through the relay from then on.
@override@JsonKey() Set<String> get directRefusedSources {
  if (_directRefusedSources is EqualUnmodifiableSetView) return _directRefusedSources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_directRefusedSources);
}


/// Create a copy of CastLearned
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CastLearnedCopyWith<_CastLearned> get copyWith => __$CastLearnedCopyWithImpl<_CastLearned>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CastLearned&&(identical(other.maxHeight, maxHeight) || other.maxHeight == maxHeight)&&const DeepCollectionEquality().equals(other.refusedCodecs, _refusedCodecs)&&const DeepCollectionEquality().equals(other.directRefusedSources, _directRefusedSources));
}


@override
int get hashCode {
    return Object.hash(runtimeType,maxHeight,const DeepCollectionEquality().hash(_refusedCodecs),const DeepCollectionEquality().hash(_directRefusedSources));
}

@override
String toString() {
    return 'CastLearned(maxHeight: $maxHeight, refusedCodecs: $refusedCodecs, directRefusedSources: $directRefusedSources)';
}


}

/// @nodoc
abstract mixin class _$CastLearnedCopyWith<$Res> implements $CastLearnedCopyWith<$Res> {
  factory _$CastLearnedCopyWith(_CastLearned value, $Res Function(_CastLearned) _then) = __$CastLearnedCopyWithImpl;
@override @useResult
$Res call({
 int? maxHeight, Set<String> refusedCodecs, Set<String> directRefusedSources
});




}
/// @nodoc
class __$CastLearnedCopyWithImpl<$Res>
    implements _$CastLearnedCopyWith<$Res> {
  __$CastLearnedCopyWithImpl(this._self, this._then);

  final _CastLearned _self;
  final $Res Function(_CastLearned) _then;

/// Create a copy of CastLearned
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? maxHeight = freezed,Object? refusedCodecs = null,Object? directRefusedSources = null,}) {
  return _then(_CastLearned(
maxHeight: freezed == maxHeight ? _self.maxHeight : maxHeight // ignore: cast_nullable_to_non_nullable
as int?,refusedCodecs: null == refusedCodecs ? _self._refusedCodecs : refusedCodecs // ignore: cast_nullable_to_non_nullable
as Set<String>,directRefusedSources: null == directRefusedSources ? _self._directRefusedSources : directRefusedSources // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

/// @nodoc
mixin _$KnownCastDevice {

 String get id; String get name;/// The address it had when last seen or used.
 String get host; int get port; bool get manual; HevcSupport get hevc; CastLearned get learned; String? get model; DateTime? get lastUsedAt;
/// Create a copy of KnownCastDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KnownCastDeviceCopyWith<KnownCastDevice> get copyWith => _$KnownCastDeviceCopyWithImpl<KnownCastDevice>(this as KnownCastDevice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as KnownCastDevice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KnownCastDevice&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.manual, _this.manual) || other.manual == _this.manual)&&(identical(other.hevc, _this.hevc) || other.hevc == _this.hevc)&&(identical(other.learned, _this.learned) || other.learned == _this.learned)&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.lastUsedAt, _this.lastUsedAt) || other.lastUsedAt == _this.lastUsedAt));
}


@override
int get hashCode {
  final _this = this as KnownCastDevice;
  return Object.hash(runtimeType,_this.id,_this.name,_this.host,_this.port,_this.manual,_this.hevc,_this.learned,_this.model,_this.lastUsedAt);
}

@override
String toString() {
  final _this = this as KnownCastDevice;
  return 'KnownCastDevice(id: ${_this.id}, name: ${_this.name}, host: ${_this.host}, port: ${_this.port}, manual: ${_this.manual}, hevc: ${_this.hevc}, learned: ${_this.learned}, model: ${_this.model}, lastUsedAt: ${_this.lastUsedAt})';
}


}

/// @nodoc
abstract mixin class $KnownCastDeviceCopyWith<$Res>  {
  factory $KnownCastDeviceCopyWith(KnownCastDevice value, $Res Function(KnownCastDevice) _then) = _$KnownCastDeviceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String host, int port, bool manual, HevcSupport hevc, CastLearned learned, String? model, DateTime? lastUsedAt
});


$CastLearnedCopyWith<$Res> get learned;

}
/// @nodoc
class _$KnownCastDeviceCopyWithImpl<$Res>
    implements $KnownCastDeviceCopyWith<$Res> {
  _$KnownCastDeviceCopyWithImpl(this._self, this._then);

  final KnownCastDevice _self;
  final $Res Function(KnownCastDevice) _then;

/// Create a copy of KnownCastDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? host = null,Object? port = null,Object? manual = null,Object? hevc = null,Object? learned = null,Object? model = freezed,Object? lastUsedAt = freezed,}) {
  return _then(KnownCastDevice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,manual: null == manual ? _self.manual : manual // ignore: cast_nullable_to_non_nullable
as bool,hevc: null == hevc ? _self.hevc : hevc // ignore: cast_nullable_to_non_nullable
as HevcSupport,learned: null == learned ? _self.learned : learned // ignore: cast_nullable_to_non_nullable
as CastLearned,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of KnownCastDevice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastLearnedCopyWith<$Res> get learned {
  
  return $CastLearnedCopyWith<$Res>(_self.learned, (value) {
    return _then(_self.copyWith(learned: value));
  });
}
}


/// Adds pattern-matching-related methods to [KnownCastDevice].
extension KnownCastDevicePatterns on KnownCastDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KnownCastDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KnownCastDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KnownCastDevice value)  $default,){
final _that = this;
switch (_that) {
case _KnownCastDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KnownCastDevice value)?  $default,){
final _that = this;
switch (_that) {
case _KnownCastDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String host,  int port,  bool manual,  HevcSupport hevc,  CastLearned learned,  String? model,  DateTime? lastUsedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KnownCastDevice() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.manual,_that.hevc,_that.learned,_that.model,_that.lastUsedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String host,  int port,  bool manual,  HevcSupport hevc,  CastLearned learned,  String? model,  DateTime? lastUsedAt)  $default,) {final _that = this;
switch (_that) {
case _KnownCastDevice():
return $default(_that.id,_that.name,_that.host,_that.port,_that.manual,_that.hevc,_that.learned,_that.model,_that.lastUsedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String host,  int port,  bool manual,  HevcSupport hevc,  CastLearned learned,  String? model,  DateTime? lastUsedAt)?  $default,) {final _that = this;
switch (_that) {
case _KnownCastDevice() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.manual,_that.hevc,_that.learned,_that.model,_that.lastUsedAt);case _:
  return null;

}
}

}

/// @nodoc


class _KnownCastDevice implements KnownCastDevice {
  const _KnownCastDevice({required this.id, required this.name, required this.host, required this.port, required this.manual, required this.hevc, required this.learned, this.model, this.lastUsedAt});
  

@override final  String id;
@override final  String name;
/// The address it had when last seen or used.
@override final  String host;
@override final  int port;
@override final  bool manual;
@override final  HevcSupport hevc;
@override final  CastLearned learned;
@override final  String? model;
@override final  DateTime? lastUsedAt;

/// Create a copy of KnownCastDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KnownCastDeviceCopyWith<_KnownCastDevice> get copyWith => __$KnownCastDeviceCopyWithImpl<_KnownCastDevice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _KnownCastDevice&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.manual, manual) || other.manual == manual)&&(identical(other.hevc, hevc) || other.hevc == hevc)&&(identical(other.learned, learned) || other.learned == learned)&&(identical(other.model, model) || other.model == model)&&(identical(other.lastUsedAt, lastUsedAt) || other.lastUsedAt == lastUsedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,host,port,manual,hevc,learned,model,lastUsedAt);
}

@override
String toString() {
    return 'KnownCastDevice(id: $id, name: $name, host: $host, port: $port, manual: $manual, hevc: $hevc, learned: $learned, model: $model, lastUsedAt: $lastUsedAt)';
}


}

/// @nodoc
abstract mixin class _$KnownCastDeviceCopyWith<$Res> implements $KnownCastDeviceCopyWith<$Res> {
  factory _$KnownCastDeviceCopyWith(_KnownCastDevice value, $Res Function(_KnownCastDevice) _then) = __$KnownCastDeviceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String host, int port, bool manual, HevcSupport hevc, CastLearned learned, String? model, DateTime? lastUsedAt
});


@override $CastLearnedCopyWith<$Res> get learned;

}
/// @nodoc
class __$KnownCastDeviceCopyWithImpl<$Res>
    implements _$KnownCastDeviceCopyWith<$Res> {
  __$KnownCastDeviceCopyWithImpl(this._self, this._then);

  final _KnownCastDevice _self;
  final $Res Function(_KnownCastDevice) _then;

/// Create a copy of KnownCastDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? host = null,Object? port = null,Object? manual = null,Object? hevc = null,Object? learned = null,Object? model = freezed,Object? lastUsedAt = freezed,}) {
  return _then(_KnownCastDevice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,manual: null == manual ? _self.manual : manual // ignore: cast_nullable_to_non_nullable
as bool,hevc: null == hevc ? _self.hevc : hevc // ignore: cast_nullable_to_non_nullable
as HevcSupport,learned: null == learned ? _self.learned : learned // ignore: cast_nullable_to_non_nullable
as CastLearned,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,lastUsedAt: freezed == lastUsedAt ? _self.lastUsedAt : lastUsedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of KnownCastDevice
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastLearnedCopyWith<$Res> get learned {
  
  return $CastLearnedCopyWith<$Res>(_self.learned, (value) {
    return _then(_self.copyWith(learned: value));
  });
}
}

// dart format on
