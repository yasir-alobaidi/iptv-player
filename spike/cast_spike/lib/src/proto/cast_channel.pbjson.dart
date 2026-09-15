// This is a generated file - do not edit.
//
// Generated from cast_channel.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use castMessageDescriptor instead')
const CastMessage$json = {
  '1': 'CastMessage',
  '2': [
    {
      '1': 'protocol_version',
      '3': 1,
      '4': 2,
      '5': 14,
      '6': '.cast_channel.CastMessage.ProtocolVersion',
      '10': 'protocolVersion'
    },
    {'1': 'source_id', '3': 2, '4': 2, '5': 9, '10': 'sourceId'},
    {'1': 'destination_id', '3': 3, '4': 2, '5': 9, '10': 'destinationId'},
    {'1': 'namespace', '3': 4, '4': 2, '5': 9, '10': 'namespace'},
    {
      '1': 'payload_type',
      '3': 5,
      '4': 2,
      '5': 14,
      '6': '.cast_channel.CastMessage.PayloadType',
      '10': 'payloadType'
    },
    {'1': 'payload_utf8', '3': 6, '4': 1, '5': 9, '10': 'payloadUtf8'},
    {'1': 'payload_binary', '3': 7, '4': 1, '5': 12, '10': 'payloadBinary'},
  ],
  '4': [CastMessage_ProtocolVersion$json, CastMessage_PayloadType$json],
};

@$core.Deprecated('Use castMessageDescriptor instead')
const CastMessage_ProtocolVersion$json = {
  '1': 'ProtocolVersion',
  '2': [
    {'1': 'CASTV2_1_0', '2': 0},
  ],
};

@$core.Deprecated('Use castMessageDescriptor instead')
const CastMessage_PayloadType$json = {
  '1': 'PayloadType',
  '2': [
    {'1': 'STRING', '2': 0},
    {'1': 'BINARY', '2': 1},
  ],
};

/// Descriptor for `CastMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List castMessageDescriptor = $convert.base64Decode(
    'CgtDYXN0TWVzc2FnZRJUChBwcm90b2NvbF92ZXJzaW9uGAEgAigOMikuY2FzdF9jaGFubmVsLk'
    'Nhc3RNZXNzYWdlLlByb3RvY29sVmVyc2lvblIPcHJvdG9jb2xWZXJzaW9uEhsKCXNvdXJjZV9p'
    'ZBgCIAIoCVIIc291cmNlSWQSJQoOZGVzdGluYXRpb25faWQYAyACKAlSDWRlc3RpbmF0aW9uSW'
    'QSHAoJbmFtZXNwYWNlGAQgAigJUgluYW1lc3BhY2USSAoMcGF5bG9hZF90eXBlGAUgAigOMiUu'
    'Y2FzdF9jaGFubmVsLkNhc3RNZXNzYWdlLlBheWxvYWRUeXBlUgtwYXlsb2FkVHlwZRIhCgxwYX'
    'lsb2FkX3V0ZjgYBiABKAlSC3BheWxvYWRVdGY4EiUKDnBheWxvYWRfYmluYXJ5GAcgASgMUg1w'
    'YXlsb2FkQmluYXJ5IiEKD1Byb3RvY29sVmVyc2lvbhIOCgpDQVNUVjJfMV8wEAAiJQoLUGF5bG'
    '9hZFR5cGUSCgoGU1RSSU5HEAASCgoGQklOQVJZEAE=');
