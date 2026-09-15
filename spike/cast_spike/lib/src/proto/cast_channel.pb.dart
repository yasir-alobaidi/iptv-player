// This is a generated file - do not edit.
//
// Generated from cast_channel.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'cast_channel.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'cast_channel.pbenum.dart';

class CastMessage extends $pb.GeneratedMessage {
  factory CastMessage({
    CastMessage_ProtocolVersion? protocolVersion,
    $core.String? sourceId,
    $core.String? destinationId,
    $core.String? namespace,
    CastMessage_PayloadType? payloadType,
    $core.String? payloadUtf8,
    $core.List<$core.int>? payloadBinary,
  }) {
    final result = CastMessage._();
    if (protocolVersion != null) result.protocolVersion = protocolVersion;
    if (sourceId != null) result.sourceId = sourceId;
    if (destinationId != null) result.destinationId = destinationId;
    if (namespace != null) result.namespace = namespace;
    if (payloadType != null) result.payloadType = payloadType;
    if (payloadUtf8 != null) result.payloadUtf8 = payloadUtf8;
    if (payloadBinary != null) result.payloadBinary = payloadBinary;
    return result;
  }

  CastMessage._();

  factory CastMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CastMessage()..mergeFromBuffer(data, registry);
  factory CastMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CastMessage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CastMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'cast_channel'),
      createEmptyInstance: CastMessage.$_createMessage)
    ..aE<CastMessage_ProtocolVersion>(
        1, _omitFieldNames ? '' : 'protocolVersion',
        fieldType: $pb.PbFieldType.QE,
        enumValues: CastMessage_ProtocolVersion.values)
    ..aQS(2, _omitFieldNames ? '' : 'sourceId')
    ..aQS(3, _omitFieldNames ? '' : 'destinationId')
    ..aQS(4, _omitFieldNames ? '' : 'namespace')
    ..aE<CastMessage_PayloadType>(5, _omitFieldNames ? '' : 'payloadType',
        fieldType: $pb.PbFieldType.QE,
        enumValues: CastMessage_PayloadType.values)
    ..aOS(6, _omitFieldNames ? '' : 'payloadUtf8')
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'payloadBinary', $pb.PbFieldType.OY);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CastMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CastMessage copyWith(void Function(CastMessage) updates) =>
      super.copyWith((message) => updates(message as CastMessage))
          as CastMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CastMessage() / CastMessage.new instead')
  static CastMessage create() => CastMessage._();
  static $pb.GeneratedMessage $_createMessage() => CastMessage._();
  @$core.override
  CastMessage createEmptyInstance() => CastMessage._();
  @$core.pragma('dart2js:noInline')
  static CastMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CastMessage>(
          CastMessage.$_createMessage);
  static CastMessage? _defaultInstance;

  @$pb.TagNumber(1)
  CastMessage_ProtocolVersion get protocolVersion => $_getN(0);
  @$pb.TagNumber(1)
  set protocolVersion(CastMessage_ProtocolVersion value) =>
      $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocolVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocolVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sourceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sourceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSourceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get destinationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set destinationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDestinationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDestinationId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get namespace => $_getSZ(3);
  @$pb.TagNumber(4)
  set namespace($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNamespace() => $_has(3);
  @$pb.TagNumber(4)
  void clearNamespace() => $_clearField(4);

  @$pb.TagNumber(5)
  CastMessage_PayloadType get payloadType => $_getN(4);
  @$pb.TagNumber(5)
  set payloadType(CastMessage_PayloadType value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPayloadType() => $_has(4);
  @$pb.TagNumber(5)
  void clearPayloadType() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get payloadUtf8 => $_getSZ(5);
  @$pb.TagNumber(6)
  set payloadUtf8($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPayloadUtf8() => $_has(5);
  @$pb.TagNumber(6)
  void clearPayloadUtf8() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get payloadBinary => $_getN(6);
  @$pb.TagNumber(7)
  set payloadBinary($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPayloadBinary() => $_has(6);
  @$pb.TagNumber(7)
  void clearPayloadBinary() => $_clearField(7);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
