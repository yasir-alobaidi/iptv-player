// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'casting_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CastingState {

 CastPhase get phase;/// The device, while there is a session.
 CastDevice? get device;/// What is cast, or was when it ended or failed.
 Playable? get item;/// How it is cast: the badge, its sentence and the details line.
 CastPlan? get plan;/// Paused, with our controls or the TV's remote.
 bool get paused;/// The TV is filling its buffer. On live HLS this comes and goes with
/// nothing visible (docs/04): the view may show it, never as a stall.
 bool get buffering;/// The connection to the device broke and is being made again; the TV
/// plays on meanwhile (the pill).
 bool get reconnecting; CastVolume get volume;/// Why it failed, for [CastPhase.failed].
 CastProblem? get problem;
/// Create a copy of CastingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CastingStateCopyWith<CastingState> get copyWith => _$CastingStateCopyWithImpl<CastingState>(this as CastingState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CastingState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CastingState&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&(identical(other.device, _this.device) || other.device == _this.device)&&(identical(other.item, _this.item) || other.item == _this.item)&&(identical(other.plan, _this.plan) || other.plan == _this.plan)&&(identical(other.paused, _this.paused) || other.paused == _this.paused)&&(identical(other.buffering, _this.buffering) || other.buffering == _this.buffering)&&(identical(other.reconnecting, _this.reconnecting) || other.reconnecting == _this.reconnecting)&&(identical(other.volume, _this.volume) || other.volume == _this.volume)&&(identical(other.problem, _this.problem) || other.problem == _this.problem));
}


@override
int get hashCode {
  final _this = this as CastingState;
  return Object.hash(runtimeType,_this.phase,_this.device,_this.item,_this.plan,_this.paused,_this.buffering,_this.reconnecting,_this.volume,_this.problem);
}

@override
String toString() {
  final _this = this as CastingState;
  return 'CastingState(phase: ${_this.phase}, device: ${_this.device}, item: ${_this.item}, plan: ${_this.plan}, paused: ${_this.paused}, buffering: ${_this.buffering}, reconnecting: ${_this.reconnecting}, volume: ${_this.volume}, problem: ${_this.problem})';
}


}

/// @nodoc
abstract mixin class $CastingStateCopyWith<$Res>  {
  factory $CastingStateCopyWith(CastingState value, $Res Function(CastingState) _then) = _$CastingStateCopyWithImpl;
@useResult
$Res call({
 CastPhase phase, CastDevice? device, Playable? item, CastPlan? plan, bool paused, bool buffering, bool reconnecting, CastVolume volume, CastProblem? problem
});


$CastDeviceCopyWith<$Res>? get device;$CastVolumeCopyWith<$Res> get volume;

}
/// @nodoc
class _$CastingStateCopyWithImpl<$Res>
    implements $CastingStateCopyWith<$Res> {
  _$CastingStateCopyWithImpl(this._self, this._then);

  final CastingState _self;
  final $Res Function(CastingState) _then;

/// Create a copy of CastingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? device = freezed,Object? item = freezed,Object? plan = freezed,Object? paused = null,Object? buffering = null,Object? reconnecting = null,Object? volume = null,Object? problem = freezed,}) {
  return _then(CastingState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as CastPhase,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as CastDevice?,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as Playable?,plan: freezed == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as CastPlan?,paused: null == paused ? _self.paused : paused // ignore: cast_nullable_to_non_nullable
as bool,buffering: null == buffering ? _self.buffering : buffering // ignore: cast_nullable_to_non_nullable
as bool,reconnecting: null == reconnecting ? _self.reconnecting : reconnecting // ignore: cast_nullable_to_non_nullable
as bool,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as CastVolume,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as CastProblem?,
  ));
}
/// Create a copy of CastingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastDeviceCopyWith<$Res>? get device {
    if (_self.device == null) {
    return null;
  }

  return $CastDeviceCopyWith<$Res>(_self.device!, (value) {
    return _then(_self.copyWith(device: value));
  });
}/// Create a copy of CastingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastVolumeCopyWith<$Res> get volume {
  
  return $CastVolumeCopyWith<$Res>(_self.volume, (value) {
    return _then(_self.copyWith(volume: value));
  });
}
}


/// Adds pattern-matching-related methods to [CastingState].
extension CastingStatePatterns on CastingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CastingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CastingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CastingState value)  $default,){
final _that = this;
switch (_that) {
case _CastingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CastingState value)?  $default,){
final _that = this;
switch (_that) {
case _CastingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CastPhase phase,  CastDevice? device,  Playable? item,  CastPlan? plan,  bool paused,  bool buffering,  bool reconnecting,  CastVolume volume,  CastProblem? problem)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CastingState() when $default != null:
return $default(_that.phase,_that.device,_that.item,_that.plan,_that.paused,_that.buffering,_that.reconnecting,_that.volume,_that.problem);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CastPhase phase,  CastDevice? device,  Playable? item,  CastPlan? plan,  bool paused,  bool buffering,  bool reconnecting,  CastVolume volume,  CastProblem? problem)  $default,) {final _that = this;
switch (_that) {
case _CastingState():
return $default(_that.phase,_that.device,_that.item,_that.plan,_that.paused,_that.buffering,_that.reconnecting,_that.volume,_that.problem);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CastPhase phase,  CastDevice? device,  Playable? item,  CastPlan? plan,  bool paused,  bool buffering,  bool reconnecting,  CastVolume volume,  CastProblem? problem)?  $default,) {final _that = this;
switch (_that) {
case _CastingState() when $default != null:
return $default(_that.phase,_that.device,_that.item,_that.plan,_that.paused,_that.buffering,_that.reconnecting,_that.volume,_that.problem);case _:
  return null;

}
}

}

/// @nodoc


class _CastingState extends CastingState {
  const _CastingState({this.phase = CastPhase.off, this.device, this.item, this.plan, this.paused = false, this.buffering = false, this.reconnecting = false, this.volume = const CastVolume(), this.problem}): super._();
  

@override@JsonKey() final  CastPhase phase;
/// The device, while there is a session.
@override final  CastDevice? device;
/// What is cast, or was when it ended or failed.
@override final  Playable? item;
/// How it is cast: the badge, its sentence and the details line.
@override final  CastPlan? plan;
/// Paused, with our controls or the TV's remote.
@override@JsonKey() final  bool paused;
/// The TV is filling its buffer. On live HLS this comes and goes with
/// nothing visible (docs/04): the view may show it, never as a stall.
@override@JsonKey() final  bool buffering;
/// The connection to the device broke and is being made again; the TV
/// plays on meanwhile (the pill).
@override@JsonKey() final  bool reconnecting;
@override@JsonKey() final  CastVolume volume;
/// Why it failed, for [CastPhase.failed].
@override final  CastProblem? problem;

/// Create a copy of CastingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CastingStateCopyWith<_CastingState> get copyWith => __$CastingStateCopyWithImpl<_CastingState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CastingState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.device, device) || other.device == device)&&(identical(other.item, item) || other.item == item)&&(identical(other.plan, plan) || other.plan == plan)&&(identical(other.paused, paused) || other.paused == paused)&&(identical(other.buffering, buffering) || other.buffering == buffering)&&(identical(other.reconnecting, reconnecting) || other.reconnecting == reconnecting)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.problem, problem) || other.problem == problem));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phase,device,item,plan,paused,buffering,reconnecting,volume,problem);
}

@override
String toString() {
    return 'CastingState(phase: $phase, device: $device, item: $item, plan: $plan, paused: $paused, buffering: $buffering, reconnecting: $reconnecting, volume: $volume, problem: $problem)';
}


}

/// @nodoc
abstract mixin class _$CastingStateCopyWith<$Res> implements $CastingStateCopyWith<$Res> {
  factory _$CastingStateCopyWith(_CastingState value, $Res Function(_CastingState) _then) = __$CastingStateCopyWithImpl;
@override @useResult
$Res call({
 CastPhase phase, CastDevice? device, Playable? item, CastPlan? plan, bool paused, bool buffering, bool reconnecting, CastVolume volume, CastProblem? problem
});


@override $CastDeviceCopyWith<$Res>? get device;@override $CastVolumeCopyWith<$Res> get volume;

}
/// @nodoc
class __$CastingStateCopyWithImpl<$Res>
    implements _$CastingStateCopyWith<$Res> {
  __$CastingStateCopyWithImpl(this._self, this._then);

  final _CastingState _self;
  final $Res Function(_CastingState) _then;

/// Create a copy of CastingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? device = freezed,Object? item = freezed,Object? plan = freezed,Object? paused = null,Object? buffering = null,Object? reconnecting = null,Object? volume = null,Object? problem = freezed,}) {
  return _then(_CastingState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as CastPhase,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as CastDevice?,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as Playable?,plan: freezed == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as CastPlan?,paused: null == paused ? _self.paused : paused // ignore: cast_nullable_to_non_nullable
as bool,buffering: null == buffering ? _self.buffering : buffering // ignore: cast_nullable_to_non_nullable
as bool,reconnecting: null == reconnecting ? _self.reconnecting : reconnecting // ignore: cast_nullable_to_non_nullable
as bool,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as CastVolume,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as CastProblem?,
  ));
}

/// Create a copy of CastingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastDeviceCopyWith<$Res>? get device {
    if (_self.device == null) {
    return null;
  }

  return $CastDeviceCopyWith<$Res>(_self.device!, (value) {
    return _then(_self.copyWith(device: value));
  });
}/// Create a copy of CastingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CastVolumeCopyWith<$Res> get volume {
  
  return $CastVolumeCopyWith<$Res>(_self.volume, (value) {
    return _then(_self.copyWith(volume: value));
  });
}
}

// dart format on
