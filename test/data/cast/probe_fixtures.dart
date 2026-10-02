import 'dart:io';

import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/data/cast/ffprobe_json.dart';

/// ffprobe's answer for each media sample, recorded by the bundled
/// ffprobe with the probe's own arguments (`test_fixtures/cast/probe/`,
/// file names replaced by the sample's).
String probeFixture(String name) =>
    File('test_fixtures/cast/probe/$name.json').readAsStringSync();

StreamFacts readFixture(String name) => readFfprobeJson(probeFixture(name))!;

/// The live samples the fake panel loops (docs/06's matrix).
const liveSampleNames = [
  'h264_1080p50_aac',
  'h264_1080p25_ac3',
  'h264_1080i50_mp2',
  'hevc_1080p50_aac',
  'hevc_2160p25_eac3',
  'mpeg2_576i25_mp2',
  'h264_2160p25_aac',
  'codec_switch_h264_720p_to_1080p',
];
