// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProviderAccount {

/// `Active`, `Expired`, `Banned`, `Disabled`, as the panel words it.
 String? get status;/// Null means the account doesn't expire.
 DateTime? get expiresAt; bool get isTrial; int? get activeConnections; int? get maxConnections;/// The live formats the panel offers, lower case: `ts`, `m3u8`, `rtmp`.
 List<String> get allowedFormats;/// The panel's time zone name, e.g. `Europe/London`.
 String? get serverTimezone;
/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderAccountCopyWith<ProviderAccount> get copyWith => _$ProviderAccountCopyWithImpl<ProviderAccount>(this as ProviderAccount, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProviderAccount;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderAccount&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.isTrial, _this.isTrial) || other.isTrial == _this.isTrial)&&(identical(other.activeConnections, _this.activeConnections) || other.activeConnections == _this.activeConnections)&&(identical(other.maxConnections, _this.maxConnections) || other.maxConnections == _this.maxConnections)&&const DeepCollectionEquality().equals(other.allowedFormats, _this.allowedFormats)&&(identical(other.serverTimezone, _this.serverTimezone) || other.serverTimezone == _this.serverTimezone));
}


@override
int get hashCode {
  final _this = this as ProviderAccount;
  return Object.hash(runtimeType,_this.status,_this.expiresAt,_this.isTrial,_this.activeConnections,_this.maxConnections,const DeepCollectionEquality().hash(_this.allowedFormats),_this.serverTimezone);
}

@override
String toString() {
  final _this = this as ProviderAccount;
  return 'ProviderAccount(status: ${_this.status}, expiresAt: ${_this.expiresAt}, isTrial: ${_this.isTrial}, activeConnections: ${_this.activeConnections}, maxConnections: ${_this.maxConnections}, allowedFormats: ${_this.allowedFormats}, serverTimezone: ${_this.serverTimezone})';
}


}

/// @nodoc
abstract mixin class $ProviderAccountCopyWith<$Res>  {
  factory $ProviderAccountCopyWith(ProviderAccount value, $Res Function(ProviderAccount) _then) = _$ProviderAccountCopyWithImpl;
@useResult
$Res call({
 String? status, DateTime? expiresAt, bool isTrial, int? activeConnections, int? maxConnections, List<String> allowedFormats, String? serverTimezone
});




}
/// @nodoc
class _$ProviderAccountCopyWithImpl<$Res>
    implements $ProviderAccountCopyWith<$Res> {
  _$ProviderAccountCopyWithImpl(this._self, this._then);

  final ProviderAccount _self;
  final $Res Function(ProviderAccount) _then;

/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = freezed,Object? expiresAt = freezed,Object? isTrial = null,Object? activeConnections = freezed,Object? maxConnections = freezed,Object? allowedFormats = null,Object? serverTimezone = freezed,}) {
  return _then(ProviderAccount(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isTrial: null == isTrial ? _self.isTrial : isTrial // ignore: cast_nullable_to_non_nullable
as bool,activeConnections: freezed == activeConnections ? _self.activeConnections : activeConnections // ignore: cast_nullable_to_non_nullable
as int?,maxConnections: freezed == maxConnections ? _self.maxConnections : maxConnections // ignore: cast_nullable_to_non_nullable
as int?,allowedFormats: null == allowedFormats ? _self.allowedFormats : allowedFormats // ignore: cast_nullable_to_non_nullable
as List<String>,serverTimezone: freezed == serverTimezone ? _self.serverTimezone : serverTimezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderAccount].
extension ProviderAccountPatterns on ProviderAccount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderAccount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderAccount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderAccount value)  $default,){
final _that = this;
switch (_that) {
case _ProviderAccount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderAccount value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderAccount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? status,  DateTime? expiresAt,  bool isTrial,  int? activeConnections,  int? maxConnections,  List<String> allowedFormats,  String? serverTimezone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderAccount() when $default != null:
return $default(_that.status,_that.expiresAt,_that.isTrial,_that.activeConnections,_that.maxConnections,_that.allowedFormats,_that.serverTimezone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? status,  DateTime? expiresAt,  bool isTrial,  int? activeConnections,  int? maxConnections,  List<String> allowedFormats,  String? serverTimezone)  $default,) {final _that = this;
switch (_that) {
case _ProviderAccount():
return $default(_that.status,_that.expiresAt,_that.isTrial,_that.activeConnections,_that.maxConnections,_that.allowedFormats,_that.serverTimezone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? status,  DateTime? expiresAt,  bool isTrial,  int? activeConnections,  int? maxConnections,  List<String> allowedFormats,  String? serverTimezone)?  $default,) {final _that = this;
switch (_that) {
case _ProviderAccount() when $default != null:
return $default(_that.status,_that.expiresAt,_that.isTrial,_that.activeConnections,_that.maxConnections,_that.allowedFormats,_that.serverTimezone);case _:
  return null;

}
}

}

/// @nodoc


class _ProviderAccount implements ProviderAccount {
  const _ProviderAccount({this.status, this.expiresAt, this.isTrial = false, this.activeConnections, this.maxConnections,  List<String> allowedFormats = const <String>[], this.serverTimezone}): _allowedFormats = allowedFormats;
  

/// `Active`, `Expired`, `Banned`, `Disabled`, as the panel words it.
@override final  String? status;
/// Null means the account doesn't expire.
@override final  DateTime? expiresAt;
@override@JsonKey() final  bool isTrial;
@override final  int? activeConnections;
@override final  int? maxConnections;
/// The live formats the panel offers, lower case: `ts`, `m3u8`, `rtmp`.
 final  List<String> _allowedFormats;
/// The live formats the panel offers, lower case: `ts`, `m3u8`, `rtmp`.
@override@JsonKey() List<String> get allowedFormats {
  if (_allowedFormats is EqualUnmodifiableListView) return _allowedFormats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allowedFormats);
}

/// The panel's time zone name, e.g. `Europe/London`.
@override final  String? serverTimezone;

/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderAccountCopyWith<_ProviderAccount> get copyWith => __$ProviderAccountCopyWithImpl<_ProviderAccount>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderAccount&&(identical(other.status, status) || other.status == status)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.isTrial, isTrial) || other.isTrial == isTrial)&&(identical(other.activeConnections, activeConnections) || other.activeConnections == activeConnections)&&(identical(other.maxConnections, maxConnections) || other.maxConnections == maxConnections)&&const DeepCollectionEquality().equals(other.allowedFormats, _allowedFormats)&&(identical(other.serverTimezone, serverTimezone) || other.serverTimezone == serverTimezone));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,expiresAt,isTrial,activeConnections,maxConnections,const DeepCollectionEquality().hash(_allowedFormats),serverTimezone);
}

@override
String toString() {
    return 'ProviderAccount(status: $status, expiresAt: $expiresAt, isTrial: $isTrial, activeConnections: $activeConnections, maxConnections: $maxConnections, allowedFormats: $allowedFormats, serverTimezone: $serverTimezone)';
}


}

/// @nodoc
abstract mixin class _$ProviderAccountCopyWith<$Res> implements $ProviderAccountCopyWith<$Res> {
  factory _$ProviderAccountCopyWith(_ProviderAccount value, $Res Function(_ProviderAccount) _then) = __$ProviderAccountCopyWithImpl;
@override @useResult
$Res call({
 String? status, DateTime? expiresAt, bool isTrial, int? activeConnections, int? maxConnections, List<String> allowedFormats, String? serverTimezone
});




}
/// @nodoc
class __$ProviderAccountCopyWithImpl<$Res>
    implements _$ProviderAccountCopyWith<$Res> {
  __$ProviderAccountCopyWithImpl(this._self, this._then);

  final _ProviderAccount _self;
  final $Res Function(_ProviderAccount) _then;

/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = freezed,Object? expiresAt = freezed,Object? isTrial = null,Object? activeConnections = freezed,Object? maxConnections = freezed,Object? allowedFormats = null,Object? serverTimezone = freezed,}) {
  return _then(_ProviderAccount(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isTrial: null == isTrial ? _self.isTrial : isTrial // ignore: cast_nullable_to_non_nullable
as bool,activeConnections: freezed == activeConnections ? _self.activeConnections : activeConnections // ignore: cast_nullable_to_non_nullable
as int?,maxConnections: freezed == maxConnections ? _self.maxConnections : maxConnections // ignore: cast_nullable_to_non_nullable
as int?,allowedFormats: null == allowedFormats ? _self._allowedFormats : allowedFormats // ignore: cast_nullable_to_non_nullable
as List<String>,serverTimezone: freezed == serverTimezone ? _self.serverTimezone : serverTimezone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
