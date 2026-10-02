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

class CastMessage_ProtocolVersion extends $pb.ProtobufEnum {
  static const CastMessage_ProtocolVersion CASTV2_1_0 =
      CastMessage_ProtocolVersion._(0, _omitEnumNames ? '' : 'CASTV2_1_0');

  static const $core.List<CastMessage_ProtocolVersion> values =
      <CastMessage_ProtocolVersion>[
    CASTV2_1_0,
  ];

  static final $core.List<CastMessage_ProtocolVersion?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 0);
  static CastMessage_ProtocolVersion? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CastMessage_ProtocolVersion._(super.value, super.name);
}

class CastMessage_PayloadType extends $pb.ProtobufEnum {
  static const CastMessage_PayloadType STRING =
      CastMessage_PayloadType._(0, _omitEnumNames ? '' : 'STRING');
  static const CastMessage_PayloadType BINARY =
      CastMessage_PayloadType._(1, _omitEnumNames ? '' : 'BINARY');

  static const $core.List<CastMessage_PayloadType> values =
      <CastMessage_PayloadType>[
    STRING,
    BINARY,
  ];

  static final $core.List<CastMessage_PayloadType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static CastMessage_PayloadType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CastMessage_PayloadType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
