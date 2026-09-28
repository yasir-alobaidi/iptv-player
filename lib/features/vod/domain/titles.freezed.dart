// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'titles.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MovieItem {

/// The database row id: stable within a sync, not across them. User
/// data is keyed by [sourceId] + [remoteKey].
 int get id; String get sourceId; String get remoteKey; String get name; String? get posterUrl;/// Out of 10.
 double? get rating; int? get year;/// The container extension the stream URL needs (`mkv`).
 String? get ext; int? get categoryId; DateTime? get addedAt; bool get isFavorite;/// Where it was left, when it was ever played.
 WatchMark? get watch;/// From its details, once they were fetched (the focused card shows
/// it).
 Duration? get runtime;
/// Create a copy of MovieItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MovieItemCopyWith<MovieItem> get copyWith => _$MovieItemCopyWithImpl<MovieItem>(this as MovieItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MovieItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MovieItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.remoteKey, _this.remoteKey) || other.remoteKey == _this.remoteKey)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.posterUrl, _this.posterUrl) || other.posterUrl == _this.posterUrl)&&(identical(other.rating, _this.rating) || other.rating == _this.rating)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.ext, _this.ext) || other.ext == _this.ext)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt)&&(identical(other.isFavorite, _this.isFavorite) || other.isFavorite == _this.isFavorite)&&(identical(other.watch, _this.watch) || other.watch == _this.watch)&&(identical(other.runtime, _this.runtime) || other.runtime == _this.runtime));
}


@override
int get hashCode {
  final _this = this as MovieItem;
  return Object.hash(runtimeType,_this.id,_this.sourceId,_this.remoteKey,_this.name,_this.posterUrl,_this.rating,_this.year,_this.ext,_this.categoryId,_this.addedAt,_this.isFavorite,_this.watch,_this.runtime);
}

@override
String toString() {
  final _this = this as MovieItem;
  return 'MovieItem(id: ${_this.id}, sourceId: ${_this.sourceId}, remoteKey: ${_this.remoteKey}, name: ${_this.name}, posterUrl: ${_this.posterUrl}, rating: ${_this.rating}, year: ${_this.year}, ext: ${_this.ext}, categoryId: ${_this.categoryId}, addedAt: ${_this.addedAt}, isFavorite: ${_this.isFavorite}, watch: ${_this.watch}, runtime: ${_this.runtime})';
}


}

/// @nodoc
abstract mixin class $MovieItemCopyWith<$Res>  {
  factory $MovieItemCopyWith(MovieItem value, $Res Function(MovieItem) _then) = _$MovieItemCopyWithImpl;
@useResult
$Res call({
 int id, String sourceId, String remoteKey, String name, String? posterUrl, double? rating, int? year, String? ext, int? categoryId, DateTime? addedAt, bool isFavorite, WatchMark? watch, Duration? runtime
});




}
/// @nodoc
class _$MovieItemCopyWithImpl<$Res>
    implements $MovieItemCopyWith<$Res> {
  _$MovieItemCopyWithImpl(this._self, this._then);

  final MovieItem _self;
  final $Res Function(MovieItem) _then;

/// Create a copy of MovieItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceId = null,Object? remoteKey = null,Object? name = null,Object? posterUrl = freezed,Object? rating = freezed,Object? year = freezed,Object? ext = freezed,Object? categoryId = freezed,Object? addedAt = freezed,Object? isFavorite = null,Object? watch = freezed,Object? runtime = freezed,}) {
  return _then(MovieItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int?,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,watch: freezed == watch ? _self.watch : watch // ignore: cast_nullable_to_non_nullable
as WatchMark?,runtime: freezed == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}

}


/// Adds pattern-matching-related methods to [MovieItem].
extension MovieItemPatterns on MovieItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MovieItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MovieItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MovieItem value)  $default,){
final _that = this;
switch (_that) {
case _MovieItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MovieItem value)?  $default,){
final _that = this;
switch (_that) {
case _MovieItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String sourceId,  String remoteKey,  String name,  String? posterUrl,  double? rating,  int? year,  String? ext,  int? categoryId,  DateTime? addedAt,  bool isFavorite,  WatchMark? watch,  Duration? runtime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MovieItem() when $default != null:
return $default(_that.id,_that.sourceId,_that.remoteKey,_that.name,_that.posterUrl,_that.rating,_that.year,_that.ext,_that.categoryId,_that.addedAt,_that.isFavorite,_that.watch,_that.runtime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String sourceId,  String remoteKey,  String name,  String? posterUrl,  double? rating,  int? year,  String? ext,  int? categoryId,  DateTime? addedAt,  bool isFavorite,  WatchMark? watch,  Duration? runtime)  $default,) {final _that = this;
switch (_that) {
case _MovieItem():
return $default(_that.id,_that.sourceId,_that.remoteKey,_that.name,_that.posterUrl,_that.rating,_that.year,_that.ext,_that.categoryId,_that.addedAt,_that.isFavorite,_that.watch,_that.runtime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String sourceId,  String remoteKey,  String name,  String? posterUrl,  double? rating,  int? year,  String? ext,  int? categoryId,  DateTime? addedAt,  bool isFavorite,  WatchMark? watch,  Duration? runtime)?  $default,) {final _that = this;
switch (_that) {
case _MovieItem() when $default != null:
return $default(_that.id,_that.sourceId,_that.remoteKey,_that.name,_that.posterUrl,_that.rating,_that.year,_that.ext,_that.categoryId,_that.addedAt,_that.isFavorite,_that.watch,_that.runtime);case _:
  return null;

}
}

}

/// @nodoc


class _MovieItem extends MovieItem {
  const _MovieItem({required this.id, required this.sourceId, required this.remoteKey, required this.name, this.posterUrl, this.rating, this.year, this.ext, this.categoryId, this.addedAt, this.isFavorite = false, this.watch, this.runtime}): super._();
  

/// The database row id: stable within a sync, not across them. User
/// data is keyed by [sourceId] + [remoteKey].
@override final  int id;
@override final  String sourceId;
@override final  String remoteKey;
@override final  String name;
@override final  String? posterUrl;
/// Out of 10.
@override final  double? rating;
@override final  int? year;
/// The container extension the stream URL needs (`mkv`).
@override final  String? ext;
@override final  int? categoryId;
@override final  DateTime? addedAt;
@override@JsonKey() final  bool isFavorite;
/// Where it was left, when it was ever played.
@override final  WatchMark? watch;
/// From its details, once they were fetched (the focused card shows
/// it).
@override final  Duration? runtime;

/// Create a copy of MovieItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MovieItemCopyWith<_MovieItem> get copyWith => __$MovieItemCopyWithImpl<_MovieItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MovieItem&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.remoteKey, remoteKey) || other.remoteKey == remoteKey)&&(identical(other.name, name) || other.name == name)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.year, year) || other.year == year)&&(identical(other.ext, ext) || other.ext == ext)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.watch, watch) || other.watch == watch)&&(identical(other.runtime, runtime) || other.runtime == runtime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,sourceId,remoteKey,name,posterUrl,rating,year,ext,categoryId,addedAt,isFavorite,watch,runtime);
}

@override
String toString() {
    return 'MovieItem(id: $id, sourceId: $sourceId, remoteKey: $remoteKey, name: $name, posterUrl: $posterUrl, rating: $rating, year: $year, ext: $ext, categoryId: $categoryId, addedAt: $addedAt, isFavorite: $isFavorite, watch: $watch, runtime: $runtime)';
}


}

/// @nodoc
abstract mixin class _$MovieItemCopyWith<$Res> implements $MovieItemCopyWith<$Res> {
  factory _$MovieItemCopyWith(_MovieItem value, $Res Function(_MovieItem) _then) = __$MovieItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String sourceId, String remoteKey, String name, String? posterUrl, double? rating, int? year, String? ext, int? categoryId, DateTime? addedAt, bool isFavorite, WatchMark? watch, Duration? runtime
});




}
/// @nodoc
class __$MovieItemCopyWithImpl<$Res>
    implements _$MovieItemCopyWith<$Res> {
  __$MovieItemCopyWithImpl(this._self, this._then);

  final _MovieItem _self;
  final $Res Function(_MovieItem) _then;

/// Create a copy of MovieItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceId = null,Object? remoteKey = null,Object? name = null,Object? posterUrl = freezed,Object? rating = freezed,Object? year = freezed,Object? ext = freezed,Object? categoryId = freezed,Object? addedAt = freezed,Object? isFavorite = null,Object? watch = freezed,Object? runtime = freezed,}) {
  return _then(_MovieItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int?,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,watch: freezed == watch ? _self.watch : watch // ignore: cast_nullable_to_non_nullable
as WatchMark?,runtime: freezed == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}


}

/// @nodoc
mixin _$MovieDetails {

 String? get plot; String? get cast; String? get director; String? get genre; Duration? get runtime; String? get backdropUrl;/// From the panel's probe of the file: 2160 is the 4K badge, 1080 FHD.
 int? get videoHeight;/// 6 is the 5.1 badge.
 int? get audioChannels;/// When it was fetched; null when there was nothing to fetch (M3U).
 DateTime? get fetchedAt;
/// Create a copy of MovieDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MovieDetailsCopyWith<MovieDetails> get copyWith => _$MovieDetailsCopyWithImpl<MovieDetails>(this as MovieDetails, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MovieDetails;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MovieDetails&&(identical(other.plot, _this.plot) || other.plot == _this.plot)&&(identical(other.cast, _this.cast) || other.cast == _this.cast)&&(identical(other.director, _this.director) || other.director == _this.director)&&(identical(other.genre, _this.genre) || other.genre == _this.genre)&&(identical(other.runtime, _this.runtime) || other.runtime == _this.runtime)&&(identical(other.backdropUrl, _this.backdropUrl) || other.backdropUrl == _this.backdropUrl)&&(identical(other.videoHeight, _this.videoHeight) || other.videoHeight == _this.videoHeight)&&(identical(other.audioChannels, _this.audioChannels) || other.audioChannels == _this.audioChannels)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt));
}


@override
int get hashCode {
  final _this = this as MovieDetails;
  return Object.hash(runtimeType,_this.plot,_this.cast,_this.director,_this.genre,_this.runtime,_this.backdropUrl,_this.videoHeight,_this.audioChannels,_this.fetchedAt);
}

@override
String toString() {
  final _this = this as MovieDetails;
  return 'MovieDetails(plot: ${_this.plot}, cast: ${_this.cast}, director: ${_this.director}, genre: ${_this.genre}, runtime: ${_this.runtime}, backdropUrl: ${_this.backdropUrl}, videoHeight: ${_this.videoHeight}, audioChannels: ${_this.audioChannels}, fetchedAt: ${_this.fetchedAt})';
}


}

/// @nodoc
abstract mixin class $MovieDetailsCopyWith<$Res>  {
  factory $MovieDetailsCopyWith(MovieDetails value, $Res Function(MovieDetails) _then) = _$MovieDetailsCopyWithImpl;
@useResult
$Res call({
 String? plot, String? cast, String? director, String? genre, Duration? runtime, String? backdropUrl, int? videoHeight, int? audioChannels, DateTime? fetchedAt
});




}
/// @nodoc
class _$MovieDetailsCopyWithImpl<$Res>
    implements $MovieDetailsCopyWith<$Res> {
  _$MovieDetailsCopyWithImpl(this._self, this._then);

  final MovieDetails _self;
  final $Res Function(MovieDetails) _then;

/// Create a copy of MovieDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? plot = freezed,Object? cast = freezed,Object? director = freezed,Object? genre = freezed,Object? runtime = freezed,Object? backdropUrl = freezed,Object? videoHeight = freezed,Object? audioChannels = freezed,Object? fetchedAt = freezed,}) {
  return _then(MovieDetails(
plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,cast: freezed == cast ? _self.cast : cast // ignore: cast_nullable_to_non_nullable
as String?,director: freezed == director ? _self.director : director // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,runtime: freezed == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as Duration?,backdropUrl: freezed == backdropUrl ? _self.backdropUrl : backdropUrl // ignore: cast_nullable_to_non_nullable
as String?,videoHeight: freezed == videoHeight ? _self.videoHeight : videoHeight // ignore: cast_nullable_to_non_nullable
as int?,audioChannels: freezed == audioChannels ? _self.audioChannels : audioChannels // ignore: cast_nullable_to_non_nullable
as int?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MovieDetails].
extension MovieDetailsPatterns on MovieDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MovieDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MovieDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MovieDetails value)  $default,){
final _that = this;
switch (_that) {
case _MovieDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MovieDetails value)?  $default,){
final _that = this;
switch (_that) {
case _MovieDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? plot,  String? cast,  String? director,  String? genre,  Duration? runtime,  String? backdropUrl,  int? videoHeight,  int? audioChannels,  DateTime? fetchedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MovieDetails() when $default != null:
return $default(_that.plot,_that.cast,_that.director,_that.genre,_that.runtime,_that.backdropUrl,_that.videoHeight,_that.audioChannels,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? plot,  String? cast,  String? director,  String? genre,  Duration? runtime,  String? backdropUrl,  int? videoHeight,  int? audioChannels,  DateTime? fetchedAt)  $default,) {final _that = this;
switch (_that) {
case _MovieDetails():
return $default(_that.plot,_that.cast,_that.director,_that.genre,_that.runtime,_that.backdropUrl,_that.videoHeight,_that.audioChannels,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? plot,  String? cast,  String? director,  String? genre,  Duration? runtime,  String? backdropUrl,  int? videoHeight,  int? audioChannels,  DateTime? fetchedAt)?  $default,) {final _that = this;
switch (_that) {
case _MovieDetails() when $default != null:
return $default(_that.plot,_that.cast,_that.director,_that.genre,_that.runtime,_that.backdropUrl,_that.videoHeight,_that.audioChannels,_that.fetchedAt);case _:
  return null;

}
}

}

/// @nodoc


class _MovieDetails implements MovieDetails {
  const _MovieDetails({this.plot, this.cast, this.director, this.genre, this.runtime, this.backdropUrl, this.videoHeight, this.audioChannels, this.fetchedAt});
  

@override final  String? plot;
@override final  String? cast;
@override final  String? director;
@override final  String? genre;
@override final  Duration? runtime;
@override final  String? backdropUrl;
/// From the panel's probe of the file: 2160 is the 4K badge, 1080 FHD.
@override final  int? videoHeight;
/// 6 is the 5.1 badge.
@override final  int? audioChannels;
/// When it was fetched; null when there was nothing to fetch (M3U).
@override final  DateTime? fetchedAt;

/// Create a copy of MovieDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MovieDetailsCopyWith<_MovieDetails> get copyWith => __$MovieDetailsCopyWithImpl<_MovieDetails>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MovieDetails&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.cast, cast) || other.cast == cast)&&(identical(other.director, director) || other.director == director)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&(identical(other.backdropUrl, backdropUrl) || other.backdropUrl == backdropUrl)&&(identical(other.videoHeight, videoHeight) || other.videoHeight == videoHeight)&&(identical(other.audioChannels, audioChannels) || other.audioChannels == audioChannels)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,plot,cast,director,genre,runtime,backdropUrl,videoHeight,audioChannels,fetchedAt);
}

@override
String toString() {
    return 'MovieDetails(plot: $plot, cast: $cast, director: $director, genre: $genre, runtime: $runtime, backdropUrl: $backdropUrl, videoHeight: $videoHeight, audioChannels: $audioChannels, fetchedAt: $fetchedAt)';
}


}

/// @nodoc
abstract mixin class _$MovieDetailsCopyWith<$Res> implements $MovieDetailsCopyWith<$Res> {
  factory _$MovieDetailsCopyWith(_MovieDetails value, $Res Function(_MovieDetails) _then) = __$MovieDetailsCopyWithImpl;
@override @useResult
$Res call({
 String? plot, String? cast, String? director, String? genre, Duration? runtime, String? backdropUrl, int? videoHeight, int? audioChannels, DateTime? fetchedAt
});




}
/// @nodoc
class __$MovieDetailsCopyWithImpl<$Res>
    implements _$MovieDetailsCopyWith<$Res> {
  __$MovieDetailsCopyWithImpl(this._self, this._then);

  final _MovieDetails _self;
  final $Res Function(_MovieDetails) _then;

/// Create a copy of MovieDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? plot = freezed,Object? cast = freezed,Object? director = freezed,Object? genre = freezed,Object? runtime = freezed,Object? backdropUrl = freezed,Object? videoHeight = freezed,Object? audioChannels = freezed,Object? fetchedAt = freezed,}) {
  return _then(_MovieDetails(
plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,cast: freezed == cast ? _self.cast : cast // ignore: cast_nullable_to_non_nullable
as String?,director: freezed == director ? _self.director : director // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,runtime: freezed == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as Duration?,backdropUrl: freezed == backdropUrl ? _self.backdropUrl : backdropUrl // ignore: cast_nullable_to_non_nullable
as String?,videoHeight: freezed == videoHeight ? _self.videoHeight : videoHeight // ignore: cast_nullable_to_non_nullable
as int?,audioChannels: freezed == audioChannels ? _self.audioChannels : audioChannels // ignore: cast_nullable_to_non_nullable
as int?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$SeriesItem {

 int get id; String get sourceId; String get remoteKey; String get name; String? get posterUrl; double? get rating; int? get year; String? get plot; String? get genre; String? get backdropUrl; int? get categoryId;/// The provider's `last_modified`.
 DateTime? get updatedAt; bool get isFavorite;
/// Create a copy of SeriesItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeriesItemCopyWith<SeriesItem> get copyWith => _$SeriesItemCopyWithImpl<SeriesItem>(this as SeriesItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SeriesItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.remoteKey, _this.remoteKey) || other.remoteKey == _this.remoteKey)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.posterUrl, _this.posterUrl) || other.posterUrl == _this.posterUrl)&&(identical(other.rating, _this.rating) || other.rating == _this.rating)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.plot, _this.plot) || other.plot == _this.plot)&&(identical(other.genre, _this.genre) || other.genre == _this.genre)&&(identical(other.backdropUrl, _this.backdropUrl) || other.backdropUrl == _this.backdropUrl)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.isFavorite, _this.isFavorite) || other.isFavorite == _this.isFavorite));
}


@override
int get hashCode {
  final _this = this as SeriesItem;
  return Object.hash(runtimeType,_this.id,_this.sourceId,_this.remoteKey,_this.name,_this.posterUrl,_this.rating,_this.year,_this.plot,_this.genre,_this.backdropUrl,_this.categoryId,_this.updatedAt,_this.isFavorite);
}

@override
String toString() {
  final _this = this as SeriesItem;
  return 'SeriesItem(id: ${_this.id}, sourceId: ${_this.sourceId}, remoteKey: ${_this.remoteKey}, name: ${_this.name}, posterUrl: ${_this.posterUrl}, rating: ${_this.rating}, year: ${_this.year}, plot: ${_this.plot}, genre: ${_this.genre}, backdropUrl: ${_this.backdropUrl}, categoryId: ${_this.categoryId}, updatedAt: ${_this.updatedAt}, isFavorite: ${_this.isFavorite})';
}


}

/// @nodoc
abstract mixin class $SeriesItemCopyWith<$Res>  {
  factory $SeriesItemCopyWith(SeriesItem value, $Res Function(SeriesItem) _then) = _$SeriesItemCopyWithImpl;
@useResult
$Res call({
 int id, String sourceId, String remoteKey, String name, String? posterUrl, double? rating, int? year, String? plot, String? genre, String? backdropUrl, int? categoryId, DateTime? updatedAt, bool isFavorite
});




}
/// @nodoc
class _$SeriesItemCopyWithImpl<$Res>
    implements $SeriesItemCopyWith<$Res> {
  _$SeriesItemCopyWithImpl(this._self, this._then);

  final SeriesItem _self;
  final $Res Function(SeriesItem) _then;

/// Create a copy of SeriesItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceId = null,Object? remoteKey = null,Object? name = null,Object? posterUrl = freezed,Object? rating = freezed,Object? year = freezed,Object? plot = freezed,Object? genre = freezed,Object? backdropUrl = freezed,Object? categoryId = freezed,Object? updatedAt = freezed,Object? isFavorite = null,}) {
  return _then(SeriesItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,backdropUrl: freezed == backdropUrl ? _self.backdropUrl : backdropUrl // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SeriesItem].
extension SeriesItemPatterns on SeriesItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SeriesItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SeriesItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SeriesItem value)  $default,){
final _that = this;
switch (_that) {
case _SeriesItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SeriesItem value)?  $default,){
final _that = this;
switch (_that) {
case _SeriesItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String sourceId,  String remoteKey,  String name,  String? posterUrl,  double? rating,  int? year,  String? plot,  String? genre,  String? backdropUrl,  int? categoryId,  DateTime? updatedAt,  bool isFavorite)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SeriesItem() when $default != null:
return $default(_that.id,_that.sourceId,_that.remoteKey,_that.name,_that.posterUrl,_that.rating,_that.year,_that.plot,_that.genre,_that.backdropUrl,_that.categoryId,_that.updatedAt,_that.isFavorite);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String sourceId,  String remoteKey,  String name,  String? posterUrl,  double? rating,  int? year,  String? plot,  String? genre,  String? backdropUrl,  int? categoryId,  DateTime? updatedAt,  bool isFavorite)  $default,) {final _that = this;
switch (_that) {
case _SeriesItem():
return $default(_that.id,_that.sourceId,_that.remoteKey,_that.name,_that.posterUrl,_that.rating,_that.year,_that.plot,_that.genre,_that.backdropUrl,_that.categoryId,_that.updatedAt,_that.isFavorite);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String sourceId,  String remoteKey,  String name,  String? posterUrl,  double? rating,  int? year,  String? plot,  String? genre,  String? backdropUrl,  int? categoryId,  DateTime? updatedAt,  bool isFavorite)?  $default,) {final _that = this;
switch (_that) {
case _SeriesItem() when $default != null:
return $default(_that.id,_that.sourceId,_that.remoteKey,_that.name,_that.posterUrl,_that.rating,_that.year,_that.plot,_that.genre,_that.backdropUrl,_that.categoryId,_that.updatedAt,_that.isFavorite);case _:
  return null;

}
}

}

/// @nodoc


class _SeriesItem extends SeriesItem {
  const _SeriesItem({required this.id, required this.sourceId, required this.remoteKey, required this.name, this.posterUrl, this.rating, this.year, this.plot, this.genre, this.backdropUrl, this.categoryId, this.updatedAt, this.isFavorite = false}): super._();
  

@override final  int id;
@override final  String sourceId;
@override final  String remoteKey;
@override final  String name;
@override final  String? posterUrl;
@override final  double? rating;
@override final  int? year;
@override final  String? plot;
@override final  String? genre;
@override final  String? backdropUrl;
@override final  int? categoryId;
/// The provider's `last_modified`.
@override final  DateTime? updatedAt;
@override@JsonKey() final  bool isFavorite;

/// Create a copy of SeriesItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SeriesItemCopyWith<_SeriesItem> get copyWith => __$SeriesItemCopyWithImpl<_SeriesItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SeriesItem&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.remoteKey, remoteKey) || other.remoteKey == remoteKey)&&(identical(other.name, name) || other.name == name)&&(identical(other.posterUrl, posterUrl) || other.posterUrl == posterUrl)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.year, year) || other.year == year)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.backdropUrl, backdropUrl) || other.backdropUrl == backdropUrl)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,sourceId,remoteKey,name,posterUrl,rating,year,plot,genre,backdropUrl,categoryId,updatedAt,isFavorite);
}

@override
String toString() {
    return 'SeriesItem(id: $id, sourceId: $sourceId, remoteKey: $remoteKey, name: $name, posterUrl: $posterUrl, rating: $rating, year: $year, plot: $plot, genre: $genre, backdropUrl: $backdropUrl, categoryId: $categoryId, updatedAt: $updatedAt, isFavorite: $isFavorite)';
}


}

/// @nodoc
abstract mixin class _$SeriesItemCopyWith<$Res> implements $SeriesItemCopyWith<$Res> {
  factory _$SeriesItemCopyWith(_SeriesItem value, $Res Function(_SeriesItem) _then) = __$SeriesItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String sourceId, String remoteKey, String name, String? posterUrl, double? rating, int? year, String? plot, String? genre, String? backdropUrl, int? categoryId, DateTime? updatedAt, bool isFavorite
});




}
/// @nodoc
class __$SeriesItemCopyWithImpl<$Res>
    implements _$SeriesItemCopyWith<$Res> {
  __$SeriesItemCopyWithImpl(this._self, this._then);

  final _SeriesItem _self;
  final $Res Function(_SeriesItem) _then;

/// Create a copy of SeriesItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceId = null,Object? remoteKey = null,Object? name = null,Object? posterUrl = freezed,Object? rating = freezed,Object? year = freezed,Object? plot = freezed,Object? genre = freezed,Object? backdropUrl = freezed,Object? categoryId = freezed,Object? updatedAt = freezed,Object? isFavorite = null,}) {
  return _then(_SeriesItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,posterUrl: freezed == posterUrl ? _self.posterUrl : posterUrl // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,backdropUrl: freezed == backdropUrl ? _self.backdropUrl : backdropUrl // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$EpisodeItem {

 int get id; String get sourceId;/// The series' remote key.
 String get seriesKey; String get remoteKey; int get season; int get episode; String get title; String? get ext; Duration? get duration; String? get plot; String? get stillUrl;
/// Create a copy of EpisodeItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpisodeItemCopyWith<EpisodeItem> get copyWith => _$EpisodeItemCopyWithImpl<EpisodeItem>(this as EpisodeItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EpisodeItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EpisodeItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.seriesKey, _this.seriesKey) || other.seriesKey == _this.seriesKey)&&(identical(other.remoteKey, _this.remoteKey) || other.remoteKey == _this.remoteKey)&&(identical(other.season, _this.season) || other.season == _this.season)&&(identical(other.episode, _this.episode) || other.episode == _this.episode)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.ext, _this.ext) || other.ext == _this.ext)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.plot, _this.plot) || other.plot == _this.plot)&&(identical(other.stillUrl, _this.stillUrl) || other.stillUrl == _this.stillUrl));
}


@override
int get hashCode {
  final _this = this as EpisodeItem;
  return Object.hash(runtimeType,_this.id,_this.sourceId,_this.seriesKey,_this.remoteKey,_this.season,_this.episode,_this.title,_this.ext,_this.duration,_this.plot,_this.stillUrl);
}

@override
String toString() {
  final _this = this as EpisodeItem;
  return 'EpisodeItem(id: ${_this.id}, sourceId: ${_this.sourceId}, seriesKey: ${_this.seriesKey}, remoteKey: ${_this.remoteKey}, season: ${_this.season}, episode: ${_this.episode}, title: ${_this.title}, ext: ${_this.ext}, duration: ${_this.duration}, plot: ${_this.plot}, stillUrl: ${_this.stillUrl})';
}


}

/// @nodoc
abstract mixin class $EpisodeItemCopyWith<$Res>  {
  factory $EpisodeItemCopyWith(EpisodeItem value, $Res Function(EpisodeItem) _then) = _$EpisodeItemCopyWithImpl;
@useResult
$Res call({
 int id, String sourceId, String seriesKey, String remoteKey, int season, int episode, String title, String? ext, Duration? duration, String? plot, String? stillUrl
});




}
/// @nodoc
class _$EpisodeItemCopyWithImpl<$Res>
    implements $EpisodeItemCopyWith<$Res> {
  _$EpisodeItemCopyWithImpl(this._self, this._then);

  final EpisodeItem _self;
  final $Res Function(EpisodeItem) _then;

/// Create a copy of EpisodeItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceId = null,Object? seriesKey = null,Object? remoteKey = null,Object? season = null,Object? episode = null,Object? title = null,Object? ext = freezed,Object? duration = freezed,Object? plot = freezed,Object? stillUrl = freezed,}) {
  return _then(EpisodeItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,seriesKey: null == seriesKey ? _self.seriesKey : seriesKey // ignore: cast_nullable_to_non_nullable
as String,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,season: null == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int,episode: null == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,stillUrl: freezed == stillUrl ? _self.stillUrl : stillUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EpisodeItem].
extension EpisodeItemPatterns on EpisodeItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EpisodeItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EpisodeItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EpisodeItem value)  $default,){
final _that = this;
switch (_that) {
case _EpisodeItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EpisodeItem value)?  $default,){
final _that = this;
switch (_that) {
case _EpisodeItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String sourceId,  String seriesKey,  String remoteKey,  int season,  int episode,  String title,  String? ext,  Duration? duration,  String? plot,  String? stillUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EpisodeItem() when $default != null:
return $default(_that.id,_that.sourceId,_that.seriesKey,_that.remoteKey,_that.season,_that.episode,_that.title,_that.ext,_that.duration,_that.plot,_that.stillUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String sourceId,  String seriesKey,  String remoteKey,  int season,  int episode,  String title,  String? ext,  Duration? duration,  String? plot,  String? stillUrl)  $default,) {final _that = this;
switch (_that) {
case _EpisodeItem():
return $default(_that.id,_that.sourceId,_that.seriesKey,_that.remoteKey,_that.season,_that.episode,_that.title,_that.ext,_that.duration,_that.plot,_that.stillUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String sourceId,  String seriesKey,  String remoteKey,  int season,  int episode,  String title,  String? ext,  Duration? duration,  String? plot,  String? stillUrl)?  $default,) {final _that = this;
switch (_that) {
case _EpisodeItem() when $default != null:
return $default(_that.id,_that.sourceId,_that.seriesKey,_that.remoteKey,_that.season,_that.episode,_that.title,_that.ext,_that.duration,_that.plot,_that.stillUrl);case _:
  return null;

}
}

}

/// @nodoc


class _EpisodeItem extends EpisodeItem {
  const _EpisodeItem({required this.id, required this.sourceId, required this.seriesKey, required this.remoteKey, required this.season, required this.episode, required this.title, this.ext, this.duration, this.plot, this.stillUrl}): super._();
  

@override final  int id;
@override final  String sourceId;
/// The series' remote key.
@override final  String seriesKey;
@override final  String remoteKey;
@override final  int season;
@override final  int episode;
@override final  String title;
@override final  String? ext;
@override final  Duration? duration;
@override final  String? plot;
@override final  String? stillUrl;

/// Create a copy of EpisodeItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpisodeItemCopyWith<_EpisodeItem> get copyWith => __$EpisodeItemCopyWithImpl<_EpisodeItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EpisodeItem&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.seriesKey, seriesKey) || other.seriesKey == seriesKey)&&(identical(other.remoteKey, remoteKey) || other.remoteKey == remoteKey)&&(identical(other.season, season) || other.season == season)&&(identical(other.episode, episode) || other.episode == episode)&&(identical(other.title, title) || other.title == title)&&(identical(other.ext, ext) || other.ext == ext)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.stillUrl, stillUrl) || other.stillUrl == stillUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,sourceId,seriesKey,remoteKey,season,episode,title,ext,duration,plot,stillUrl);
}

@override
String toString() {
    return 'EpisodeItem(id: $id, sourceId: $sourceId, seriesKey: $seriesKey, remoteKey: $remoteKey, season: $season, episode: $episode, title: $title, ext: $ext, duration: $duration, plot: $plot, stillUrl: $stillUrl)';
}


}

/// @nodoc
abstract mixin class _$EpisodeItemCopyWith<$Res> implements $EpisodeItemCopyWith<$Res> {
  factory _$EpisodeItemCopyWith(_EpisodeItem value, $Res Function(_EpisodeItem) _then) = __$EpisodeItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String sourceId, String seriesKey, String remoteKey, int season, int episode, String title, String? ext, Duration? duration, String? plot, String? stillUrl
});




}
/// @nodoc
class __$EpisodeItemCopyWithImpl<$Res>
    implements _$EpisodeItemCopyWith<$Res> {
  __$EpisodeItemCopyWithImpl(this._self, this._then);

  final _EpisodeItem _self;
  final $Res Function(_EpisodeItem) _then;

/// Create a copy of EpisodeItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceId = null,Object? seriesKey = null,Object? remoteKey = null,Object? season = null,Object? episode = null,Object? title = null,Object? ext = freezed,Object? duration = freezed,Object? plot = freezed,Object? stillUrl = freezed,}) {
  return _then(_EpisodeItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,seriesKey: null == seriesKey ? _self.seriesKey : seriesKey // ignore: cast_nullable_to_non_nullable
as String,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,season: null == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int,episode: null == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,ext: freezed == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,stillUrl: freezed == stillUrl ? _self.stillUrl : stillUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$Season {

 int get number; List<EpisodeItem> get episodes;
/// Create a copy of Season
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeasonCopyWith<Season> get copyWith => _$SeasonCopyWithImpl<Season>(this as Season, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Season;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Season&&(identical(other.number, _this.number) || other.number == _this.number)&&const DeepCollectionEquality().equals(other.episodes, _this.episodes));
}


@override
int get hashCode {
  final _this = this as Season;
  return Object.hash(runtimeType,_this.number,const DeepCollectionEquality().hash(_this.episodes));
}

@override
String toString() {
  final _this = this as Season;
  return 'Season(number: ${_this.number}, episodes: ${_this.episodes})';
}


}

/// @nodoc
abstract mixin class $SeasonCopyWith<$Res>  {
  factory $SeasonCopyWith(Season value, $Res Function(Season) _then) = _$SeasonCopyWithImpl;
@useResult
$Res call({
 int number, List<EpisodeItem> episodes
});




}
/// @nodoc
class _$SeasonCopyWithImpl<$Res>
    implements $SeasonCopyWith<$Res> {
  _$SeasonCopyWithImpl(this._self, this._then);

  final Season _self;
  final $Res Function(Season) _then;

/// Create a copy of Season
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? episodes = null,}) {
  return _then(Season(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as List<EpisodeItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [Season].
extension SeasonPatterns on Season {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Season value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Season() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Season value)  $default,){
final _that = this;
switch (_that) {
case _Season():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Season value)?  $default,){
final _that = this;
switch (_that) {
case _Season() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int number,  List<EpisodeItem> episodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Season() when $default != null:
return $default(_that.number,_that.episodes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int number,  List<EpisodeItem> episodes)  $default,) {final _that = this;
switch (_that) {
case _Season():
return $default(_that.number,_that.episodes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int number,  List<EpisodeItem> episodes)?  $default,) {final _that = this;
switch (_that) {
case _Season() when $default != null:
return $default(_that.number,_that.episodes);case _:
  return null;

}
}

}

/// @nodoc


class _Season implements Season {
  const _Season({required this.number, required  List<EpisodeItem> episodes}): _episodes = episodes;
  

@override final  int number;
 final  List<EpisodeItem> _episodes;
@override List<EpisodeItem> get episodes {
  if (_episodes is EqualUnmodifiableListView) return _episodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_episodes);
}


/// Create a copy of Season
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SeasonCopyWith<_Season> get copyWith => __$SeasonCopyWithImpl<_Season>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Season&&(identical(other.number, number) || other.number == number)&&const DeepCollectionEquality().equals(other.episodes, _episodes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,number,const DeepCollectionEquality().hash(_episodes));
}

@override
String toString() {
    return 'Season(number: $number, episodes: $episodes)';
}


}

/// @nodoc
abstract mixin class _$SeasonCopyWith<$Res> implements $SeasonCopyWith<$Res> {
  factory _$SeasonCopyWith(_Season value, $Res Function(_Season) _then) = __$SeasonCopyWithImpl;
@override @useResult
$Res call({
 int number, List<EpisodeItem> episodes
});




}
/// @nodoc
class __$SeasonCopyWithImpl<$Res>
    implements _$SeasonCopyWith<$Res> {
  __$SeasonCopyWithImpl(this._self, this._then);

  final _Season _self;
  final $Res Function(_Season) _then;

/// Create a copy of Season
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? episodes = null,}) {
  return _then(_Season(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self._episodes : episodes // ignore: cast_nullable_to_non_nullable
as List<EpisodeItem>,
  ));
}


}

/// @nodoc
mixin _$SeriesDetails {

 List<Season> get seasons; String? get plot; String? get cast; String? get director; String? get genre; String? get backdropUrl;/// When the episodes were fetched; null for an M3U source, whose
/// episodes came with the sync.
 DateTime? get fetchedAt;
/// Create a copy of SeriesDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeriesDetailsCopyWith<SeriesDetails> get copyWith => _$SeriesDetailsCopyWithImpl<SeriesDetails>(this as SeriesDetails, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SeriesDetails;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesDetails&&const DeepCollectionEquality().equals(other.seasons, _this.seasons)&&(identical(other.plot, _this.plot) || other.plot == _this.plot)&&(identical(other.cast, _this.cast) || other.cast == _this.cast)&&(identical(other.director, _this.director) || other.director == _this.director)&&(identical(other.genre, _this.genre) || other.genre == _this.genre)&&(identical(other.backdropUrl, _this.backdropUrl) || other.backdropUrl == _this.backdropUrl)&&(identical(other.fetchedAt, _this.fetchedAt) || other.fetchedAt == _this.fetchedAt));
}


@override
int get hashCode {
  final _this = this as SeriesDetails;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.seasons),_this.plot,_this.cast,_this.director,_this.genre,_this.backdropUrl,_this.fetchedAt);
}

@override
String toString() {
  final _this = this as SeriesDetails;
  return 'SeriesDetails(seasons: ${_this.seasons}, plot: ${_this.plot}, cast: ${_this.cast}, director: ${_this.director}, genre: ${_this.genre}, backdropUrl: ${_this.backdropUrl}, fetchedAt: ${_this.fetchedAt})';
}


}

/// @nodoc
abstract mixin class $SeriesDetailsCopyWith<$Res>  {
  factory $SeriesDetailsCopyWith(SeriesDetails value, $Res Function(SeriesDetails) _then) = _$SeriesDetailsCopyWithImpl;
@useResult
$Res call({
 List<Season> seasons, String? plot, String? cast, String? director, String? genre, String? backdropUrl, DateTime? fetchedAt
});




}
/// @nodoc
class _$SeriesDetailsCopyWithImpl<$Res>
    implements $SeriesDetailsCopyWith<$Res> {
  _$SeriesDetailsCopyWithImpl(this._self, this._then);

  final SeriesDetails _self;
  final $Res Function(SeriesDetails) _then;

/// Create a copy of SeriesDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seasons = null,Object? plot = freezed,Object? cast = freezed,Object? director = freezed,Object? genre = freezed,Object? backdropUrl = freezed,Object? fetchedAt = freezed,}) {
  return _then(SeriesDetails(
seasons: null == seasons ? _self.seasons : seasons // ignore: cast_nullable_to_non_nullable
as List<Season>,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,cast: freezed == cast ? _self.cast : cast // ignore: cast_nullable_to_non_nullable
as String?,director: freezed == director ? _self.director : director // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,backdropUrl: freezed == backdropUrl ? _self.backdropUrl : backdropUrl // ignore: cast_nullable_to_non_nullable
as String?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SeriesDetails].
extension SeriesDetailsPatterns on SeriesDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SeriesDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SeriesDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SeriesDetails value)  $default,){
final _that = this;
switch (_that) {
case _SeriesDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SeriesDetails value)?  $default,){
final _that = this;
switch (_that) {
case _SeriesDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Season> seasons,  String? plot,  String? cast,  String? director,  String? genre,  String? backdropUrl,  DateTime? fetchedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SeriesDetails() when $default != null:
return $default(_that.seasons,_that.plot,_that.cast,_that.director,_that.genre,_that.backdropUrl,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Season> seasons,  String? plot,  String? cast,  String? director,  String? genre,  String? backdropUrl,  DateTime? fetchedAt)  $default,) {final _that = this;
switch (_that) {
case _SeriesDetails():
return $default(_that.seasons,_that.plot,_that.cast,_that.director,_that.genre,_that.backdropUrl,_that.fetchedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Season> seasons,  String? plot,  String? cast,  String? director,  String? genre,  String? backdropUrl,  DateTime? fetchedAt)?  $default,) {final _that = this;
switch (_that) {
case _SeriesDetails() when $default != null:
return $default(_that.seasons,_that.plot,_that.cast,_that.director,_that.genre,_that.backdropUrl,_that.fetchedAt);case _:
  return null;

}
}

}

/// @nodoc


class _SeriesDetails extends SeriesDetails {
  const _SeriesDetails({ List<Season> seasons = const <Season>[], this.plot, this.cast, this.director, this.genre, this.backdropUrl, this.fetchedAt}): _seasons = seasons,super._();
  

 final  List<Season> _seasons;
@override@JsonKey() List<Season> get seasons {
  if (_seasons is EqualUnmodifiableListView) return _seasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_seasons);
}

@override final  String? plot;
@override final  String? cast;
@override final  String? director;
@override final  String? genre;
@override final  String? backdropUrl;
/// When the episodes were fetched; null for an M3U source, whose
/// episodes came with the sync.
@override final  DateTime? fetchedAt;

/// Create a copy of SeriesDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SeriesDetailsCopyWith<_SeriesDetails> get copyWith => __$SeriesDetailsCopyWithImpl<_SeriesDetails>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SeriesDetails&&const DeepCollectionEquality().equals(other.seasons, _seasons)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.cast, cast) || other.cast == cast)&&(identical(other.director, director) || other.director == director)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.backdropUrl, backdropUrl) || other.backdropUrl == backdropUrl)&&(identical(other.fetchedAt, fetchedAt) || other.fetchedAt == fetchedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_seasons),plot,cast,director,genre,backdropUrl,fetchedAt);
}

@override
String toString() {
    return 'SeriesDetails(seasons: $seasons, plot: $plot, cast: $cast, director: $director, genre: $genre, backdropUrl: $backdropUrl, fetchedAt: $fetchedAt)';
}


}

/// @nodoc
abstract mixin class _$SeriesDetailsCopyWith<$Res> implements $SeriesDetailsCopyWith<$Res> {
  factory _$SeriesDetailsCopyWith(_SeriesDetails value, $Res Function(_SeriesDetails) _then) = __$SeriesDetailsCopyWithImpl;
@override @useResult
$Res call({
 List<Season> seasons, String? plot, String? cast, String? director, String? genre, String? backdropUrl, DateTime? fetchedAt
});




}
/// @nodoc
class __$SeriesDetailsCopyWithImpl<$Res>
    implements _$SeriesDetailsCopyWith<$Res> {
  __$SeriesDetailsCopyWithImpl(this._self, this._then);

  final _SeriesDetails _self;
  final $Res Function(_SeriesDetails) _then;

/// Create a copy of SeriesDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seasons = null,Object? plot = freezed,Object? cast = freezed,Object? director = freezed,Object? genre = freezed,Object? backdropUrl = freezed,Object? fetchedAt = freezed,}) {
  return _then(_SeriesDetails(
seasons: null == seasons ? _self._seasons : seasons // ignore: cast_nullable_to_non_nullable
as List<Season>,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,cast: freezed == cast ? _self.cast : cast // ignore: cast_nullable_to_non_nullable
as String?,director: freezed == director ? _self.director : director // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,backdropUrl: freezed == backdropUrl ? _self.backdropUrl : backdropUrl // ignore: cast_nullable_to_non_nullable
as String?,fetchedAt: freezed == fetchedAt ? _self.fetchedAt : fetchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
