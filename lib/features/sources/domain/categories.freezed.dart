// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'categories.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CategoryChoice {

 int get id;/// The user's rename, or the provider's name.
 String get name; bool get isHidden;/// Channels, movies or series filed under it.
 int get itemCount;
/// Create a copy of CategoryChoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryChoiceCopyWith<CategoryChoice> get copyWith => _$CategoryChoiceCopyWithImpl<CategoryChoice>(this as CategoryChoice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CategoryChoice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryChoice&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.isHidden, _this.isHidden) || other.isHidden == _this.isHidden)&&(identical(other.itemCount, _this.itemCount) || other.itemCount == _this.itemCount));
}


@override
int get hashCode {
  final _this = this as CategoryChoice;
  return Object.hash(runtimeType,_this.id,_this.name,_this.isHidden,_this.itemCount);
}

@override
String toString() {
  final _this = this as CategoryChoice;
  return 'CategoryChoice(id: ${_this.id}, name: ${_this.name}, isHidden: ${_this.isHidden}, itemCount: ${_this.itemCount})';
}


}

/// @nodoc
abstract mixin class $CategoryChoiceCopyWith<$Res>  {
  factory $CategoryChoiceCopyWith(CategoryChoice value, $Res Function(CategoryChoice) _then) = _$CategoryChoiceCopyWithImpl;
@useResult
$Res call({
 int id, String name, bool isHidden, int itemCount
});




}
/// @nodoc
class _$CategoryChoiceCopyWithImpl<$Res>
    implements $CategoryChoiceCopyWith<$Res> {
  _$CategoryChoiceCopyWithImpl(this._self, this._then);

  final CategoryChoice _self;
  final $Res Function(CategoryChoice) _then;

/// Create a copy of CategoryChoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? isHidden = null,Object? itemCount = null,}) {
  return _then(CategoryChoice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isHidden: null == isHidden ? _self.isHidden : isHidden // ignore: cast_nullable_to_non_nullable
as bool,itemCount: null == itemCount ? _self.itemCount : itemCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CategoryChoice].
extension CategoryChoicePatterns on CategoryChoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoryChoice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoryChoice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoryChoice value)  $default,){
final _that = this;
switch (_that) {
case _CategoryChoice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoryChoice value)?  $default,){
final _that = this;
switch (_that) {
case _CategoryChoice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  bool isHidden,  int itemCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoryChoice() when $default != null:
return $default(_that.id,_that.name,_that.isHidden,_that.itemCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  bool isHidden,  int itemCount)  $default,) {final _that = this;
switch (_that) {
case _CategoryChoice():
return $default(_that.id,_that.name,_that.isHidden,_that.itemCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  bool isHidden,  int itemCount)?  $default,) {final _that = this;
switch (_that) {
case _CategoryChoice() when $default != null:
return $default(_that.id,_that.name,_that.isHidden,_that.itemCount);case _:
  return null;

}
}

}

/// @nodoc


class _CategoryChoice implements CategoryChoice {
  const _CategoryChoice({required this.id, required this.name, required this.isHidden, required this.itemCount});
  

@override final  int id;
/// The user's rename, or the provider's name.
@override final  String name;
@override final  bool isHidden;
/// Channels, movies or series filed under it.
@override final  int itemCount;

/// Create a copy of CategoryChoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryChoiceCopyWith<_CategoryChoice> get copyWith => __$CategoryChoiceCopyWithImpl<_CategoryChoice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoryChoice&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isHidden, isHidden) || other.isHidden == isHidden)&&(identical(other.itemCount, itemCount) || other.itemCount == itemCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,isHidden,itemCount);
}

@override
String toString() {
    return 'CategoryChoice(id: $id, name: $name, isHidden: $isHidden, itemCount: $itemCount)';
}


}

/// @nodoc
abstract mixin class _$CategoryChoiceCopyWith<$Res> implements $CategoryChoiceCopyWith<$Res> {
  factory _$CategoryChoiceCopyWith(_CategoryChoice value, $Res Function(_CategoryChoice) _then) = __$CategoryChoiceCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, bool isHidden, int itemCount
});




}
/// @nodoc
class __$CategoryChoiceCopyWithImpl<$Res>
    implements _$CategoryChoiceCopyWith<$Res> {
  __$CategoryChoiceCopyWithImpl(this._self, this._then);

  final _CategoryChoice _self;
  final $Res Function(_CategoryChoice) _then;

/// Create a copy of CategoryChoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? isHidden = null,Object? itemCount = null,}) {
  return _then(_CategoryChoice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isHidden: null == isHidden ? _self.isHidden : isHidden // ignore: cast_nullable_to_non_nullable
as bool,itemCount: null == itemCount ? _self.itemCount : itemCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$CategoryList {

 List<CategoryChoice> get categories;/// Items with no category, or one the provider no longer lists. They
/// are always shown: there is no category to hide them with.
 int get uncategorized;
/// Create a copy of CategoryList
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoryListCopyWith<CategoryList> get copyWith => _$CategoryListCopyWithImpl<CategoryList>(this as CategoryList, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CategoryList;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoryList&&const DeepCollectionEquality().equals(other.categories, _this.categories)&&(identical(other.uncategorized, _this.uncategorized) || other.uncategorized == _this.uncategorized));
}


@override
int get hashCode {
  final _this = this as CategoryList;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.categories),_this.uncategorized);
}

@override
String toString() {
  final _this = this as CategoryList;
  return 'CategoryList(categories: ${_this.categories}, uncategorized: ${_this.uncategorized})';
}


}

/// @nodoc
abstract mixin class $CategoryListCopyWith<$Res>  {
  factory $CategoryListCopyWith(CategoryList value, $Res Function(CategoryList) _then) = _$CategoryListCopyWithImpl;
@useResult
$Res call({
 List<CategoryChoice> categories, int uncategorized
});




}
/// @nodoc
class _$CategoryListCopyWithImpl<$Res>
    implements $CategoryListCopyWith<$Res> {
  _$CategoryListCopyWithImpl(this._self, this._then);

  final CategoryList _self;
  final $Res Function(CategoryList) _then;

/// Create a copy of CategoryList
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? categories = null,Object? uncategorized = null,}) {
  return _then(CategoryList(
categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<CategoryChoice>,uncategorized: null == uncategorized ? _self.uncategorized : uncategorized // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CategoryList].
extension CategoryListPatterns on CategoryList {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoryList value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoryList() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoryList value)  $default,){
final _that = this;
switch (_that) {
case _CategoryList():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoryList value)?  $default,){
final _that = this;
switch (_that) {
case _CategoryList() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CategoryChoice> categories,  int uncategorized)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoryList() when $default != null:
return $default(_that.categories,_that.uncategorized);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CategoryChoice> categories,  int uncategorized)  $default,) {final _that = this;
switch (_that) {
case _CategoryList():
return $default(_that.categories,_that.uncategorized);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CategoryChoice> categories,  int uncategorized)?  $default,) {final _that = this;
switch (_that) {
case _CategoryList() when $default != null:
return $default(_that.categories,_that.uncategorized);case _:
  return null;

}
}

}

/// @nodoc


class _CategoryList extends CategoryList {
  const _CategoryList({required  List<CategoryChoice> categories, this.uncategorized = 0}): _categories = categories,super._();
  

 final  List<CategoryChoice> _categories;
@override List<CategoryChoice> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

/// Items with no category, or one the provider no longer lists. They
/// are always shown: there is no category to hide them with.
@override@JsonKey() final  int uncategorized;

/// Create a copy of CategoryList
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoryListCopyWith<_CategoryList> get copyWith => __$CategoryListCopyWithImpl<_CategoryList>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoryList&&const DeepCollectionEquality().equals(other.categories, _categories)&&(identical(other.uncategorized, uncategorized) || other.uncategorized == uncategorized));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_categories),uncategorized);
}

@override
String toString() {
    return 'CategoryList(categories: $categories, uncategorized: $uncategorized)';
}


}

/// @nodoc
abstract mixin class _$CategoryListCopyWith<$Res> implements $CategoryListCopyWith<$Res> {
  factory _$CategoryListCopyWith(_CategoryList value, $Res Function(_CategoryList) _then) = __$CategoryListCopyWithImpl;
@override @useResult
$Res call({
 List<CategoryChoice> categories, int uncategorized
});




}
/// @nodoc
class __$CategoryListCopyWithImpl<$Res>
    implements _$CategoryListCopyWith<$Res> {
  __$CategoryListCopyWithImpl(this._self, this._then);

  final _CategoryList _self;
  final $Res Function(_CategoryList) _then;

/// Create a copy of CategoryList
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? categories = null,Object? uncategorized = null,}) {
  return _then(_CategoryList(
categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<CategoryChoice>,uncategorized: null == uncategorized ? _self.uncategorized : uncategorized // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
