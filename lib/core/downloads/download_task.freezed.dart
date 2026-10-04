// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'download_task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DownloadTask {

 int get id; String get sourceId; VodType get type;/// The movie's or the episode's key at its source.
 String get remoteKey;/// A movie's title, or an episode's own.
 String get title;/// The file it becomes, absolute; `<targetPath>.part` until it is
/// verified (hard rule 11).
 String get targetPath; DownloadTaskState get state; int get downloadedBytes;/// Its place in the queue: lower runs first.
 int get sortOrder; DateTime get createdAt; int? get year;/// An episode's series: its key and its name.
 String? get seriesKey; String? get showTitle; int? get season; int? get episode; String? get artworkUrl;/// The whole file's size, once the provider said.
 int? get totalBytes; DownloadProblem? get problem;/// The problem's technical detail, redacted, for Details.
 String? get problemDetail;/// Tries since the last progress.
 int get attempts;/// The library item it became.
 int? get libraryItemId; DateTime? get completedAt;/// Bytes a second right now, while it runs (not stored).
 double? get speed;
/// Create a copy of DownloadTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadTaskCopyWith<DownloadTask> get copyWith => _$DownloadTaskCopyWithImpl<DownloadTask>(this as DownloadTask, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DownloadTask;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadTask&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.remoteKey, _this.remoteKey) || other.remoteKey == _this.remoteKey)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.targetPath, _this.targetPath) || other.targetPath == _this.targetPath)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.downloadedBytes, _this.downloadedBytes) || other.downloadedBytes == _this.downloadedBytes)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.seriesKey, _this.seriesKey) || other.seriesKey == _this.seriesKey)&&(identical(other.showTitle, _this.showTitle) || other.showTitle == _this.showTitle)&&(identical(other.season, _this.season) || other.season == _this.season)&&(identical(other.episode, _this.episode) || other.episode == _this.episode)&&(identical(other.artworkUrl, _this.artworkUrl) || other.artworkUrl == _this.artworkUrl)&&(identical(other.totalBytes, _this.totalBytes) || other.totalBytes == _this.totalBytes)&&(identical(other.problem, _this.problem) || other.problem == _this.problem)&&(identical(other.problemDetail, _this.problemDetail) || other.problemDetail == _this.problemDetail)&&(identical(other.attempts, _this.attempts) || other.attempts == _this.attempts)&&(identical(other.libraryItemId, _this.libraryItemId) || other.libraryItemId == _this.libraryItemId)&&(identical(other.completedAt, _this.completedAt) || other.completedAt == _this.completedAt)&&(identical(other.speed, _this.speed) || other.speed == _this.speed));
}


@override
int get hashCode {
  final _this = this as DownloadTask;
  return Object.hashAll([runtimeType,_this.id,_this.sourceId,_this.type,_this.remoteKey,_this.title,_this.targetPath,_this.state,_this.downloadedBytes,_this.sortOrder,_this.createdAt,_this.year,_this.seriesKey,_this.showTitle,_this.season,_this.episode,_this.artworkUrl,_this.totalBytes,_this.problem,_this.problemDetail,_this.attempts,_this.libraryItemId,_this.completedAt,_this.speed]);
}

@override
String toString() {
  final _this = this as DownloadTask;
  return 'DownloadTask(id: ${_this.id}, sourceId: ${_this.sourceId}, type: ${_this.type}, remoteKey: ${_this.remoteKey}, title: ${_this.title}, targetPath: ${_this.targetPath}, state: ${_this.state}, downloadedBytes: ${_this.downloadedBytes}, sortOrder: ${_this.sortOrder}, createdAt: ${_this.createdAt}, year: ${_this.year}, seriesKey: ${_this.seriesKey}, showTitle: ${_this.showTitle}, season: ${_this.season}, episode: ${_this.episode}, artworkUrl: ${_this.artworkUrl}, totalBytes: ${_this.totalBytes}, problem: ${_this.problem}, problemDetail: ${_this.problemDetail}, attempts: ${_this.attempts}, libraryItemId: ${_this.libraryItemId}, completedAt: ${_this.completedAt}, speed: ${_this.speed})';
}


}

/// @nodoc
abstract mixin class $DownloadTaskCopyWith<$Res>  {
  factory $DownloadTaskCopyWith(DownloadTask value, $Res Function(DownloadTask) _then) = _$DownloadTaskCopyWithImpl;
@useResult
$Res call({
 int id, String sourceId, VodType type, String remoteKey, String title, String targetPath, DownloadTaskState state, int downloadedBytes, int sortOrder, DateTime createdAt, int? year, String? seriesKey, String? showTitle, int? season, int? episode, String? artworkUrl, int? totalBytes, DownloadProblem? problem, String? problemDetail, int attempts, int? libraryItemId, DateTime? completedAt, double? speed
});




}
/// @nodoc
class _$DownloadTaskCopyWithImpl<$Res>
    implements $DownloadTaskCopyWith<$Res> {
  _$DownloadTaskCopyWithImpl(this._self, this._then);

  final DownloadTask _self;
  final $Res Function(DownloadTask) _then;

/// Create a copy of DownloadTask
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceId = null,Object? type = null,Object? remoteKey = null,Object? title = null,Object? targetPath = null,Object? state = null,Object? downloadedBytes = null,Object? sortOrder = null,Object? createdAt = null,Object? year = freezed,Object? seriesKey = freezed,Object? showTitle = freezed,Object? season = freezed,Object? episode = freezed,Object? artworkUrl = freezed,Object? totalBytes = freezed,Object? problem = freezed,Object? problemDetail = freezed,Object? attempts = null,Object? libraryItemId = freezed,Object? completedAt = freezed,Object? speed = freezed,}) {
  return _then(DownloadTask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VodType,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,targetPath: null == targetPath ? _self.targetPath : targetPath // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as DownloadTaskState,downloadedBytes: null == downloadedBytes ? _self.downloadedBytes : downloadedBytes // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,seriesKey: freezed == seriesKey ? _self.seriesKey : seriesKey // ignore: cast_nullable_to_non_nullable
as String?,showTitle: freezed == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,totalBytes: freezed == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int?,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as DownloadProblem?,problemDetail: freezed == problemDetail ? _self.problemDetail : problemDetail // ignore: cast_nullable_to_non_nullable
as String?,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,libraryItemId: freezed == libraryItemId ? _self.libraryItemId : libraryItemId // ignore: cast_nullable_to_non_nullable
as int?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [DownloadTask].
extension DownloadTaskPatterns on DownloadTask {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadTask value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadTask() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadTask value)  $default,){
final _that = this;
switch (_that) {
case _DownloadTask():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadTask value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadTask() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String sourceId,  VodType type,  String remoteKey,  String title,  String targetPath,  DownloadTaskState state,  int downloadedBytes,  int sortOrder,  DateTime createdAt,  int? year,  String? seriesKey,  String? showTitle,  int? season,  int? episode,  String? artworkUrl,  int? totalBytes,  DownloadProblem? problem,  String? problemDetail,  int attempts,  int? libraryItemId,  DateTime? completedAt,  double? speed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadTask() when $default != null:
return $default(_that.id,_that.sourceId,_that.type,_that.remoteKey,_that.title,_that.targetPath,_that.state,_that.downloadedBytes,_that.sortOrder,_that.createdAt,_that.year,_that.seriesKey,_that.showTitle,_that.season,_that.episode,_that.artworkUrl,_that.totalBytes,_that.problem,_that.problemDetail,_that.attempts,_that.libraryItemId,_that.completedAt,_that.speed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String sourceId,  VodType type,  String remoteKey,  String title,  String targetPath,  DownloadTaskState state,  int downloadedBytes,  int sortOrder,  DateTime createdAt,  int? year,  String? seriesKey,  String? showTitle,  int? season,  int? episode,  String? artworkUrl,  int? totalBytes,  DownloadProblem? problem,  String? problemDetail,  int attempts,  int? libraryItemId,  DateTime? completedAt,  double? speed)  $default,) {final _that = this;
switch (_that) {
case _DownloadTask():
return $default(_that.id,_that.sourceId,_that.type,_that.remoteKey,_that.title,_that.targetPath,_that.state,_that.downloadedBytes,_that.sortOrder,_that.createdAt,_that.year,_that.seriesKey,_that.showTitle,_that.season,_that.episode,_that.artworkUrl,_that.totalBytes,_that.problem,_that.problemDetail,_that.attempts,_that.libraryItemId,_that.completedAt,_that.speed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String sourceId,  VodType type,  String remoteKey,  String title,  String targetPath,  DownloadTaskState state,  int downloadedBytes,  int sortOrder,  DateTime createdAt,  int? year,  String? seriesKey,  String? showTitle,  int? season,  int? episode,  String? artworkUrl,  int? totalBytes,  DownloadProblem? problem,  String? problemDetail,  int attempts,  int? libraryItemId,  DateTime? completedAt,  double? speed)?  $default,) {final _that = this;
switch (_that) {
case _DownloadTask() when $default != null:
return $default(_that.id,_that.sourceId,_that.type,_that.remoteKey,_that.title,_that.targetPath,_that.state,_that.downloadedBytes,_that.sortOrder,_that.createdAt,_that.year,_that.seriesKey,_that.showTitle,_that.season,_that.episode,_that.artworkUrl,_that.totalBytes,_that.problem,_that.problemDetail,_that.attempts,_that.libraryItemId,_that.completedAt,_that.speed);case _:
  return null;

}
}

}

/// @nodoc


class _DownloadTask extends DownloadTask {
  const _DownloadTask({required this.id, required this.sourceId, required this.type, required this.remoteKey, required this.title, required this.targetPath, required this.state, required this.downloadedBytes, required this.sortOrder, required this.createdAt, this.year, this.seriesKey, this.showTitle, this.season, this.episode, this.artworkUrl, this.totalBytes, this.problem, this.problemDetail, this.attempts = 0, this.libraryItemId, this.completedAt, this.speed}): super._();
  

@override final  int id;
@override final  String sourceId;
@override final  VodType type;
/// The movie's or the episode's key at its source.
@override final  String remoteKey;
/// A movie's title, or an episode's own.
@override final  String title;
/// The file it becomes, absolute; `<targetPath>.part` until it is
/// verified (hard rule 11).
@override final  String targetPath;
@override final  DownloadTaskState state;
@override final  int downloadedBytes;
/// Its place in the queue: lower runs first.
@override final  int sortOrder;
@override final  DateTime createdAt;
@override final  int? year;
/// An episode's series: its key and its name.
@override final  String? seriesKey;
@override final  String? showTitle;
@override final  int? season;
@override final  int? episode;
@override final  String? artworkUrl;
/// The whole file's size, once the provider said.
@override final  int? totalBytes;
@override final  DownloadProblem? problem;
/// The problem's technical detail, redacted, for Details.
@override final  String? problemDetail;
/// Tries since the last progress.
@override@JsonKey() final  int attempts;
/// The library item it became.
@override final  int? libraryItemId;
@override final  DateTime? completedAt;
/// Bytes a second right now, while it runs (not stored).
@override final  double? speed;

/// Create a copy of DownloadTask
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadTaskCopyWith<_DownloadTask> get copyWith => __$DownloadTaskCopyWithImpl<_DownloadTask>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadTask&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.type, type) || other.type == type)&&(identical(other.remoteKey, remoteKey) || other.remoteKey == remoteKey)&&(identical(other.title, title) || other.title == title)&&(identical(other.targetPath, targetPath) || other.targetPath == targetPath)&&(identical(other.state, state) || other.state == state)&&(identical(other.downloadedBytes, downloadedBytes) || other.downloadedBytes == downloadedBytes)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.year, year) || other.year == year)&&(identical(other.seriesKey, seriesKey) || other.seriesKey == seriesKey)&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.season, season) || other.season == season)&&(identical(other.episode, episode) || other.episode == episode)&&(identical(other.artworkUrl, artworkUrl) || other.artworkUrl == artworkUrl)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.problem, problem) || other.problem == problem)&&(identical(other.problemDetail, problemDetail) || other.problemDetail == problemDetail)&&(identical(other.attempts, attempts) || other.attempts == attempts)&&(identical(other.libraryItemId, libraryItemId) || other.libraryItemId == libraryItemId)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.speed, speed) || other.speed == speed));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,sourceId,type,remoteKey,title,targetPath,state,downloadedBytes,sortOrder,createdAt,year,seriesKey,showTitle,season,episode,artworkUrl,totalBytes,problem,problemDetail,attempts,libraryItemId,completedAt,speed]);
}

@override
String toString() {
    return 'DownloadTask(id: $id, sourceId: $sourceId, type: $type, remoteKey: $remoteKey, title: $title, targetPath: $targetPath, state: $state, downloadedBytes: $downloadedBytes, sortOrder: $sortOrder, createdAt: $createdAt, year: $year, seriesKey: $seriesKey, showTitle: $showTitle, season: $season, episode: $episode, artworkUrl: $artworkUrl, totalBytes: $totalBytes, problem: $problem, problemDetail: $problemDetail, attempts: $attempts, libraryItemId: $libraryItemId, completedAt: $completedAt, speed: $speed)';
}


}

/// @nodoc
abstract mixin class _$DownloadTaskCopyWith<$Res> implements $DownloadTaskCopyWith<$Res> {
  factory _$DownloadTaskCopyWith(_DownloadTask value, $Res Function(_DownloadTask) _then) = __$DownloadTaskCopyWithImpl;
@override @useResult
$Res call({
 int id, String sourceId, VodType type, String remoteKey, String title, String targetPath, DownloadTaskState state, int downloadedBytes, int sortOrder, DateTime createdAt, int? year, String? seriesKey, String? showTitle, int? season, int? episode, String? artworkUrl, int? totalBytes, DownloadProblem? problem, String? problemDetail, int attempts, int? libraryItemId, DateTime? completedAt, double? speed
});




}
/// @nodoc
class __$DownloadTaskCopyWithImpl<$Res>
    implements _$DownloadTaskCopyWith<$Res> {
  __$DownloadTaskCopyWithImpl(this._self, this._then);

  final _DownloadTask _self;
  final $Res Function(_DownloadTask) _then;

/// Create a copy of DownloadTask
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceId = null,Object? type = null,Object? remoteKey = null,Object? title = null,Object? targetPath = null,Object? state = null,Object? downloadedBytes = null,Object? sortOrder = null,Object? createdAt = null,Object? year = freezed,Object? seriesKey = freezed,Object? showTitle = freezed,Object? season = freezed,Object? episode = freezed,Object? artworkUrl = freezed,Object? totalBytes = freezed,Object? problem = freezed,Object? problemDetail = freezed,Object? attempts = null,Object? libraryItemId = freezed,Object? completedAt = freezed,Object? speed = freezed,}) {
  return _then(_DownloadTask(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VodType,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,targetPath: null == targetPath ? _self.targetPath : targetPath // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as DownloadTaskState,downloadedBytes: null == downloadedBytes ? _self.downloadedBytes : downloadedBytes // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,seriesKey: freezed == seriesKey ? _self.seriesKey : seriesKey // ignore: cast_nullable_to_non_nullable
as String?,showTitle: freezed == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,totalBytes: freezed == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int?,problem: freezed == problem ? _self.problem : problem // ignore: cast_nullable_to_non_nullable
as DownloadProblem?,problemDetail: freezed == problemDetail ? _self.problemDetail : problemDetail // ignore: cast_nullable_to_non_nullable
as String?,attempts: null == attempts ? _self.attempts : attempts // ignore: cast_nullable_to_non_nullable
as int,libraryItemId: freezed == libraryItemId ? _self.libraryItemId : libraryItemId // ignore: cast_nullable_to_non_nullable
as int?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$DownloadRequest {

 String get sourceId; VodType get type; String get remoteKey; String get title; int? get year; String? get seriesKey; String? get showTitle; int? get season; int? get episode; String? get artworkUrl;/// The provider's container extension (`mkv`), which the file keeps.
 String? get extension;
/// Create a copy of DownloadRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadRequestCopyWith<DownloadRequest> get copyWith => _$DownloadRequestCopyWithImpl<DownloadRequest>(this as DownloadRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DownloadRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadRequest&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.remoteKey, _this.remoteKey) || other.remoteKey == _this.remoteKey)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.year, _this.year) || other.year == _this.year)&&(identical(other.seriesKey, _this.seriesKey) || other.seriesKey == _this.seriesKey)&&(identical(other.showTitle, _this.showTitle) || other.showTitle == _this.showTitle)&&(identical(other.season, _this.season) || other.season == _this.season)&&(identical(other.episode, _this.episode) || other.episode == _this.episode)&&(identical(other.artworkUrl, _this.artworkUrl) || other.artworkUrl == _this.artworkUrl)&&(identical(other.extension, _this.extension) || other.extension == _this.extension));
}


@override
int get hashCode {
  final _this = this as DownloadRequest;
  return Object.hash(runtimeType,_this.sourceId,_this.type,_this.remoteKey,_this.title,_this.year,_this.seriesKey,_this.showTitle,_this.season,_this.episode,_this.artworkUrl,_this.extension);
}

@override
String toString() {
  final _this = this as DownloadRequest;
  return 'DownloadRequest(sourceId: ${_this.sourceId}, type: ${_this.type}, remoteKey: ${_this.remoteKey}, title: ${_this.title}, year: ${_this.year}, seriesKey: ${_this.seriesKey}, showTitle: ${_this.showTitle}, season: ${_this.season}, episode: ${_this.episode}, artworkUrl: ${_this.artworkUrl}, extension: ${_this.extension})';
}


}

/// @nodoc
abstract mixin class $DownloadRequestCopyWith<$Res>  {
  factory $DownloadRequestCopyWith(DownloadRequest value, $Res Function(DownloadRequest) _then) = _$DownloadRequestCopyWithImpl;
@useResult
$Res call({
 String sourceId, VodType type, String remoteKey, String title, int? year, String? seriesKey, String? showTitle, int? season, int? episode, String? artworkUrl, String? extension
});




}
/// @nodoc
class _$DownloadRequestCopyWithImpl<$Res>
    implements $DownloadRequestCopyWith<$Res> {
  _$DownloadRequestCopyWithImpl(this._self, this._then);

  final DownloadRequest _self;
  final $Res Function(DownloadRequest) _then;

/// Create a copy of DownloadRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? type = null,Object? remoteKey = null,Object? title = null,Object? year = freezed,Object? seriesKey = freezed,Object? showTitle = freezed,Object? season = freezed,Object? episode = freezed,Object? artworkUrl = freezed,Object? extension = freezed,}) {
  return _then(DownloadRequest(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VodType,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,seriesKey: freezed == seriesKey ? _self.seriesKey : seriesKey // ignore: cast_nullable_to_non_nullable
as String?,showTitle: freezed == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,extension: freezed == extension ? _self.extension : extension // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DownloadRequest].
extension DownloadRequestPatterns on DownloadRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadRequest value)  $default,){
final _that = this;
switch (_that) {
case _DownloadRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadRequest value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sourceId,  VodType type,  String remoteKey,  String title,  int? year,  String? seriesKey,  String? showTitle,  int? season,  int? episode,  String? artworkUrl,  String? extension)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadRequest() when $default != null:
return $default(_that.sourceId,_that.type,_that.remoteKey,_that.title,_that.year,_that.seriesKey,_that.showTitle,_that.season,_that.episode,_that.artworkUrl,_that.extension);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sourceId,  VodType type,  String remoteKey,  String title,  int? year,  String? seriesKey,  String? showTitle,  int? season,  int? episode,  String? artworkUrl,  String? extension)  $default,) {final _that = this;
switch (_that) {
case _DownloadRequest():
return $default(_that.sourceId,_that.type,_that.remoteKey,_that.title,_that.year,_that.seriesKey,_that.showTitle,_that.season,_that.episode,_that.artworkUrl,_that.extension);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sourceId,  VodType type,  String remoteKey,  String title,  int? year,  String? seriesKey,  String? showTitle,  int? season,  int? episode,  String? artworkUrl,  String? extension)?  $default,) {final _that = this;
switch (_that) {
case _DownloadRequest() when $default != null:
return $default(_that.sourceId,_that.type,_that.remoteKey,_that.title,_that.year,_that.seriesKey,_that.showTitle,_that.season,_that.episode,_that.artworkUrl,_that.extension);case _:
  return null;

}
}

}

/// @nodoc


class _DownloadRequest implements DownloadRequest {
  const _DownloadRequest({required this.sourceId, required this.type, required this.remoteKey, required this.title, this.year, this.seriesKey, this.showTitle, this.season, this.episode, this.artworkUrl, this.extension});
  

@override final  String sourceId;
@override final  VodType type;
@override final  String remoteKey;
@override final  String title;
@override final  int? year;
@override final  String? seriesKey;
@override final  String? showTitle;
@override final  int? season;
@override final  int? episode;
@override final  String? artworkUrl;
/// The provider's container extension (`mkv`), which the file keeps.
@override final  String? extension;

/// Create a copy of DownloadRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadRequestCopyWith<_DownloadRequest> get copyWith => __$DownloadRequestCopyWithImpl<_DownloadRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadRequest&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.type, type) || other.type == type)&&(identical(other.remoteKey, remoteKey) || other.remoteKey == remoteKey)&&(identical(other.title, title) || other.title == title)&&(identical(other.year, year) || other.year == year)&&(identical(other.seriesKey, seriesKey) || other.seriesKey == seriesKey)&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.season, season) || other.season == season)&&(identical(other.episode, episode) || other.episode == episode)&&(identical(other.artworkUrl, artworkUrl) || other.artworkUrl == artworkUrl)&&(identical(other.extension, extension) || other.extension == extension));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceId,type,remoteKey,title,year,seriesKey,showTitle,season,episode,artworkUrl,extension);
}

@override
String toString() {
    return 'DownloadRequest(sourceId: $sourceId, type: $type, remoteKey: $remoteKey, title: $title, year: $year, seriesKey: $seriesKey, showTitle: $showTitle, season: $season, episode: $episode, artworkUrl: $artworkUrl, extension: $extension)';
}


}

/// @nodoc
abstract mixin class _$DownloadRequestCopyWith<$Res> implements $DownloadRequestCopyWith<$Res> {
  factory _$DownloadRequestCopyWith(_DownloadRequest value, $Res Function(_DownloadRequest) _then) = __$DownloadRequestCopyWithImpl;
@override @useResult
$Res call({
 String sourceId, VodType type, String remoteKey, String title, int? year, String? seriesKey, String? showTitle, int? season, int? episode, String? artworkUrl, String? extension
});




}
/// @nodoc
class __$DownloadRequestCopyWithImpl<$Res>
    implements _$DownloadRequestCopyWith<$Res> {
  __$DownloadRequestCopyWithImpl(this._self, this._then);

  final _DownloadRequest _self;
  final $Res Function(_DownloadRequest) _then;

/// Create a copy of DownloadRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? type = null,Object? remoteKey = null,Object? title = null,Object? year = freezed,Object? seriesKey = freezed,Object? showTitle = freezed,Object? season = freezed,Object? episode = freezed,Object? artworkUrl = freezed,Object? extension = freezed,}) {
  return _then(_DownloadRequest(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VodType,remoteKey: null == remoteKey ? _self.remoteKey : remoteKey // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,seriesKey: freezed == seriesKey ? _self.seriesKey : seriesKey // ignore: cast_nullable_to_non_nullable
as String?,showTitle: freezed == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String?,season: freezed == season ? _self.season : season // ignore: cast_nullable_to_non_nullable
as int?,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as int?,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,extension: freezed == extension ? _self.extension : extension // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
