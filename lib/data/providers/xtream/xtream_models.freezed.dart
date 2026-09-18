// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xtream_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$XtreamRows<T> {

 List<T> get items; int get skipped;
/// Create a copy of XtreamRows
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamRowsCopyWith<T, XtreamRows<T>> get copyWith => _$XtreamRowsCopyWithImpl<T, XtreamRows<T>>(this as XtreamRows<T>, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamRows<T>;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamRows<T>&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped));
}


@override
int get hashCode {
  final _this = this as XtreamRows<T>;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items),_this.skipped);
}

@override
String toString() {
  final _this = this as XtreamRows<T>;
  return 'XtreamRows<$T>(items: ${_this.items}, skipped: ${_this.skipped})';
}


}

/// @nodoc
abstract mixin class $XtreamRowsCopyWith<T,$Res>  {
  factory $XtreamRowsCopyWith(XtreamRows<T> value, $Res Function(XtreamRows<T>) _then) = _$XtreamRowsCopyWithImpl;
@useResult
$Res call({
 List<T> items, int skipped
});




}
/// @nodoc
class _$XtreamRowsCopyWithImpl<T,$Res>
    implements $XtreamRowsCopyWith<T, $Res> {
  _$XtreamRowsCopyWithImpl(this._self, this._then);

  final XtreamRows<T> _self;
  final $Res Function(XtreamRows<T>) _then;

/// Create a copy of XtreamRows
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? skipped = null,}) {
  return _then(XtreamRows(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<T>,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamRows].
extension XtreamRowsPatterns<T> on XtreamRows<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamRows<T> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamRows() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamRows<T> value)  $default,){
final _that = this;
switch (_that) {
case _XtreamRows():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamRows<T> value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamRows() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<T> items,  int skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamRows() when $default != null:
return $default(_that.items,_that.skipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<T> items,  int skipped)  $default,) {final _that = this;
switch (_that) {
case _XtreamRows():
return $default(_that.items,_that.skipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<T> items,  int skipped)?  $default,) {final _that = this;
switch (_that) {
case _XtreamRows() when $default != null:
return $default(_that.items,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamRows<T> implements XtreamRows<T> {
  const _XtreamRows({required  List<T> items, this.skipped = 0}): _items = items;
  

 final  List<T> _items;
@override List<T> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int skipped;

/// Create a copy of XtreamRows
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamRowsCopyWith<T, _XtreamRows<T>> get copyWith => __$XtreamRowsCopyWithImpl<T, _XtreamRows<T>>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamRows<T>&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),skipped);
}

@override
String toString() {
    return 'XtreamRows<$T>(items: $items, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$XtreamRowsCopyWith<T,$Res> implements $XtreamRowsCopyWith<T, $Res> {
  factory _$XtreamRowsCopyWith(_XtreamRows<T> value, $Res Function(_XtreamRows<T>) _then) = __$XtreamRowsCopyWithImpl;
@override @useResult
$Res call({
 List<T> items, int skipped
});




}
/// @nodoc
class __$XtreamRowsCopyWithImpl<T,$Res>
    implements _$XtreamRowsCopyWith<T, $Res> {
  __$XtreamRowsCopyWithImpl(this._self, this._then);

  final _XtreamRows<T> _self;
  final $Res Function(_XtreamRows<T>) _then;

/// Create a copy of XtreamRows
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? skipped = null,}) {
  return _then(_XtreamRows<T>(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<T>,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$XtreamAccount {

/// `Active`, `Expired`, `Banned`, `Disabled`, as the panel words it.
 String? get status;/// Null means no expiry (docs/02).
 DateTime? get expiresAt; bool get isTrial; int? get activeConnections; int? get maxConnections; DateTime? get createdAt; List<String> get allowedOutputFormats;/// The panel's time zone name, e.g. `Europe/London`.
 String? get serverTimezone;/// The panel's clock when it answered, for spotting a skewed server.
 DateTime? get serverTime;
/// Create a copy of XtreamAccount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamAccountCopyWith<XtreamAccount> get copyWith => _$XtreamAccountCopyWithImpl<XtreamAccount>(this as XtreamAccount, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamAccount;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamAccount&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.isTrial, _this.isTrial) || other.isTrial == _this.isTrial)&&(identical(other.activeConnections, _this.activeConnections) || other.activeConnections == _this.activeConnections)&&(identical(other.maxConnections, _this.maxConnections) || other.maxConnections == _this.maxConnections)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&const DeepCollectionEquality().equals(other.allowedOutputFormats, _this.allowedOutputFormats)&&(identical(other.serverTimezone, _this.serverTimezone) || other.serverTimezone == _this.serverTimezone)&&(identical(other.serverTime, _this.serverTime) || other.serverTime == _this.serverTime));
}


@override
int get hashCode {
  final _this = this as XtreamAccount;
  return Object.hash(runtimeType,_this.status,_this.expiresAt,_this.isTrial,_this.activeConnections,_this.maxConnections,_this.createdAt,const DeepCollectionEquality().hash(_this.allowedOutputFormats),_this.serverTimezone,_this.serverTime);
}

@override
String toString() {
  final _this = this as XtreamAccount;
  return 'XtreamAccount(status: ${_this.status}, expiresAt: ${_this.expiresAt}, isTrial: ${_this.isTrial}, activeConnections: ${_this.activeConnections}, maxConnections: ${_this.maxConnections}, createdAt: ${_this.createdAt}, allowedOutputFormats: ${_this.allowedOutputFormats}, serverTimezone: ${_this.serverTimezone}, serverTime: ${_this.serverTime})';
}


}

/// @nodoc
abstract mixin class $XtreamAccountCopyWith<$Res>  {
  factory $XtreamAccountCopyWith(XtreamAccount value, $Res Function(XtreamAccount) _then) = _$XtreamAccountCopyWithImpl;
@useResult
$Res call({
 String? status, DateTime? expiresAt, bool isTrial, int? activeConnections, int? maxConnections, DateTime? createdAt, List<String> allowedOutputFormats, String? serverTimezone, DateTime? serverTime
});




}
/// @nodoc
class _$XtreamAccountCopyWithImpl<$Res>
    implements $XtreamAccountCopyWith<$Res> {
  _$XtreamAccountCopyWithImpl(this._self, this._then);

  final XtreamAccount _self;
  final $Res Function(XtreamAccount) _then;

/// Create a copy of XtreamAccount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = freezed,Object? expiresAt = freezed,Object? isTrial = null,Object? activeConnections = freezed,Object? maxConnections = freezed,Object? createdAt = freezed,Object? allowedOutputFormats = null,Object? serverTimezone = freezed,Object? serverTime = freezed,}) {
  return _then(XtreamAccount(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isTrial: null == isTrial ? _self.isTrial : isTrial // ignore: cast_nullable_to_non_nullable
as bool,activeConnections: freezed == activeConnections ? _self.activeConnections : activeConnections // ignore: cast_nullable_to_non_nullable
as int?,maxConnections: freezed == maxConnections ? _self.maxConnections : maxConnections // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,allowedOutputFormats: null == allowedOutputFormats ? _self.allowedOutputFormats : allowedOutputFormats // ignore: cast_nullable_to_non_nullable
as List<String>,serverTimezone: freezed == serverTimezone ? _self.serverTimezone : serverTimezone // ignore: cast_nullable_to_non_nullable
as String?,serverTime: freezed == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamAccount].
extension XtreamAccountPatterns on XtreamAccount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamAccount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamAccount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamAccount value)  $default,){
final _that = this;
switch (_that) {
case _XtreamAccount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamAccount value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamAccount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? status,  DateTime? expiresAt,  bool isTrial,  int? activeConnections,  int? maxConnections,  DateTime? createdAt,  List<String> allowedOutputFormats,  String? serverTimezone,  DateTime? serverTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamAccount() when $default != null:
return $default(_that.status,_that.expiresAt,_that.isTrial,_that.activeConnections,_that.maxConnections,_that.createdAt,_that.allowedOutputFormats,_that.serverTimezone,_that.serverTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? status,  DateTime? expiresAt,  bool isTrial,  int? activeConnections,  int? maxConnections,  DateTime? createdAt,  List<String> allowedOutputFormats,  String? serverTimezone,  DateTime? serverTime)  $default,) {final _that = this;
switch (_that) {
case _XtreamAccount():
return $default(_that.status,_that.expiresAt,_that.isTrial,_that.activeConnections,_that.maxConnections,_that.createdAt,_that.allowedOutputFormats,_that.serverTimezone,_that.serverTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? status,  DateTime? expiresAt,  bool isTrial,  int? activeConnections,  int? maxConnections,  DateTime? createdAt,  List<String> allowedOutputFormats,  String? serverTimezone,  DateTime? serverTime)?  $default,) {final _that = this;
switch (_that) {
case _XtreamAccount() when $default != null:
return $default(_that.status,_that.expiresAt,_that.isTrial,_that.activeConnections,_that.maxConnections,_that.createdAt,_that.allowedOutputFormats,_that.serverTimezone,_that.serverTime);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamAccount implements XtreamAccount {
  const _XtreamAccount({this.status, this.expiresAt, this.isTrial = false, this.activeConnections, this.maxConnections, this.createdAt,  List<String> allowedOutputFormats = const <String>[], this.serverTimezone, this.serverTime}): _allowedOutputFormats = allowedOutputFormats;
  

/// `Active`, `Expired`, `Banned`, `Disabled`, as the panel words it.
@override final  String? status;
/// Null means no expiry (docs/02).
@override final  DateTime? expiresAt;
@override@JsonKey() final  bool isTrial;
@override final  int? activeConnections;
@override final  int? maxConnections;
@override final  DateTime? createdAt;
 final  List<String> _allowedOutputFormats;
@override@JsonKey() List<String> get allowedOutputFormats {
  if (_allowedOutputFormats is EqualUnmodifiableListView) return _allowedOutputFormats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allowedOutputFormats);
}

/// The panel's time zone name, e.g. `Europe/London`.
@override final  String? serverTimezone;
/// The panel's clock when it answered, for spotting a skewed server.
@override final  DateTime? serverTime;

/// Create a copy of XtreamAccount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamAccountCopyWith<_XtreamAccount> get copyWith => __$XtreamAccountCopyWithImpl<_XtreamAccount>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamAccount&&(identical(other.status, status) || other.status == status)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.isTrial, isTrial) || other.isTrial == isTrial)&&(identical(other.activeConnections, activeConnections) || other.activeConnections == activeConnections)&&(identical(other.maxConnections, maxConnections) || other.maxConnections == maxConnections)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.allowedOutputFormats, _allowedOutputFormats)&&(identical(other.serverTimezone, serverTimezone) || other.serverTimezone == serverTimezone)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,expiresAt,isTrial,activeConnections,maxConnections,createdAt,const DeepCollectionEquality().hash(_allowedOutputFormats),serverTimezone,serverTime);
}

@override
String toString() {
    return 'XtreamAccount(status: $status, expiresAt: $expiresAt, isTrial: $isTrial, activeConnections: $activeConnections, maxConnections: $maxConnections, createdAt: $createdAt, allowedOutputFormats: $allowedOutputFormats, serverTimezone: $serverTimezone, serverTime: $serverTime)';
}


}

/// @nodoc
abstract mixin class _$XtreamAccountCopyWith<$Res> implements $XtreamAccountCopyWith<$Res> {
  factory _$XtreamAccountCopyWith(_XtreamAccount value, $Res Function(_XtreamAccount) _then) = __$XtreamAccountCopyWithImpl;
@override @useResult
$Res call({
 String? status, DateTime? expiresAt, bool isTrial, int? activeConnections, int? maxConnections, DateTime? createdAt, List<String> allowedOutputFormats, String? serverTimezone, DateTime? serverTime
});




}
/// @nodoc
class __$XtreamAccountCopyWithImpl<$Res>
    implements _$XtreamAccountCopyWith<$Res> {
  __$XtreamAccountCopyWithImpl(this._self, this._then);

  final _XtreamAccount _self;
  final $Res Function(_XtreamAccount) _then;

/// Create a copy of XtreamAccount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = freezed,Object? expiresAt = freezed,Object? isTrial = null,Object? activeConnections = freezed,Object? maxConnections = freezed,Object? createdAt = freezed,Object? allowedOutputFormats = null,Object? serverTimezone = freezed,Object? serverTime = freezed,}) {
  return _then(_XtreamAccount(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isTrial: null == isTrial ? _self.isTrial : isTrial // ignore: cast_nullable_to_non_nullable
as bool,activeConnections: freezed == activeConnections ? _self.activeConnections : activeConnections // ignore: cast_nullable_to_non_nullable
as int?,maxConnections: freezed == maxConnections ? _self.maxConnections : maxConnections // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,allowedOutputFormats: null == allowedOutputFormats ? _self._allowedOutputFormats : allowedOutputFormats // ignore: cast_nullable_to_non_nullable
as List<String>,serverTimezone: freezed == serverTimezone ? _self.serverTimezone : serverTimezone // ignore: cast_nullable_to_non_nullable
as String?,serverTime: freezed == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$XtreamCategory {

 String get id; String get name;
/// Create a copy of XtreamCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamCategoryCopyWith<XtreamCategory> get copyWith => _$XtreamCategoryCopyWithImpl<XtreamCategory>(this as XtreamCategory, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamCategory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamCategory&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name));
}


@override
int get hashCode {
  final _this = this as XtreamCategory;
  return Object.hash(runtimeType,_this.id,_this.name);
}

@override
String toString() {
  final _this = this as XtreamCategory;
  return 'XtreamCategory(id: ${_this.id}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $XtreamCategoryCopyWith<$Res>  {
  factory $XtreamCategoryCopyWith(XtreamCategory value, $Res Function(XtreamCategory) _then) = _$XtreamCategoryCopyWithImpl;
@useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class _$XtreamCategoryCopyWithImpl<$Res>
    implements $XtreamCategoryCopyWith<$Res> {
  _$XtreamCategoryCopyWithImpl(this._self, this._then);

  final XtreamCategory _self;
  final $Res Function(XtreamCategory) _then;

/// Create a copy of XtreamCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(XtreamCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamCategory].
extension XtreamCategoryPatterns on XtreamCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamCategory value)  $default,){
final _that = this;
switch (_that) {
case _XtreamCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamCategory value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamCategory() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name)  $default,) {final _that = this;
switch (_that) {
case _XtreamCategory():
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _XtreamCategory() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamCategory implements XtreamCategory {
  const _XtreamCategory({required this.id, required this.name});
  

@override final  String id;
@override final  String name;

/// Create a copy of XtreamCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamCategoryCopyWith<_XtreamCategory> get copyWith => __$XtreamCategoryCopyWithImpl<_XtreamCategory>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name);
}

@override
String toString() {
    return 'XtreamCategory(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$XtreamCategoryCopyWith<$Res> implements $XtreamCategoryCopyWith<$Res> {
  factory _$XtreamCategoryCopyWith(_XtreamCategory value, $Res Function(_XtreamCategory) _then) = __$XtreamCategoryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class __$XtreamCategoryCopyWithImpl<$Res>
    implements _$XtreamCategoryCopyWith<$Res> {
  __$XtreamCategoryCopyWithImpl(this._self, this._then);

  final _XtreamCategory _self;
  final $Res Function(_XtreamCategory) _then;

/// Create a copy of XtreamCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_XtreamCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$XtreamChannel {

 String get streamId; String get name; int? get number; String? get iconUrl; String? get epgChannelId;/// As sent: null when missing, possibly pointing at a category the
/// panel doesn't list. The sync files both under "Uncategorized".
 String? get categoryId; int get archiveDays; DateTime? get addedAt;
/// Create a copy of XtreamChannel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamChannelCopyWith<XtreamChannel> get copyWith => _$XtreamChannelCopyWithImpl<XtreamChannel>(this as XtreamChannel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamChannel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamChannel&&(identical(other.streamId, _this.streamId) || other.streamId == _this.streamId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.iconUrl, _this.iconUrl) || other.iconUrl == _this.iconUrl)&&(identical(other.epgChannelId, _this.epgChannelId) || other.epgChannelId == _this.epgChannelId)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.archiveDays, _this.archiveDays) || other.archiveDays == _this.archiveDays)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt));
}


@override
int get hashCode {
  final _this = this as XtreamChannel;
  return Object.hash(runtimeType,_this.streamId,_this.name,_this.number,_this.iconUrl,_this.epgChannelId,_this.categoryId,_this.archiveDays,_this.addedAt);
}

@override
String toString() {
  final _this = this as XtreamChannel;
  return 'XtreamChannel(streamId: ${_this.streamId}, name: ${_this.name}, number: ${_this.number}, iconUrl: ${_this.iconUrl}, epgChannelId: ${_this.epgChannelId}, categoryId: ${_this.categoryId}, archiveDays: ${_this.archiveDays}, addedAt: ${_this.addedAt})';
}


}

/// @nodoc
abstract mixin class $XtreamChannelCopyWith<$Res>  {
  factory $XtreamChannelCopyWith(XtreamChannel value, $Res Function(XtreamChannel) _then) = _$XtreamChannelCopyWithImpl;
@useResult
$Res call({
 String streamId, String name, int? number, String? iconUrl, String? epgChannelId, String? categoryId, int archiveDays, DateTime? addedAt
});




}
/// @nodoc
class _$XtreamChannelCopyWithImpl<$Res>
    implements $XtreamChannelCopyWith<$Res> {
  _$XtreamChannelCopyWithImpl(this._self, this._then);

  final XtreamChannel _self;
  final $Res Function(XtreamChannel) _then;

/// Create a copy of XtreamChannel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? streamId = null,Object? name = null,Object? number = freezed,Object? iconUrl = freezed,Object? epgChannelId = freezed,Object? categoryId = freezed,Object? archiveDays = null,Object? addedAt = freezed,}) {
  return _then(XtreamChannel(
streamId: null == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,epgChannelId: freezed == epgChannelId ? _self.epgChannelId : epgChannelId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,archiveDays: null == archiveDays ? _self.archiveDays : archiveDays // ignore: cast_nullable_to_non_nullable
as int,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamChannel].
extension XtreamChannelPatterns on XtreamChannel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamChannel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamChannel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamChannel value)  $default,){
final _that = this;
switch (_that) {
case _XtreamChannel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamChannel value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamChannel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String streamId,  String name,  int? number,  String? iconUrl,  String? epgChannelId,  String? categoryId,  int archiveDays,  DateTime? addedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamChannel() when $default != null:
return $default(_that.streamId,_that.name,_that.number,_that.iconUrl,_that.epgChannelId,_that.categoryId,_that.archiveDays,_that.addedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String streamId,  String name,  int? number,  String? iconUrl,  String? epgChannelId,  String? categoryId,  int archiveDays,  DateTime? addedAt)  $default,) {final _that = this;
switch (_that) {
case _XtreamChannel():
return $default(_that.streamId,_that.name,_that.number,_that.iconUrl,_that.epgChannelId,_that.categoryId,_that.archiveDays,_that.addedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String streamId,  String name,  int? number,  String? iconUrl,  String? epgChannelId,  String? categoryId,  int archiveDays,  DateTime? addedAt)?  $default,) {final _that = this;
switch (_that) {
case _XtreamChannel() when $default != null:
return $default(_that.streamId,_that.name,_that.number,_that.iconUrl,_that.epgChannelId,_that.categoryId,_that.archiveDays,_that.addedAt);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamChannel implements XtreamChannel {
  const _XtreamChannel({required this.streamId, required this.name, this.number, this.iconUrl, this.epgChannelId, this.categoryId, this.archiveDays = 0, this.addedAt});
  

@override final  String streamId;
@override final  String name;
@override final  int? number;
@override final  String? iconUrl;
@override final  String? epgChannelId;
/// As sent: null when missing, possibly pointing at a category the
/// panel doesn't list. The sync files both under "Uncategorized".
@override final  String? categoryId;
@override@JsonKey() final  int archiveDays;
@override final  DateTime? addedAt;

/// Create a copy of XtreamChannel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamChannelCopyWith<_XtreamChannel> get copyWith => __$XtreamChannelCopyWithImpl<_XtreamChannel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamChannel&&(identical(other.streamId, streamId) || other.streamId == streamId)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.epgChannelId, epgChannelId) || other.epgChannelId == epgChannelId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.archiveDays, archiveDays) || other.archiveDays == archiveDays)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,streamId,name,number,iconUrl,epgChannelId,categoryId,archiveDays,addedAt);
}

@override
String toString() {
    return 'XtreamChannel(streamId: $streamId, name: $name, number: $number, iconUrl: $iconUrl, epgChannelId: $epgChannelId, categoryId: $categoryId, archiveDays: $archiveDays, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class _$XtreamChannelCopyWith<$Res> implements $XtreamChannelCopyWith<$Res> {
  factory _$XtreamChannelCopyWith(_XtreamChannel value, $Res Function(_XtreamChannel) _then) = __$XtreamChannelCopyWithImpl;
@override @useResult
$Res call({
 String streamId, String name, int? number, String? iconUrl, String? epgChannelId, String? categoryId, int archiveDays, DateTime? addedAt
});




}
/// @nodoc
class __$XtreamChannelCopyWithImpl<$Res>
    implements _$XtreamChannelCopyWith<$Res> {
  __$XtreamChannelCopyWithImpl(this._self, this._then);

  final _XtreamChannel _self;
  final $Res Function(_XtreamChannel) _then;

/// Create a copy of XtreamChannel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? streamId = null,Object? name = null,Object? number = freezed,Object? iconUrl = freezed,Object? epgChannelId = freezed,Object? categoryId = freezed,Object? archiveDays = null,Object? addedAt = freezed,}) {
  return _then(_XtreamChannel(
streamId: null == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,epgChannelId: freezed == epgChannelId ? _self.epgChannelId : epgChannelId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,archiveDays: null == archiveDays ? _self.archiveDays : archiveDays // ignore: cast_nullable_to_non_nullable
as int,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$XtreamMovie {

 String get streamId; String get name; int? get number; String? get posterUrl;/// Out of 10; null when unrated (panels send 0 or `""`).
 double? get rating; int? get year;/// The container extension the stream URL needs, e.g. `mkv`.
 String? get ext; String? get categoryId; DateTime? get addedAt;
/// Create a copy of XtreamMovie
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamMovieCopyWith<XtreamMovie> get copyWith => _$XtreamMovieCopyWithImpl<XtreamMovie>(this as XtreamMovie, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamMovie;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamMovie&&(identical(other.streamId, _this.streamId) || other.streamId == _this.streamId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.posterUrl, _this.posterUrl) || other.posterUrl == _this.posterUrl)&&(identical(other.rating, _this.rating) || other.rating == _this.rating)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.ext, _this.ext) || other.ext == _this.ext)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt));
}


@override
int get hashCode {
  final _this = this as XtreamMovie;
  return Object.hash(runtimeType,_this.streamId,_this.name,_this.number,_this.posterUrl,_this.rating,_this.year,_this.ext,_this.categoryId,_this.addedAt);
}

@override
String toString() {
  final _this = this as XtreamMovie;
  return 'XtreamMovie(streamId: ${_this.streamId}, name: ${_this.name}, number: ${_this.number}, posterUrl: ${_this.posterUrl}, rating: ${_this.rating}, year: ${_this.year}, ext: ${_this.ext}, categoryId: ${_this.categoryId}, addedAt: ${_this.addedAt})';
}


}

/// @nodoc
abstract mixin class $XtreamMovieCopyWith<$Res>  {
  factory $XtreamMovieCopyWith(XtreamMovie value, $Res Function(XtreamMovie) _then) = _$XtreamMovieCopyWithImpl;
@useResult
$Res call({
 String streamId, String name, int? number, String? posterUrl, double? rating, int? year, String? ext, String? categoryId, DateTime? addedAt
});




}
/// @nodoc
class _$XtreamMovieCopyWithImpl<$Res>
    implements $XtreamMovieCopyWith<$Res> {
  _$XtreamMovieCopyWithImpl(this._self, this._then);

  final XtreamMovie _self;
  final $Res Function(XtreamMovie) _then;

/// Create a copy of XtreamMovie
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? streamId = null,Object? name = null,Object? number = freezed,Object? posterUrl = freezed,Object? rating = freezed,Object? year = freezed,Object? ext = freezed,Object? categoryId = freezed,Object? addedAt = freezed,}) {
  return _then(XtreamMovie(
streamId: null == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamMovie].
extension XtreamMoviePatterns on XtreamMovie {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamMovie value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamMovie() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamMovie value)  $default,){
final _that = this;
switch (_that) {
case _XtreamMovie():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamMovie value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamMovie() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String streamId,  String name,  int? number,  String? posterUrl,  double? rating,  int? year,  String? ext,  String? categoryId,  DateTime? addedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamMovie() when $default != null:
return $default(_that.streamId,_that.name,_that.number,_that.posterUrl,_that.rating,_that.year,_that.ext,_that.categoryId,_that.addedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String streamId,  String name,  int? number,  String? posterUrl,  double? rating,  int? year,  String? ext,  String? categoryId,  DateTime? addedAt)  $default,) {final _that = this;
switch (_that) {
case _XtreamMovie():
return $default(_that.streamId,_that.name,_that.number,_that.posterUrl,_that.rating,_that.year,_that.ext,_that.categoryId,_that.addedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String streamId,  String name,  int? number,  String? posterUrl,  double? rating,  int? year,  String? ext,  String? categoryId,  DateTime? addedAt)?  $default,) {final _that = this;
switch (_that) {
case _XtreamMovie() when $default != null:
return $default(_that.streamId,_that.name,_that.number,_that.posterUrl,_that.rating,_that.year,_that.ext,_that.categoryId,_that.addedAt);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamMovie implements XtreamMovie {
  const _XtreamMovie({required this.streamId, required this.name, this.number, this.posterUrl, this.rating, this.year, this.ext, this.categoryId, this.addedAt});
  

@override final  String streamId;
@override final  String name;
@override final  int? number;
@override final  String? posterUrl;
/// Out of 10; null when unrated (panels send 0 or `""`).
@override final  double? rating;
@override final  int? year;
/// The container extension the stream URL needs, e.g. `mkv`.
@override final  String? ext;
@override final  String? categoryId;
@override final  DateTime? addedAt;

/// Create a copy of XtreamMovie
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamMovieCopyWith<_XtreamMovie> get copyWith => __$XtreamMovieCopyWithImpl<_XtreamMovie>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamMovie&&(identical(other.streamId, streamId) || other.streamId == streamId)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.year, year) || other.year == year)&&(identical(other.ext, ext) || other.ext == ext)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,streamId,name,number,posterUrl,rating,year,ext,categoryId,addedAt);
}

@override
String toString() {
    return 'XtreamMovie(streamId: $streamId, name: $name, number: $number, posterUrl: $posterUrl, rating: $rating, year: $year, ext: $ext, categoryId: $categoryId, addedAt: $addedAt)';
}


}

/// @nodoc
abstract mixin class _$XtreamMovieCopyWith<$Res> implements $XtreamMovieCopyWith<$Res> {
  factory _$XtreamMovieCopyWith(_XtreamMovie value, $Res Function(_XtreamMovie) _then) = __$XtreamMovieCopyWithImpl;
@override @useResult
$Res call({
 String streamId, String name, int? number, String? posterUrl, double? rating, int? year, String? ext, String? categoryId, DateTime? addedAt
});




}
/// @nodoc
class __$XtreamMovieCopyWithImpl<$Res>
    implements _$XtreamMovieCopyWith<$Res> {
  __$XtreamMovieCopyWithImpl(this._self, this._then);

  final _XtreamMovie _self;
  final $Res Function(_XtreamMovie) _then;

/// Create a copy of XtreamMovie
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? streamId = null,Object? name = null,Object? number = freezed,Object? posterUrl = freezed,Object? rating = freezed,Object? year = freezed,Object? ext = freezed,Object? categoryId = freezed,Object? addedAt = freezed,}) {
  return _then(_XtreamMovie(
streamId: null == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$XtreamSeries {

 String get seriesId; String get name; int? get number; String? get posterUrl; double? get rating; int? get year; String? get plot; String? get genre; String? get categoryId;/// `last_modified`: when it changes, fetched episodes are stale.
 DateTime? get lastModified;
/// Create a copy of XtreamSeries
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamSeriesCopyWith<XtreamSeries> get copyWith => _$XtreamSeriesCopyWithImpl<XtreamSeries>(this as XtreamSeries, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamSeries;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamSeries&&(identical(other.seriesId, _this.seriesId) || other.seriesId == _this.seriesId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.posterUrl, _this.posterUrl) || other.posterUrl == _this.posterUrl)&&(identical(other.rating, _this.rating) || other.rating == _this.rating)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.plot, _this.plot) || other.plot == _this.plot)&&(identical(other.genre, _this.genre) || other.genre == _this.genre)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.lastModified, _this.lastModified) || other.lastModified == _this.lastModified));
}


@override
int get hashCode {
  final _this = this as XtreamSeries;
  return Object.hash(runtimeType,_this.seriesId,_this.name,_this.number,_this.posterUrl,_this.rating,_this.year,_this.plot,_this.genre,_this.categoryId,_this.lastModified);
}

@override
String toString() {
  final _this = this as XtreamSeries;
  return 'XtreamSeries(seriesId: ${_this.seriesId}, name: ${_this.name}, number: ${_this.number}, posterUrl: ${_this.posterUrl}, rating: ${_this.rating}, year: ${_this.year}, plot: ${_this.plot}, genre: ${_this.genre}, categoryId: ${_this.categoryId}, lastModified: ${_this.lastModified})';
}


}

/// @nodoc
abstract mixin class $XtreamSeriesCopyWith<$Res>  {
  factory $XtreamSeriesCopyWith(XtreamSeries value, $Res Function(XtreamSeries) _then) = _$XtreamSeriesCopyWithImpl;
@useResult
$Res call({
 String seriesId, String name, int? number, String? posterUrl, double? rating, int? year, String? plot, String? genre, String? categoryId, DateTime? lastModified
});




}
/// @nodoc
class _$XtreamSeriesCopyWithImpl<$Res>
    implements $XtreamSeriesCopyWith<$Res> {
  _$XtreamSeriesCopyWithImpl(this._self, this._then);

  final XtreamSeries _self;
  final $Res Function(XtreamSeries) _then;

/// Create a copy of XtreamSeries
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seriesId = null,Object? name = null,Object? number = freezed,Object? posterUrl = freezed,Object? rating = freezed,Object? year = freezed,Object? plot = freezed,Object? genre = freezed,Object? categoryId = freezed,Object? lastModified = freezed,}) {
  return _then(XtreamSeries(
seriesId: null == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamSeries].
extension XtreamSeriesPatterns on XtreamSeries {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamSeries value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamSeries() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamSeries value)  $default,){
final _that = this;
switch (_that) {
case _XtreamSeries():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamSeries value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamSeries() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String seriesId,  String name,  int? number,  String? posterUrl,  double? rating,  int? year,  String? plot,  String? genre,  String? categoryId,  DateTime? lastModified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamSeries() when $default != null:
return $default(_that.seriesId,_that.name,_that.number,_that.posterUrl,_that.rating,_that.year,_that.plot,_that.genre,_that.categoryId,_that.lastModified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String seriesId,  String name,  int? number,  String? posterUrl,  double? rating,  int? year,  String? plot,  String? genre,  String? categoryId,  DateTime? lastModified)  $default,) {final _that = this;
switch (_that) {
case _XtreamSeries():
return $default(_that.seriesId,_that.name,_that.number,_that.posterUrl,_that.rating,_that.year,_that.plot,_that.genre,_that.categoryId,_that.lastModified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String seriesId,  String name,  int? number,  String? posterUrl,  double? rating,  int? year,  String? plot,  String? genre,  String? categoryId,  DateTime? lastModified)?  $default,) {final _that = this;
switch (_that) {
case _XtreamSeries() when $default != null:
return $default(_that.seriesId,_that.name,_that.number,_that.posterUrl,_that.rating,_that.year,_that.plot,_that.genre,_that.categoryId,_that.lastModified);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamSeries implements XtreamSeries {
  const _XtreamSeries({required this.seriesId, required this.name, this.number, this.posterUrl, this.rating, this.year, this.plot, this.genre, this.categoryId, this.lastModified});
  

@override final  String seriesId;
@override final  String name;
@override final  int? number;
@override final  String? posterUrl;
@override final  double? rating;
@override final  int? year;
@override final  String? plot;
@override final  String? genre;
@override final  String? categoryId;
/// `last_modified`: when it changes, fetched episodes are stale.
@override final  DateTime? lastModified;

/// Create a copy of XtreamSeries
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamSeriesCopyWith<_XtreamSeries> get copyWith => __$XtreamSeriesCopyWithImpl<_XtreamSeries>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamSeries&&(identical(other.seriesId, seriesId) || other.seriesId == seriesId)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.year, year) || other.year == year)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}


@override
int get hashCode {
    return Object.hash(runtimeType,seriesId,name,number,posterUrl,rating,year,plot,genre,categoryId,lastModified);
}

@override
String toString() {
    return 'XtreamSeries(seriesId: $seriesId, name: $name, number: $number, posterUrl: $posterUrl, rating: $rating, year: $year, plot: $plot, genre: $genre, categoryId: $categoryId, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class _$XtreamSeriesCopyWith<$Res> implements $XtreamSeriesCopyWith<$Res> {
  factory _$XtreamSeriesCopyWith(_XtreamSeries value, $Res Function(_XtreamSeries) _then) = __$XtreamSeriesCopyWithImpl;
@override @useResult
$Res call({
 String seriesId, String name, int? number, String? posterUrl, double? rating, int? year, String? plot, String? genre, String? categoryId, DateTime? lastModified
});




}
/// @nodoc
class __$XtreamSeriesCopyWithImpl<$Res>
    implements _$XtreamSeriesCopyWith<$Res> {
  __$XtreamSeriesCopyWithImpl(this._self, this._then);

  final _XtreamSeries _self;
  final $Res Function(_XtreamSeries) _then;

/// Create a copy of XtreamSeries
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seriesId = null,Object? name = null,Object? number = freezed,Object? posterUrl = freezed,Object? rating = freezed,Object? year = freezed,Object? plot = freezed,Object? genre = freezed,Object? categoryId = freezed,Object? lastModified = freezed,}) {
  return _then(_XtreamSeries(
seriesId: null == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$XtreamMovieInfo {

 String? get plot; String? get cast; String? get director; String? get genre; int? get runtimeMinutes; String? get backdropUrl; String? get posterUrl; int? get year; double? get rating; String? get ext;
/// Create a copy of XtreamMovieInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamMovieInfoCopyWith<XtreamMovieInfo> get copyWith => _$XtreamMovieInfoCopyWithImpl<XtreamMovieInfo>(this as XtreamMovieInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamMovieInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamMovieInfo&&(identical(other.plot, _this.plot) || other.plot == _this.plot)&&(identical(other.cast, _this.cast) || other.cast == _this.cast)&&(identical(other.director, _this.director) || other.director == _this.director)&&(identical(other.genre, _this.genre) || other.genre == _this.genre)&&(identical(other.runtimeMinutes, _this.runtimeMinutes) || other.runtimeMinutes == _this.runtimeMinutes)&&(identical(other.backdropUrl, _this.backdropUrl) || other.backdropUrl == _this.backdropUrl)&&(identical(other.posterUrl, _this.posterUrl) || other.posterUrl == _this.posterUrl)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.rating, _this.rating) || other.rating == _this.rating)&&(identical(other.ext, _this.ext) || other.ext == _this.ext));
}


@override
int get hashCode {
  final _this = this as XtreamMovieInfo;
  return Object.hash(runtimeType,_this.plot,_this.cast,_this.director,_this.genre,_this.runtimeMinutes,_this.backdropUrl,_this.posterUrl,_this.year,_this.rating,_this.ext);
}

@override
String toString() {
  final _this = this as XtreamMovieInfo;
  return 'XtreamMovieInfo(plot: ${_this.plot}, cast: ${_this.cast}, director: ${_this.director}, genre: ${_this.genre}, runtimeMinutes: ${_this.runtimeMinutes}, backdropUrl: ${_this.backdropUrl}, posterUrl: ${_this.posterUrl}, year: ${_this.year}, rating: ${_this.rating}, ext: ${_this.ext})';
}


}

/// @nodoc
abstract mixin class $XtreamMovieInfoCopyWith<$Res>  {
  factory $XtreamMovieInfoCopyWith(XtreamMovieInfo value, $Res Function(XtreamMovieInfo) _then) = _$XtreamMovieInfoCopyWithImpl;
@useResult
$Res call({
 String? plot, String? cast, String? director, String? genre, int? runtimeMinutes, String? backdropUrl, String? posterUrl, int? year, double? rating, String? ext
});




}
/// @nodoc
class _$XtreamMovieInfoCopyWithImpl<$Res>
    implements $XtreamMovieInfoCopyWith<$Res> {
  _$XtreamMovieInfoCopyWithImpl(this._self, this._then);

  final XtreamMovieInfo _self;
  final $Res Function(XtreamMovieInfo) _then;

/// Create a copy of XtreamMovieInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? plot = freezed,Object? cast = freezed,Object? director = freezed,Object? genre = freezed,Object? runtimeMinutes = freezed,Object? backdropUrl = freezed,Object? posterUrl = freezed,Object? year = freezed,Object? rating = freezed,Object? ext = freezed,}) {
  return _then(XtreamMovieInfo(
plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,cast: freezed == cast ? _self.cast : cast // ignore: cast_nullable_to_non_nullable
as String?,director: freezed == director ? _self.director : director // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,runtimeMinutes: freezed == runtimeMinutes ? _self.runtimeMinutes : runtimeMinutes // ignore: cast_nullable_to_non_nullable
as int?,backdropUrl: freezed == backdropUrl ? _self.backdropUrl : backdropUrl // ignore: cast_nullable_to_non_nullable
as String?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamMovieInfo].
extension XtreamMovieInfoPatterns on XtreamMovieInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamMovieInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamMovieInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamMovieInfo value)  $default,){
final _that = this;
switch (_that) {
case _XtreamMovieInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamMovieInfo value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamMovieInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? plot,  String? cast,  String? director,  String? genre,  int? runtimeMinutes,  String? backdropUrl,  String? posterUrl,  int? year,  double? rating,  String? ext)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamMovieInfo() when $default != null:
return $default(_that.plot,_that.cast,_that.director,_that.genre,_that.runtimeMinutes,_that.backdropUrl,_that.posterUrl,_that.year,_that.rating,_that.ext);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? plot,  String? cast,  String? director,  String? genre,  int? runtimeMinutes,  String? backdropUrl,  String? posterUrl,  int? year,  double? rating,  String? ext)  $default,) {final _that = this;
switch (_that) {
case _XtreamMovieInfo():
return $default(_that.plot,_that.cast,_that.director,_that.genre,_that.runtimeMinutes,_that.backdropUrl,_that.posterUrl,_that.year,_that.rating,_that.ext);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? plot,  String? cast,  String? director,  String? genre,  int? runtimeMinutes,  String? backdropUrl,  String? posterUrl,  int? year,  double? rating,  String? ext)?  $default,) {final _that = this;
switch (_that) {
case _XtreamMovieInfo() when $default != null:
return $default(_that.plot,_that.cast,_that.director,_that.genre,_that.runtimeMinutes,_that.backdropUrl,_that.posterUrl,_that.year,_that.rating,_that.ext);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamMovieInfo implements XtreamMovieInfo {
  const _XtreamMovieInfo({this.plot, this.cast, this.director, this.genre, this.runtimeMinutes, this.backdropUrl, this.posterUrl, this.year, this.rating, this.ext});
  

@override final  String? plot;
@override final  String? cast;
@override final  String? director;
@override final  String? genre;
@override final  int? runtimeMinutes;
@override final  String? backdropUrl;
@override final  String? posterUrl;
@override final  int? year;
@override final  double? rating;
@override final  String? ext;

/// Create a copy of XtreamMovieInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamMovieInfoCopyWith<_XtreamMovieInfo> get copyWith => __$XtreamMovieInfoCopyWithImpl<_XtreamMovieInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamMovieInfo&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.cast, cast) || other.cast == cast)&&(identical(other.director, director) || other.director == director)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.runtimeMinutes, runtimeMinutes) || other.runtimeMinutes == runtimeMinutes)&&(identical(other.backdropUrl, backdropUrl) || other.backdropUrl == backdropUrl)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.year, year) || other.year == year)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.ext, ext) || other.ext == ext));
}


@override
int get hashCode {
    return Object.hash(runtimeType,plot,cast,director,genre,runtimeMinutes,backdropUrl,posterUrl,year,rating,ext);
}

@override
String toString() {
    return 'XtreamMovieInfo(plot: $plot, cast: $cast, director: $director, genre: $genre, runtimeMinutes: $runtimeMinutes, backdropUrl: $backdropUrl, posterUrl: $posterUrl, year: $year, rating: $rating, ext: $ext)';
}


}

/// @nodoc
abstract mixin class _$XtreamMovieInfoCopyWith<$Res> implements $XtreamMovieInfoCopyWith<$Res> {
  factory _$XtreamMovieInfoCopyWith(_XtreamMovieInfo value, $Res Function(_XtreamMovieInfo) _then) = __$XtreamMovieInfoCopyWithImpl;
@override @useResult
$Res call({
 String? plot, String? cast, String? director, String? genre, int? runtimeMinutes, String? backdropUrl, String? posterUrl, int? year, double? rating, String? ext
});




}
/// @nodoc
class __$XtreamMovieInfoCopyWithImpl<$Res>
    implements _$XtreamMovieInfoCopyWith<$Res> {
  __$XtreamMovieInfoCopyWithImpl(this._self, this._then);

  final _XtreamMovieInfo _self;
  final $Res Function(_XtreamMovieInfo) _then;

/// Create a copy of XtreamMovieInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? plot = freezed,Object? cast = freezed,Object? director = freezed,Object? genre = freezed,Object? runtimeMinutes = freezed,Object? backdropUrl = freezed,Object? posterUrl = freezed,Object? year = freezed,Object? rating = freezed,Object? ext = freezed,}) {
  return _then(_XtreamMovieInfo(
plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,cast: freezed == cast ? _self.cast : cast // ignore: cast_nullable_to_non_nullable
as String?,director: freezed == director ? _self.director : director // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,runtimeMinutes: freezed == runtimeMinutes ? _self.runtimeMinutes : runtimeMinutes // ignore: cast_nullable_to_non_nullable
as int?,backdropUrl: freezed == backdropUrl ? _self.backdropUrl : backdropUrl // ignore: cast_nullable_to_non_nullable
as String?,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$XtreamEpisode {

 String get id; int get season; int get episode; String get title; String? get ext; int? get durationSeconds; String? get plot; String? get stillUrl;
/// Create a copy of XtreamEpisode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamEpisodeCopyWith<XtreamEpisode> get copyWith => _$XtreamEpisodeCopyWithImpl<XtreamEpisode>(this as XtreamEpisode, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamEpisode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamEpisode&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.season, _this.season) || other.season == _this.season)&&(identical(other.episode, _this.episode) || other.episode == _this.episode)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.ext, _this.ext) || other.ext == _this.ext)&&(identical(other.durationSeconds, _this.durationSeconds) || other.durationSeconds == _this.durationSeconds)&&(identical(other.plot, _this.plot) || other.plot == _this.plot)&&(identical(other.stillUrl, _this.stillUrl) || other.stillUrl == _this.stillUrl));
}


@override
int get hashCode {
  final _this = this as XtreamEpisode;
  return Object.hash(runtimeType,_this.id,_this.season,_this.episode,_this.title,_this.ext,_this.durationSeconds,_this.plot,_this.stillUrl);
}

@override
String toString() {
  final _this = this as XtreamEpisode;
  return 'XtreamEpisode(id: ${_this.id}, season: ${_this.season}, episode: ${_this.episode}, title: ${_this.title}, ext: ${_this.ext}, durationSeconds: ${_this.durationSeconds}, plot: ${_this.plot}, stillUrl: ${_this.stillUrl})';
}


}

/// @nodoc
abstract mixin class $XtreamEpisodeCopyWith<$Res>  {
  factory $XtreamEpisodeCopyWith(XtreamEpisode value, $Res Function(XtreamEpisode) _then) = _$XtreamEpisodeCopyWithImpl;
@useResult
$Res call({
 String id, int season, int episode, String title, String? ext, int? durationSeconds, String? plot, String? stillUrl
});




}
/// @nodoc
class _$XtreamEpisodeCopyWithImpl<$Res>
    implements $XtreamEpisodeCopyWith<$Res> {
  _$XtreamEpisodeCopyWithImpl(this._self, this._then);

  final XtreamEpisode _self;
  final $Res Function(XtreamEpisode) _then;

/// Create a copy of XtreamEpisode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? season = null,Object? episode = null,Object? title = null,Object? ext = freezed,Object? durationSeconds = freezed,Object? plot = freezed,Object? stillUrl = freezed,}) {
  return _then(XtreamEpisode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,season: null == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int,episode: null == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,stillUrl: freezed == stillUrl ? _self.stillUrl : stillUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamEpisode].
extension XtreamEpisodePatterns on XtreamEpisode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamEpisode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamEpisode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamEpisode value)  $default,){
final _that = this;
switch (_that) {
case _XtreamEpisode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamEpisode value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamEpisode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int season,  int episode,  String title,  String? ext,  int? durationSeconds,  String? plot,  String? stillUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamEpisode() when $default != null:
return $default(_that.id,_that.season,_that.episode,_that.title,_that.ext,_that.durationSeconds,_that.plot,_that.stillUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int season,  int episode,  String title,  String? ext,  int? durationSeconds,  String? plot,  String? stillUrl)  $default,) {final _that = this;
switch (_that) {
case _XtreamEpisode():
return $default(_that.id,_that.season,_that.episode,_that.title,_that.ext,_that.durationSeconds,_that.plot,_that.stillUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int season,  int episode,  String title,  String? ext,  int? durationSeconds,  String? plot,  String? stillUrl)?  $default,) {final _that = this;
switch (_that) {
case _XtreamEpisode() when $default != null:
return $default(_that.id,_that.season,_that.episode,_that.title,_that.ext,_that.durationSeconds,_that.plot,_that.stillUrl);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamEpisode implements XtreamEpisode {
  const _XtreamEpisode({required this.id, required this.season, required this.episode, required this.title, this.ext, this.durationSeconds, this.plot, this.stillUrl});
  

@override final  String id;
@override final  int season;
@override final  int episode;
@override final  String title;
@override final  String? ext;
@override final  int? durationSeconds;
@override final  String? plot;
@override final  String? stillUrl;

/// Create a copy of XtreamEpisode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamEpisodeCopyWith<_XtreamEpisode> get copyWith => __$XtreamEpisodeCopyWithImpl<_XtreamEpisode>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamEpisode&&(identical(other.id, id) || other.id == id)&&(identical(other.season, season) || other.season == season)&&(identical(other.episode, episode) || other.episode == episode)&&(identical(other.title, title) || other.title == title)&&(identical(other.ext, ext) || other.ext == ext)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.stillUrl, stillUrl) || other.stillUrl == stillUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,season,episode,title,ext,durationSeconds,plot,stillUrl);
}

@override
String toString() {
    return 'XtreamEpisode(id: $id, season: $season, episode: $episode, title: $title, ext: $ext, durationSeconds: $durationSeconds, plot: $plot, stillUrl: $stillUrl)';
}


}

/// @nodoc
abstract mixin class _$XtreamEpisodeCopyWith<$Res> implements $XtreamEpisodeCopyWith<$Res> {
  factory _$XtreamEpisodeCopyWith(_XtreamEpisode value, $Res Function(_XtreamEpisode) _then) = __$XtreamEpisodeCopyWithImpl;
@override @useResult
$Res call({
 String id, int season, int episode, String title, String? ext, int? durationSeconds, String? plot, String? stillUrl
});




}
/// @nodoc
class __$XtreamEpisodeCopyWithImpl<$Res>
    implements _$XtreamEpisodeCopyWith<$Res> {
  __$XtreamEpisodeCopyWithImpl(this._self, this._then);

  final _XtreamEpisode _self;
  final $Res Function(_XtreamEpisode) _then;

/// Create a copy of XtreamEpisode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? season = null,Object? episode = null,Object? title = null,Object? ext = freezed,Object? durationSeconds = freezed,Object? plot = freezed,Object? stillUrl = freezed,}) {
  return _then(_XtreamEpisode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,season: null == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int,episode: null == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,stillUrl: freezed == stillUrl ? _self.stillUrl : stillUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$XtreamSeriesInfo {

 List<XtreamEpisode> get episodes; int get skipped;
/// Create a copy of XtreamSeriesInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamSeriesInfoCopyWith<XtreamSeriesInfo> get copyWith => _$XtreamSeriesInfoCopyWithImpl<XtreamSeriesInfo>(this as XtreamSeriesInfo, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamSeriesInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamSeriesInfo&&const DeepCollectionEquality().equals(other.episodes, _this.episodes)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped));
}


@override
int get hashCode {
  final _this = this as XtreamSeriesInfo;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.episodes),_this.skipped);
}

@override
String toString() {
  final _this = this as XtreamSeriesInfo;
  return 'XtreamSeriesInfo(episodes: ${_this.episodes}, skipped: ${_this.skipped})';
}


}

/// @nodoc
abstract mixin class $XtreamSeriesInfoCopyWith<$Res>  {
  factory $XtreamSeriesInfoCopyWith(XtreamSeriesInfo value, $Res Function(XtreamSeriesInfo) _then) = _$XtreamSeriesInfoCopyWithImpl;
@useResult
$Res call({
 List<XtreamEpisode> episodes, int skipped
});




}
/// @nodoc
class _$XtreamSeriesInfoCopyWithImpl<$Res>
    implements $XtreamSeriesInfoCopyWith<$Res> {
  _$XtreamSeriesInfoCopyWithImpl(this._self, this._then);

  final XtreamSeriesInfo _self;
  final $Res Function(XtreamSeriesInfo) _then;

/// Create a copy of XtreamSeriesInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? episodes = null,Object? skipped = null,}) {
  return _then(XtreamSeriesInfo(
episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as List<XtreamEpisode>,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamSeriesInfo].
extension XtreamSeriesInfoPatterns on XtreamSeriesInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamSeriesInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamSeriesInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamSeriesInfo value)  $default,){
final _that = this;
switch (_that) {
case _XtreamSeriesInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamSeriesInfo value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamSeriesInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<XtreamEpisode> episodes,  int skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamSeriesInfo() when $default != null:
return $default(_that.episodes,_that.skipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<XtreamEpisode> episodes,  int skipped)  $default,) {final _that = this;
switch (_that) {
case _XtreamSeriesInfo():
return $default(_that.episodes,_that.skipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<XtreamEpisode> episodes,  int skipped)?  $default,) {final _that = this;
switch (_that) {
case _XtreamSeriesInfo() when $default != null:
return $default(_that.episodes,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamSeriesInfo implements XtreamSeriesInfo {
  const _XtreamSeriesInfo({ List<XtreamEpisode> episodes = const <XtreamEpisode>[], this.skipped = 0}): _episodes = episodes;
  

 final  List<XtreamEpisode> _episodes;
@override@JsonKey() List<XtreamEpisode> get episodes {
  if (_episodes is EqualUnmodifiableListView) return _episodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_episodes);
}

@override@JsonKey() final  int skipped;

/// Create a copy of XtreamSeriesInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamSeriesInfoCopyWith<_XtreamSeriesInfo> get copyWith => __$XtreamSeriesInfoCopyWithImpl<_XtreamSeriesInfo>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamSeriesInfo&&const DeepCollectionEquality().equals(other.episodes, _episodes)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_episodes),skipped);
}

@override
String toString() {
    return 'XtreamSeriesInfo(episodes: $episodes, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$XtreamSeriesInfoCopyWith<$Res> implements $XtreamSeriesInfoCopyWith<$Res> {
  factory _$XtreamSeriesInfoCopyWith(_XtreamSeriesInfo value, $Res Function(_XtreamSeriesInfo) _then) = __$XtreamSeriesInfoCopyWithImpl;
@override @useResult
$Res call({
 List<XtreamEpisode> episodes, int skipped
});




}
/// @nodoc
class __$XtreamSeriesInfoCopyWithImpl<$Res>
    implements _$XtreamSeriesInfoCopyWith<$Res> {
  __$XtreamSeriesInfoCopyWithImpl(this._self, this._then);

  final _XtreamSeriesInfo _self;
  final $Res Function(_XtreamSeriesInfo) _then;

/// Create a copy of XtreamSeriesInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? episodes = null,Object? skipped = null,}) {
  return _then(_XtreamSeriesInfo(
episodes: null == episodes ? _self._episodes : episodes // ignore: cast_nullable_to_non_nullable
as List<XtreamEpisode>,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$XtreamEpgEntry {

 String get title; DateTime get start; DateTime get end; String? get description;
/// Create a copy of XtreamEpgEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$XtreamEpgEntryCopyWith<XtreamEpgEntry> get copyWith => _$XtreamEpgEntryCopyWithImpl<XtreamEpgEntry>(this as XtreamEpgEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as XtreamEpgEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is XtreamEpgEntry&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.description, _this.description) || other.description == _this.description));
}


@override
int get hashCode {
  final _this = this as XtreamEpgEntry;
  return Object.hash(runtimeType,_this.title,_this.start,_this.end,_this.description);
}

@override
String toString() {
  final _this = this as XtreamEpgEntry;
  return 'XtreamEpgEntry(title: ${_this.title}, start: ${_this.start}, end: ${_this.end}, description: ${_this.description})';
}


}

/// @nodoc
abstract mixin class $XtreamEpgEntryCopyWith<$Res>  {
  factory $XtreamEpgEntryCopyWith(XtreamEpgEntry value, $Res Function(XtreamEpgEntry) _then) = _$XtreamEpgEntryCopyWithImpl;
@useResult
$Res call({
 String title, DateTime start, DateTime end, String? description
});




}
/// @nodoc
class _$XtreamEpgEntryCopyWithImpl<$Res>
    implements $XtreamEpgEntryCopyWith<$Res> {
  _$XtreamEpgEntryCopyWithImpl(this._self, this._then);

  final XtreamEpgEntry _self;
  final $Res Function(XtreamEpgEntry) _then;

/// Create a copy of XtreamEpgEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? start = null,Object? end = null,Object? description = freezed,}) {
  return _then(XtreamEpgEntry(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [XtreamEpgEntry].
extension XtreamEpgEntryPatterns on XtreamEpgEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _XtreamEpgEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _XtreamEpgEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _XtreamEpgEntry value)  $default,){
final _that = this;
switch (_that) {
case _XtreamEpgEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _XtreamEpgEntry value)?  $default,){
final _that = this;
switch (_that) {
case _XtreamEpgEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  DateTime start,  DateTime end,  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _XtreamEpgEntry() when $default != null:
return $default(_that.title,_that.start,_that.end,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  DateTime start,  DateTime end,  String? description)  $default,) {final _that = this;
switch (_that) {
case _XtreamEpgEntry():
return $default(_that.title,_that.start,_that.end,_that.description);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  DateTime start,  DateTime end,  String? description)?  $default,) {final _that = this;
switch (_that) {
case _XtreamEpgEntry() when $default != null:
return $default(_that.title,_that.start,_that.end,_that.description);case _:
  return null;

}
}

}

/// @nodoc


class _XtreamEpgEntry implements XtreamEpgEntry {
  const _XtreamEpgEntry({required this.title, required this.start, required this.end, this.description});
  

@override final  String title;
@override final  DateTime start;
@override final  DateTime end;
@override final  String? description;

/// Create a copy of XtreamEpgEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$XtreamEpgEntryCopyWith<_XtreamEpgEntry> get copyWith => __$XtreamEpgEntryCopyWithImpl<_XtreamEpgEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _XtreamEpgEntry&&(identical(other.title, title) || other.title == title)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.description, description) || other.description == description));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,start,end,description);
}

@override
String toString() {
    return 'XtreamEpgEntry(title: $title, start: $start, end: $end, description: $description)';
}


}

/// @nodoc
abstract mixin class _$XtreamEpgEntryCopyWith<$Res> implements $XtreamEpgEntryCopyWith<$Res> {
  factory _$XtreamEpgEntryCopyWith(_XtreamEpgEntry value, $Res Function(_XtreamEpgEntry) _then) = __$XtreamEpgEntryCopyWithImpl;
@override @useResult
$Res call({
 String title, DateTime start, DateTime end, String? description
});




}
/// @nodoc
class __$XtreamEpgEntryCopyWithImpl<$Res>
    implements _$XtreamEpgEntryCopyWith<$Res> {
  __$XtreamEpgEntryCopyWithImpl(this._self, this._then);

  final _XtreamEpgEntry _self;
  final $Res Function(_XtreamEpgEntry) _then;

/// Create a copy of XtreamEpgEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? start = null,Object? end = null,Object? description = freezed,}) {
  return _then(_XtreamEpgEntry(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
