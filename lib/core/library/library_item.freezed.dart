// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LibraryFolder {

 int get id;/// Absolute, as the system gave it.
 String get path;/// What the screens call it ("Movies HDD"): the drive's name for a
/// folder on a removable drive, else the folder's own; the user can
/// rename it.
 String get label;/// Where new downloads go. One folder at a time is; a folder that was
/// stays in the library.
 bool get isDownloadFolder;/// False while the folder can't be read (a drive unplugged): its
/// items show as "Drive not connected" (docs/09).
 bool get isAvailable; DateTime get addedAt; DateTime? get lastScanAt;
/// Create a copy of LibraryFolder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryFolderCopyWith<LibraryFolder> get copyWith => _$LibraryFolderCopyWithImpl<LibraryFolder>(this as LibraryFolder, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LibraryFolder;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryFolder&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.isDownloadFolder, _this.isDownloadFolder) || other.isDownloadFolder == _this.isDownloadFolder)&&(identical(other.isAvailable, _this.isAvailable) || other.isAvailable == _this.isAvailable)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt)&&(identical(other.lastScanAt, _this.lastScanAt) || other.lastScanAt == _this.lastScanAt));
}


@override
int get hashCode {
  final _this = this as LibraryFolder;
  return Object.hash(runtimeType,_this.id,_this.path,_this.label,_this.isDownloadFolder,_this.isAvailable,_this.addedAt,_this.lastScanAt);
}

@override
String toString() {
  final _this = this as LibraryFolder;
  return 'LibraryFolder(id: ${_this.id}, path: ${_this.path}, label: ${_this.label}, isDownloadFolder: ${_this.isDownloadFolder}, isAvailable: ${_this.isAvailable}, addedAt: ${_this.addedAt}, lastScanAt: ${_this.lastScanAt})';
}


}

/// @nodoc
abstract mixin class $LibraryFolderCopyWith<$Res>  {
  factory $LibraryFolderCopyWith(LibraryFolder value, $Res Function(LibraryFolder) _then) = _$LibraryFolderCopyWithImpl;
@useResult
$Res call({
 int id, String path, String label, bool isDownloadFolder, bool isAvailable, DateTime addedAt, DateTime? lastScanAt
});




}
/// @nodoc
class _$LibraryFolderCopyWithImpl<$Res>
    implements $LibraryFolderCopyWith<$Res> {
  _$LibraryFolderCopyWithImpl(this._self, this._then);

  final LibraryFolder _self;
  final $Res Function(LibraryFolder) _then;

/// Create a copy of LibraryFolder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? path = null,Object? label = null,Object? isDownloadFolder = null,Object? isAvailable = null,Object? addedAt = null,Object? lastScanAt = freezed,}) {
  return _then(LibraryFolder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isDownloadFolder: null == isDownloadFolder ? _self.isDownloadFolder : isDownloadFolder // ignore: cast_nullable_to_non_nullable
as bool,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastScanAt: freezed == lastScanAt ? _self.lastScanAt : lastScanAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibraryFolder].
extension LibraryFolderPatterns on LibraryFolder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryFolder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryFolder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryFolder value)  $default,){
final _that = this;
switch (_that) {
case _LibraryFolder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryFolder value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryFolder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String path,  String label,  bool isDownloadFolder,  bool isAvailable,  DateTime addedAt,  DateTime? lastScanAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryFolder() when $default != null:
return $default(_that.id,_that.path,_that.label,_that.isDownloadFolder,_that.isAvailable,_that.addedAt,_that.lastScanAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String path,  String label,  bool isDownloadFolder,  bool isAvailable,  DateTime addedAt,  DateTime? lastScanAt)  $default,) {final _that = this;
switch (_that) {
case _LibraryFolder():
return $default(_that.id,_that.path,_that.label,_that.isDownloadFolder,_that.isAvailable,_that.addedAt,_that.lastScanAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String path,  String label,  bool isDownloadFolder,  bool isAvailable,  DateTime addedAt,  DateTime? lastScanAt)?  $default,) {final _that = this;
switch (_that) {
case _LibraryFolder() when $default != null:
return $default(_that.id,_that.path,_that.label,_that.isDownloadFolder,_that.isAvailable,_that.addedAt,_that.lastScanAt);case _:
  return null;

}
}

}

/// @nodoc


class _LibraryFolder implements LibraryFolder {
  const _LibraryFolder({required this.id, required this.path, required this.label, required this.isDownloadFolder, required this.isAvailable, required this.addedAt, this.lastScanAt});
  

@override final  int id;
/// Absolute, as the system gave it.
@override final  String path;
/// What the screens call it ("Movies HDD"): the drive's name for a
/// folder on a removable drive, else the folder's own; the user can
/// rename it.
@override final  String label;
/// Where new downloads go. One folder at a time is; a folder that was
/// stays in the library.
@override final  bool isDownloadFolder;
/// False while the folder can't be read (a drive unplugged): its
/// items show as "Drive not connected" (docs/09).
@override final  bool isAvailable;
@override final  DateTime addedAt;
@override final  DateTime? lastScanAt;

/// Create a copy of LibraryFolder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryFolderCopyWith<_LibraryFolder> get copyWith => __$LibraryFolderCopyWithImpl<_LibraryFolder>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryFolder&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path)&&(identical(other.label, label) || other.label == label)&&(identical(other.isDownloadFolder, isDownloadFolder) || other.isDownloadFolder == isDownloadFolder)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt)&&(identical(other.lastScanAt, lastScanAt) || other.lastScanAt == lastScanAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,path,label,isDownloadFolder,isAvailable,addedAt,lastScanAt);
}

@override
String toString() {
    return 'LibraryFolder(id: $id, path: $path, label: $label, isDownloadFolder: $isDownloadFolder, isAvailable: $isAvailable, addedAt: $addedAt, lastScanAt: $lastScanAt)';
}


}

/// @nodoc
abstract mixin class _$LibraryFolderCopyWith<$Res> implements $LibraryFolderCopyWith<$Res> {
  factory _$LibraryFolderCopyWith(_LibraryFolder value, $Res Function(_LibraryFolder) _then) = __$LibraryFolderCopyWithImpl;
@override @useResult
$Res call({
 int id, String path, String label, bool isDownloadFolder, bool isAvailable, DateTime addedAt, DateTime? lastScanAt
});




}
/// @nodoc
class __$LibraryFolderCopyWithImpl<$Res>
    implements _$LibraryFolderCopyWith<$Res> {
  __$LibraryFolderCopyWithImpl(this._self, this._then);

  final _LibraryFolder _self;
  final $Res Function(_LibraryFolder) _then;

/// Create a copy of LibraryFolder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? path = null,Object? label = null,Object? isDownloadFolder = null,Object? isAvailable = null,Object? addedAt = null,Object? lastScanAt = freezed,}) {
  return _then(_LibraryFolder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isDownloadFolder: null == isDownloadFolder ? _self.isDownloadFolder : isDownloadFolder // ignore: cast_nullable_to_non_nullable
as bool,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastScanAt: freezed == lastScanAt ? _self.lastScanAt : lastScanAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$ExternalSubtitle {

/// Its file name, in the video's own folder.
 String get fileName;/// srt, ass, ssa or vtt.
 String get format;/// The language tag as the name has it (`en`, `eng`); null when the
/// name has none.
 String? get language; bool get forced;
/// Create a copy of ExternalSubtitle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExternalSubtitleCopyWith<ExternalSubtitle> get copyWith => _$ExternalSubtitleCopyWithImpl<ExternalSubtitle>(this as ExternalSubtitle, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ExternalSubtitle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExternalSubtitle&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.format, _this.format) || other.format == _this.format)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.forced, _this.forced) || other.forced == _this.forced));
}


@override
int get hashCode {
  final _this = this as ExternalSubtitle;
  return Object.hash(runtimeType,_this.fileName,_this.format,_this.language,_this.forced);
}

@override
String toString() {
  final _this = this as ExternalSubtitle;
  return 'ExternalSubtitle(fileName: ${_this.fileName}, format: ${_this.format}, language: ${_this.language}, forced: ${_this.forced})';
}


}

/// @nodoc
abstract mixin class $ExternalSubtitleCopyWith<$Res>  {
  factory $ExternalSubtitleCopyWith(ExternalSubtitle value, $Res Function(ExternalSubtitle) _then) = _$ExternalSubtitleCopyWithImpl;
@useResult
$Res call({
 String fileName, String format, String? language, bool forced
});




}
/// @nodoc
class _$ExternalSubtitleCopyWithImpl<$Res>
    implements $ExternalSubtitleCopyWith<$Res> {
  _$ExternalSubtitleCopyWithImpl(this._self, this._then);

  final ExternalSubtitle _self;
  final $Res Function(ExternalSubtitle) _then;

/// Create a copy of ExternalSubtitle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileName = null,Object? format = null,Object? language = freezed,Object? forced = null,}) {
  return _then(ExternalSubtitle(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,forced: null == forced ? _self.forced : forced // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ExternalSubtitle].
extension ExternalSubtitlePatterns on ExternalSubtitle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExternalSubtitle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExternalSubtitle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExternalSubtitle value)  $default,){
final _that = this;
switch (_that) {
case _ExternalSubtitle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExternalSubtitle value)?  $default,){
final _that = this;
switch (_that) {
case _ExternalSubtitle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fileName,  String format,  String? language,  bool forced)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExternalSubtitle() when $default != null:
return $default(_that.fileName,_that.format,_that.language,_that.forced);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fileName,  String format,  String? language,  bool forced)  $default,) {final _that = this;
switch (_that) {
case _ExternalSubtitle():
return $default(_that.fileName,_that.format,_that.language,_that.forced);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fileName,  String format,  String? language,  bool forced)?  $default,) {final _that = this;
switch (_that) {
case _ExternalSubtitle() when $default != null:
return $default(_that.fileName,_that.format,_that.language,_that.forced);case _:
  return null;

}
}

}

/// @nodoc


class _ExternalSubtitle implements ExternalSubtitle {
  const _ExternalSubtitle({required this.fileName, required this.format, this.language, this.forced = false});
  

/// Its file name, in the video's own folder.
@override final  String fileName;
/// srt, ass, ssa or vtt.
@override final  String format;
/// The language tag as the name has it (`en`, `eng`); null when the
/// name has none.
@override final  String? language;
@override@JsonKey() final  bool forced;

/// Create a copy of ExternalSubtitle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExternalSubtitleCopyWith<_ExternalSubtitle> get copyWith => __$ExternalSubtitleCopyWithImpl<_ExternalSubtitle>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExternalSubtitle&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.format, format) || other.format == format)&&(identical(other.language, language) || other.language == language)&&(identical(other.forced, forced) || other.forced == forced));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fileName,format,language,forced);
}

@override
String toString() {
    return 'ExternalSubtitle(fileName: $fileName, format: $format, language: $language, forced: $forced)';
}


}

/// @nodoc
abstract mixin class _$ExternalSubtitleCopyWith<$Res> implements $ExternalSubtitleCopyWith<$Res> {
  factory _$ExternalSubtitleCopyWith(_ExternalSubtitle value, $Res Function(_ExternalSubtitle) _then) = __$ExternalSubtitleCopyWithImpl;
@override @useResult
$Res call({
 String fileName, String format, String? language, bool forced
});




}
/// @nodoc
class __$ExternalSubtitleCopyWithImpl<$Res>
    implements _$ExternalSubtitleCopyWith<$Res> {
  __$ExternalSubtitleCopyWithImpl(this._self, this._then);

  final _ExternalSubtitle _self;
  final $Res Function(_ExternalSubtitle) _then;

/// Create a copy of ExternalSubtitle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileName = null,Object? format = null,Object? language = freezed,Object? forced = null,}) {
  return _then(_ExternalSubtitle(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,forced: null == forced ? _self.forced : forced // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ProviderLink {

 String get sourceId; VodType get type; String get remoteKey;/// An episode's series (its remote key).
 String? get seriesKey;
/// Create a copy of ProviderLink
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderLinkCopyWith<ProviderLink> get copyWith => _$ProviderLinkCopyWithImpl<ProviderLink>(this as ProviderLink, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProviderLink;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderLink&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.remoteKey, _this.remoteKey) || other.remoteKey == _this.remoteKey)&&(identical(other.seriesKey, _this.seriesKey) || other.seriesKey == _this.seriesKey));
}


@override
int get hashCode {
  final _this = this as ProviderLink;
  return Object.hash(runtimeType,_this.sourceId,_this.type,_this.remoteKey,_this.seriesKey);
}

@override
String toString() {
  final _this = this as ProviderLink;
  return 'ProviderLink(sourceId: ${_this.sourceId}, type: ${_this.type}, remoteKey: ${_this.remoteKey}, seriesKey: ${_this.seriesKey})';
}


}

/// @nodoc
abstract mixin class $ProviderLinkCopyWith<$Res>  {
  factory $ProviderLinkCopyWith(ProviderLink value, $Res Function(ProviderLink) _then) = _$ProviderLinkCopyWithImpl;
@useResult
$Res call({
 String sourceId, VodType type, String remoteKey, String? seriesKey
});




}
/// @nodoc
class _$ProviderLinkCopyWithImpl<$Res>
    implements $ProviderLinkCopyWith<$Res> {
  _$ProviderLinkCopyWithImpl(this._self, this._then);

  final ProviderLink _self;
  final $Res Function(ProviderLink) _then;

/// Create a copy of ProviderLink
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? type = null,Object? remoteKey = null,Object? seriesKey = freezed,}) {
  return _then(ProviderLink(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VodType,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,seriesKey: freezed == seriesKey ? _self.seriesKey : seriesKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderLink].
extension ProviderLinkPatterns on ProviderLink {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderLink value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderLink() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderLink value)  $default,){
final _that = this;
switch (_that) {
case _ProviderLink():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderLink value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderLink() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceId,  VodType type,  String remoteKey,  String? seriesKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderLink() when $default != null:
return $default(_that.sourceId,_that.type,_that.remoteKey,_that.seriesKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceId,  VodType type,  String remoteKey,  String? seriesKey)  $default,) {final _that = this;
switch (_that) {
case _ProviderLink():
return $default(_that.sourceId,_that.type,_that.remoteKey,_that.seriesKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceId,  VodType type,  String remoteKey,  String? seriesKey)?  $default,) {final _that = this;
switch (_that) {
case _ProviderLink() when $default != null:
return $default(_that.sourceId,_that.type,_that.remoteKey,_that.seriesKey);case _:
  return null;

}
}

}

/// @nodoc


class _ProviderLink implements ProviderLink {
  const _ProviderLink({required this.sourceId, required this.type, required this.remoteKey, this.seriesKey});
  

@override final  String sourceId;
@override final  VodType type;
@override final  String remoteKey;
/// An episode's series (its remote key).
@override final  String? seriesKey;

/// Create a copy of ProviderLink
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderLinkCopyWith<_ProviderLink> get copyWith => __$ProviderLinkCopyWithImpl<_ProviderLink>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderLink&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.type, type) || other.type == type)&&(identical(other.remoteKey, remoteKey) || other.remoteKey == remoteKey)&&(identical(other.seriesKey, seriesKey) || other.seriesKey == seriesKey));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceId,type,remoteKey,seriesKey);
}

@override
String toString() {
    return 'ProviderLink(sourceId: $sourceId, type: $type, remoteKey: $remoteKey, seriesKey: $seriesKey)';
}


}

/// @nodoc
abstract mixin class _$ProviderLinkCopyWith<$Res> implements $ProviderLinkCopyWith<$Res> {
  factory _$ProviderLinkCopyWith(_ProviderLink value, $Res Function(_ProviderLink) _then) = __$ProviderLinkCopyWithImpl;
@override @useResult
$Res call({
 String sourceId, VodType type, String remoteKey, String? seriesKey
});




}
/// @nodoc
class __$ProviderLinkCopyWithImpl<$Res>
    implements _$ProviderLinkCopyWith<$Res> {
  __$ProviderLinkCopyWithImpl(this._self, this._then);

  final _ProviderLink _self;
  final $Res Function(_ProviderLink) _then;

/// Create a copy of ProviderLink
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? type = null,Object? remoteKey = null,Object? seriesKey = freezed,}) {
  return _then(_ProviderLink(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VodType,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,seriesKey: freezed == seriesKey ? _self.seriesKey : seriesKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$LibraryItemEdit {

 LibraryKind get kind; String get title; int? get year; String? get showTitle; int? get season; int? get episode;
/// Create a copy of LibraryItemEdit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryItemEditCopyWith<LibraryItemEdit> get copyWith => _$LibraryItemEditCopyWithImpl<LibraryItemEdit>(this as LibraryItemEdit, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LibraryItemEdit;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryItemEdit&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.showTitle, _this.showTitle) || other.showTitle == _this.showTitle)&&(identical(other.season, _this.season) || other.season == _this.season)&&(identical(other.episode, _this.episode) || other.episode == _this.episode));
}


@override
int get hashCode {
  final _this = this as LibraryItemEdit;
  return Object.hash(runtimeType,_this.kind,_this.title,_this.year,_this.showTitle,_this.season,_this.episode);
}

@override
String toString() {
  final _this = this as LibraryItemEdit;
  return 'LibraryItemEdit(kind: ${_this.kind}, title: ${_this.title}, year: ${_this.year}, showTitle: ${_this.showTitle}, season: ${_this.season}, episode: ${_this.episode})';
}


}

/// @nodoc
abstract mixin class $LibraryItemEditCopyWith<$Res>  {
  factory $LibraryItemEditCopyWith(LibraryItemEdit value, $Res Function(LibraryItemEdit) _then) = _$LibraryItemEditCopyWithImpl;
@useResult
$Res call({
 LibraryKind kind, String title, int? year, String? showTitle, int? season, int? episode
});




}
/// @nodoc
class _$LibraryItemEditCopyWithImpl<$Res>
    implements $LibraryItemEditCopyWith<$Res> {
  _$LibraryItemEditCopyWithImpl(this._self, this._then);

  final LibraryItemEdit _self;
  final $Res Function(LibraryItemEdit) _then;

/// Create a copy of LibraryItemEdit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? title = null,Object? year = freezed,Object? showTitle = freezed,Object? season = freezed,Object? episode = freezed,}) {
  return _then(LibraryItemEdit(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LibraryKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,showTitle: freezed == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibraryItemEdit].
extension LibraryItemEditPatterns on LibraryItemEdit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryItemEdit value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryItemEdit() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryItemEdit value)  $default,){
final _that = this;
switch (_that) {
case _LibraryItemEdit():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryItemEdit value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryItemEdit() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LibraryKind kind,  String title,  int? year,  String? showTitle,  int? season,  int? episode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryItemEdit() when $default != null:
return $default(_that.kind,_that.title,_that.year,_that.showTitle,_that.season,_that.episode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LibraryKind kind,  String title,  int? year,  String? showTitle,  int? season,  int? episode)  $default,) {final _that = this;
switch (_that) {
case _LibraryItemEdit():
return $default(_that.kind,_that.title,_that.year,_that.showTitle,_that.season,_that.episode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LibraryKind kind,  String title,  int? year,  String? showTitle,  int? season,  int? episode)?  $default,) {final _that = this;
switch (_that) {
case _LibraryItemEdit() when $default != null:
return $default(_that.kind,_that.title,_that.year,_that.showTitle,_that.season,_that.episode);case _:
  return null;

}
}

}

/// @nodoc


class _LibraryItemEdit extends LibraryItemEdit {
  const _LibraryItemEdit({required this.kind, required this.title, this.year, this.showTitle, this.season, this.episode}): super._();
  

@override final  LibraryKind kind;
@override final  String title;
@override final  int? year;
@override final  String? showTitle;
@override final  int? season;
@override final  int? episode;

/// Create a copy of LibraryItemEdit
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryItemEditCopyWith<_LibraryItemEdit> get copyWith => __$LibraryItemEditCopyWithImpl<_LibraryItemEdit>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryItemEdit&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.year, year) || other.year == year)&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.season, season) || other.season == season)&&(identical(other.episode, episode) || other.episode == episode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,title,year,showTitle,season,episode);
}

@override
String toString() {
    return 'LibraryItemEdit(kind: $kind, title: $title, year: $year, showTitle: $showTitle, season: $season, episode: $episode)';
}


}

/// @nodoc
abstract mixin class _$LibraryItemEditCopyWith<$Res> implements $LibraryItemEditCopyWith<$Res> {
  factory _$LibraryItemEditCopyWith(_LibraryItemEdit value, $Res Function(_LibraryItemEdit) _then) = __$LibraryItemEditCopyWithImpl;
@override @useResult
$Res call({
 LibraryKind kind, String title, int? year, String? showTitle, int? season, int? episode
});




}
/// @nodoc
class __$LibraryItemEditCopyWithImpl<$Res>
    implements _$LibraryItemEditCopyWith<$Res> {
  __$LibraryItemEditCopyWithImpl(this._self, this._then);

  final _LibraryItemEdit _self;
  final $Res Function(_LibraryItemEdit) _then;

/// Create a copy of LibraryItemEdit
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? title = null,Object? year = freezed,Object? showTitle = freezed,Object? season = freezed,Object? episode = freezed,}) {
  return _then(_LibraryItemEdit(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LibraryKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,showTitle: freezed == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$LibraryItem {

 int get id; int get folderId;/// Inside its folder, with `/` between parts on every system.
 String get relPath; int get sizeBytes; DateTime get modifiedAt;/// Size + the first and last 64 KB (docs/09): history, favorites and
/// edits follow a file across renames and moves by it.
 String get quickHash; LibraryKind get kind; String get title; DateTime get addedAt; int? get year; String? get showTitle; int? get season; int? get episode;/// The last episode of a file holding several (`S02E04E05`).
 int? get episodeEnd;/// Null until the file was probed.
 Duration? get duration; String? get thumbnailPath; String? get artworkPath; List<ExternalSubtitle> get subtitles;/// What the user set, when anything.
 LibraryItemEdit? get edit;/// Set for a download.
 ProviderLink? get provider; bool get hidden;/// When its folder stopped being readable; the item goes 30 days
/// later (docs/09).
 DateTime? get unavailableSince;/// The file, absolute.
 String? get path;/// What ffprobe said of it; null until the scanner's probe pass.
 LibraryMedia? get media;/// A download's copy of its title's details (Phase 8 decision 5).
 Map<String, Object?>? get details;/// Downloaded from a source (it may since have been removed).
 bool get downloaded;
/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryItemCopyWith<LibraryItem> get copyWith => _$LibraryItemCopyWithImpl<LibraryItem>(this as LibraryItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LibraryItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.folderId, _this.folderId) || other.folderId == _this.folderId)&&(identical(other.relPath, _this.relPath) || other.relPath == _this.relPath)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes)&&(identical(other.modifiedAt, _this.modifiedAt) || other.modifiedAt == _this.modifiedAt)&&(identical(other.quickHash, _this.quickHash) || other.quickHash == _this.quickHash)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.showTitle, _this.showTitle) || other.showTitle == _this.showTitle)&&(identical(other.season, _this.season) || other.season == _this.season)&&(identical(other.episode, _this.episode) || other.episode == _this.episode)&&(identical(other.episodeEnd, _this.episodeEnd) || other.episodeEnd == _this.episodeEnd)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.thumbnailPath, _this.thumbnailPath) || other.thumbnailPath == _this.thumbnailPath)&&(identical(other.artworkPath, _this.artworkPath) || other.artworkPath == _this.artworkPath)&&const DeepCollectionEquality().equals(other.subtitles, _this.subtitles)&&(identical(other.edit, _this.edit) || other.edit == _this.edit)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.hidden, _this.hidden) || other.hidden == _this.hidden)&&(identical(other.unavailableSince, _this.unavailableSince) || other.unavailableSince == _this.unavailableSince)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.media, _this.media) || other.media == _this.media)&&const DeepCollectionEquality().equals(other.details, _this.details)&&(identical(other.downloaded, _this.downloaded) || other.downloaded == _this.downloaded));
}


@override
int get hashCode {
  final _this = this as LibraryItem;
  return Object.hashAll([runtimeType,_this.id,_this.folderId,_this.relPath,_this.sizeBytes,_this.modifiedAt,_this.quickHash,_this.kind,_this.title,_this.addedAt,_this.year,_this.showTitle,_this.season,_this.episode,_this.episodeEnd,_this.duration,_this.thumbnailPath,_this.artworkPath,const DeepCollectionEquality().hash(_this.subtitles),_this.edit,_this.provider,_this.hidden,_this.unavailableSince,_this.path,_this.media,const DeepCollectionEquality().hash(_this.details),_this.downloaded]);
}

@override
String toString() {
  final _this = this as LibraryItem;
  return 'LibraryItem(id: ${_this.id}, folderId: ${_this.folderId}, relPath: ${_this.relPath}, sizeBytes: ${_this.sizeBytes}, modifiedAt: ${_this.modifiedAt}, quickHash: ${_this.quickHash}, kind: ${_this.kind}, title: ${_this.title}, addedAt: ${_this.addedAt}, year: ${_this.year}, showTitle: ${_this.showTitle}, season: ${_this.season}, episode: ${_this.episode}, episodeEnd: ${_this.episodeEnd}, duration: ${_this.duration}, thumbnailPath: ${_this.thumbnailPath}, artworkPath: ${_this.artworkPath}, subtitles: ${_this.subtitles}, edit: ${_this.edit}, provider: ${_this.provider}, hidden: ${_this.hidden}, unavailableSince: ${_this.unavailableSince}, path: ${_this.path}, media: ${_this.media}, details: ${_this.details}, downloaded: ${_this.downloaded})';
}


}

/// @nodoc
abstract mixin class $LibraryItemCopyWith<$Res>  {
  factory $LibraryItemCopyWith(LibraryItem value, $Res Function(LibraryItem) _then) = _$LibraryItemCopyWithImpl;
@useResult
$Res call({
 int id, int folderId, String relPath, int sizeBytes, DateTime modifiedAt, String quickHash, LibraryKind kind, String title, DateTime addedAt, int? year, String? showTitle, int? season, int? episode, int? episodeEnd, Duration? duration, String? thumbnailPath, String? artworkPath, List<ExternalSubtitle> subtitles, LibraryItemEdit? edit, ProviderLink? provider, bool hidden, DateTime? unavailableSince, String? path, LibraryMedia? media, Map<String, Object?>? details, bool downloaded
});


$LibraryItemEditCopyWith<$Res>? get edit;$ProviderLinkCopyWith<$Res>? get provider;

}
/// @nodoc
class _$LibraryItemCopyWithImpl<$Res>
    implements $LibraryItemCopyWith<$Res> {
  _$LibraryItemCopyWithImpl(this._self, this._then);

  final LibraryItem _self;
  final $Res Function(LibraryItem) _then;

/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? folderId = null,Object? relPath = null,Object? sizeBytes = null,Object? modifiedAt = null,Object? quickHash = null,Object? kind = null,Object? title = null,Object? addedAt = null,Object? year = freezed,Object? showTitle = freezed,Object? season = freezed,Object? episode = freezed,Object? episodeEnd = freezed,Object? duration = freezed,Object? thumbnailPath = freezed,Object? artworkPath = freezed,Object? subtitles = null,Object? edit = freezed,Object? provider = freezed,Object? hidden = null,Object? unavailableSince = freezed,Object? path = freezed,Object? media = freezed,Object? details = freezed,Object? downloaded = null,}) {
  return _then(LibraryItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,folderId: null == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as int,relPath: null == relPath ? _self.relPath : relPath // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,quickHash: null == quickHash ? _self.quickHash : quickHash // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LibraryKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,showTitle: freezed == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,episodeEnd: freezed == episodeEnd ? _self.episodeEnd : episodeEnd // ignore: cast_nullable_to_non_nullable
as int?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,thumbnailPath: freezed == thumbnailPath ? _self.thumbnailPath : thumbnailPath // ignore: cast_nullable_to_non_nullable
as String?,artworkPath: freezed == artworkPath ? _self.artworkPath : artworkPath // ignore: cast_nullable_to_non_nullable
as String?,subtitles: null == subtitles ? _self.subtitles : subtitles // ignore: cast_nullable_to_non_nullable
as List<ExternalSubtitle>,edit: freezed == edit ? _self.edit : edit // ignore: cast_nullable_to_non_nullable
as LibraryItemEdit?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as ProviderLink?,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,unavailableSince: freezed == unavailableSince ? _self.unavailableSince : unavailableSince // ignore: cast_nullable_to_non_nullable
as DateTime?,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as LibraryMedia?,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>?,downloaded: null == downloaded ? _self.downloaded : downloaded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibraryItemEditCopyWith<$Res>? get edit {
    if (_self.edit == null) {
    return null;
  }

  return $LibraryItemEditCopyWith<$Res>(_self.edit!, (value) {
    return _then(_self.copyWith(edit: value));
  });
}/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderLinkCopyWith<$Res>? get provider {
    if (_self.provider == null) {
    return null;
  }

  return $ProviderLinkCopyWith<$Res>(_self.provider!, (value) {
    return _then(_self.copyWith(provider: value));
  });
}
}


/// Adds pattern-matching-related methods to [LibraryItem].
extension LibraryItemPatterns on LibraryItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryItem value)  $default,){
final _that = this;
switch (_that) {
case _LibraryItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryItem value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int folderId,  String relPath,  int sizeBytes,  DateTime modifiedAt,  String quickHash,  LibraryKind kind,  String title,  DateTime addedAt,  int? year,  String? showTitle,  int? season,  int? episode,  int? episodeEnd,  Duration? duration,  String? thumbnailPath,  String? artworkPath,  List<ExternalSubtitle> subtitles,  LibraryItemEdit? edit,  ProviderLink? provider,  bool hidden,  DateTime? unavailableSince,  String? path,  LibraryMedia? media,  Map<String, Object?>? details,  bool downloaded)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryItem() when $default != null:
return $default(_that.id,_that.folderId,_that.relPath,_that.sizeBytes,_that.modifiedAt,_that.quickHash,_that.kind,_that.title,_that.addedAt,_that.year,_that.showTitle,_that.season,_that.episode,_that.episodeEnd,_that.duration,_that.thumbnailPath,_that.artworkPath,_that.subtitles,_that.edit,_that.provider,_that.hidden,_that.unavailableSince,_that.path,_that.media,_that.details,_that.downloaded);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int folderId,  String relPath,  int sizeBytes,  DateTime modifiedAt,  String quickHash,  LibraryKind kind,  String title,  DateTime addedAt,  int? year,  String? showTitle,  int? season,  int? episode,  int? episodeEnd,  Duration? duration,  String? thumbnailPath,  String? artworkPath,  List<ExternalSubtitle> subtitles,  LibraryItemEdit? edit,  ProviderLink? provider,  bool hidden,  DateTime? unavailableSince,  String? path,  LibraryMedia? media,  Map<String, Object?>? details,  bool downloaded)  $default,) {final _that = this;
switch (_that) {
case _LibraryItem():
return $default(_that.id,_that.folderId,_that.relPath,_that.sizeBytes,_that.modifiedAt,_that.quickHash,_that.kind,_that.title,_that.addedAt,_that.year,_that.showTitle,_that.season,_that.episode,_that.episodeEnd,_that.duration,_that.thumbnailPath,_that.artworkPath,_that.subtitles,_that.edit,_that.provider,_that.hidden,_that.unavailableSince,_that.path,_that.media,_that.details,_that.downloaded);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int folderId,  String relPath,  int sizeBytes,  DateTime modifiedAt,  String quickHash,  LibraryKind kind,  String title,  DateTime addedAt,  int? year,  String? showTitle,  int? season,  int? episode,  int? episodeEnd,  Duration? duration,  String? thumbnailPath,  String? artworkPath,  List<ExternalSubtitle> subtitles,  LibraryItemEdit? edit,  ProviderLink? provider,  bool hidden,  DateTime? unavailableSince,  String? path,  LibraryMedia? media,  Map<String, Object?>? details,  bool downloaded)?  $default,) {final _that = this;
switch (_that) {
case _LibraryItem() when $default != null:
return $default(_that.id,_that.folderId,_that.relPath,_that.sizeBytes,_that.modifiedAt,_that.quickHash,_that.kind,_that.title,_that.addedAt,_that.year,_that.showTitle,_that.season,_that.episode,_that.episodeEnd,_that.duration,_that.thumbnailPath,_that.artworkPath,_that.subtitles,_that.edit,_that.provider,_that.hidden,_that.unavailableSince,_that.path,_that.media,_that.details,_that.downloaded);case _:
  return null;

}
}

}

/// @nodoc


class _LibraryItem extends LibraryItem {
  const _LibraryItem({required this.id, required this.folderId, required this.relPath, required this.sizeBytes, required this.modifiedAt, required this.quickHash, required this.kind, required this.title, required this.addedAt, this.year, this.showTitle, this.season, this.episode, this.episodeEnd, this.duration, this.thumbnailPath, this.artworkPath,  List<ExternalSubtitle> subtitles = const <ExternalSubtitle>[], this.edit, this.provider, this.hidden = false, this.unavailableSince, this.path, this.media,  Map<String, Object?>? details, this.downloaded = false}): _subtitles = subtitles,_details = details,super._();
  

@override final  int id;
@override final  int folderId;
/// Inside its folder, with `/` between parts on every system.
@override final  String relPath;
@override final  int sizeBytes;
@override final  DateTime modifiedAt;
/// Size + the first and last 64 KB (docs/09): history, favorites and
/// edits follow a file across renames and moves by it.
@override final  String quickHash;
@override final  LibraryKind kind;
@override final  String title;
@override final  DateTime addedAt;
@override final  int? year;
@override final  String? showTitle;
@override final  int? season;
@override final  int? episode;
/// The last episode of a file holding several (`S02E04E05`).
@override final  int? episodeEnd;
/// Null until the file was probed.
@override final  Duration? duration;
@override final  String? thumbnailPath;
@override final  String? artworkPath;
 final  List<ExternalSubtitle> _subtitles;
@override@JsonKey() List<ExternalSubtitle> get subtitles {
  if (_subtitles is EqualUnmodifiableListView) return _subtitles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subtitles);
}

/// What the user set, when anything.
@override final  LibraryItemEdit? edit;
/// Set for a download.
@override final  ProviderLink? provider;
@override@JsonKey() final  bool hidden;
/// When its folder stopped being readable; the item goes 30 days
/// later (docs/09).
@override final  DateTime? unavailableSince;
/// The file, absolute.
@override final  String? path;
/// What ffprobe said of it; null until the scanner's probe pass.
@override final  LibraryMedia? media;
/// A download's copy of its title's details (Phase 8 decision 5).
 final  Map<String, Object?>? _details;
/// A download's copy of its title's details (Phase 8 decision 5).
@override Map<String, Object?>? get details {
  final value = _details;
  if (value == null) return null;
  if (_details is EqualUnmodifiableMapView) return _details;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// Downloaded from a source (it may since have been removed).
@override@JsonKey() final  bool downloaded;

/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryItemCopyWith<_LibraryItem> get copyWith => __$LibraryItemCopyWithImpl<_LibraryItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.folderId, folderId) || other.folderId == folderId)&&(identical(other.relPath, relPath) || other.relPath == relPath)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt)&&(identical(other.quickHash, quickHash) || other.quickHash == quickHash)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt)&&(identical(other.year, year) || other.year == year)&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.season, season) || other.season == season)&&(identical(other.episode, episode) || other.episode == episode)&&(identical(other.episodeEnd, episodeEnd) || other.episodeEnd == episodeEnd)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.thumbnailPath, thumbnailPath) || other.thumbnailPath == thumbnailPath)&&(identical(other.artworkPath, artworkPath) || other.artworkPath == artworkPath)&&const DeepCollectionEquality().equals(other.subtitles, _subtitles)&&(identical(other.edit, edit) || other.edit == edit)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.hidden, hidden) || other.hidden == hidden)&&(identical(other.unavailableSince, unavailableSince) || other.unavailableSince == unavailableSince)&&(identical(other.path, path) || other.path == path)&&(identical(other.media, media) || other.media == media)&&const DeepCollectionEquality().equals(other.details, _details)&&(identical(other.downloaded, downloaded) || other.downloaded == downloaded));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,folderId,relPath,sizeBytes,modifiedAt,quickHash,kind,title,addedAt,year,showTitle,season,episode,episodeEnd,duration,thumbnailPath,artworkPath,const DeepCollectionEquality().hash(_subtitles),edit,provider,hidden,unavailableSince,path,media,const DeepCollectionEquality().hash(_details),downloaded]);
}

@override
String toString() {
    return 'LibraryItem(id: $id, folderId: $folderId, relPath: $relPath, sizeBytes: $sizeBytes, modifiedAt: $modifiedAt, quickHash: $quickHash, kind: $kind, title: $title, addedAt: $addedAt, year: $year, showTitle: $showTitle, season: $season, episode: $episode, episodeEnd: $episodeEnd, duration: $duration, thumbnailPath: $thumbnailPath, artworkPath: $artworkPath, subtitles: $subtitles, edit: $edit, provider: $provider, hidden: $hidden, unavailableSince: $unavailableSince, path: $path, media: $media, details: $details, downloaded: $downloaded)';
}


}

/// @nodoc
abstract mixin class _$LibraryItemCopyWith<$Res> implements $LibraryItemCopyWith<$Res> {
  factory _$LibraryItemCopyWith(_LibraryItem value, $Res Function(_LibraryItem) _then) = __$LibraryItemCopyWithImpl;
@override @useResult
$Res call({
 int id, int folderId, String relPath, int sizeBytes, DateTime modifiedAt, String quickHash, LibraryKind kind, String title, DateTime addedAt, int? year, String? showTitle, int? season, int? episode, int? episodeEnd, Duration? duration, String? thumbnailPath, String? artworkPath, List<ExternalSubtitle> subtitles, LibraryItemEdit? edit, ProviderLink? provider, bool hidden, DateTime? unavailableSince, String? path, LibraryMedia? media, Map<String, Object?>? details, bool downloaded
});


@override $LibraryItemEditCopyWith<$Res>? get edit;@override $ProviderLinkCopyWith<$Res>? get provider;

}
/// @nodoc
class __$LibraryItemCopyWithImpl<$Res>
    implements _$LibraryItemCopyWith<$Res> {
  __$LibraryItemCopyWithImpl(this._self, this._then);

  final _LibraryItem _self;
  final $Res Function(_LibraryItem) _then;

/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? folderId = null,Object? relPath = null,Object? sizeBytes = null,Object? modifiedAt = null,Object? quickHash = null,Object? kind = null,Object? title = null,Object? addedAt = null,Object? year = freezed,Object? showTitle = freezed,Object? season = freezed,Object? episode = freezed,Object? episodeEnd = freezed,Object? duration = freezed,Object? thumbnailPath = freezed,Object? artworkPath = freezed,Object? subtitles = null,Object? edit = freezed,Object? provider = freezed,Object? hidden = null,Object? unavailableSince = freezed,Object? path = freezed,Object? media = freezed,Object? details = freezed,Object? downloaded = null,}) {
  return _then(_LibraryItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,folderId: null == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as int,relPath: null == relPath ? _self.relPath : relPath // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,modifiedAt: null == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime,quickHash: null == quickHash ? _self.quickHash : quickHash // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LibraryKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,showTitle: freezed == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,episodeEnd: freezed == episodeEnd ? _self.episodeEnd : episodeEnd // ignore: cast_nullable_to_non_nullable
as int?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,thumbnailPath: freezed == thumbnailPath ? _self.thumbnailPath : thumbnailPath // ignore: cast_nullable_to_non_nullable
as String?,artworkPath: freezed == artworkPath ? _self.artworkPath : artworkPath // ignore: cast_nullable_to_non_nullable
as String?,subtitles: null == subtitles ? _self._subtitles : subtitles // ignore: cast_nullable_to_non_nullable
as List<ExternalSubtitle>,edit: freezed == edit ? _self.edit : edit // ignore: cast_nullable_to_non_nullable
as LibraryItemEdit?,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as ProviderLink?,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,unavailableSince: freezed == unavailableSince ? _self.unavailableSince : unavailableSince // ignore: cast_nullable_to_non_nullable
as DateTime?,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as LibraryMedia?,details: freezed == details ? _self._details : details // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>?,downloaded: null == downloaded ? _self.downloaded : downloaded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibraryItemEditCopyWith<$Res>? get edit {
    if (_self.edit == null) {
    return null;
  }

  return $LibraryItemEditCopyWith<$Res>(_self.edit!, (value) {
    return _then(_self.copyWith(edit: value));
  });
}/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderLinkCopyWith<$Res>? get provider {
    if (_self.provider == null) {
    return null;
  }

  return $ProviderLinkCopyWith<$Res>(_self.provider!, (value) {
    return _then(_self.copyWith(provider: value));
  });
}
}

// dart format on
