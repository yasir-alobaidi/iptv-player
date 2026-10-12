import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/cast/webvtt.dart';

/// docs/04 "Subtitles": a relayed stream that starts past 0:00 is at time
/// 0 on the TV there, and its cues are moved back to match.
void main() {
  const vtt =
      'WEBVTT\n'
      '\n'
      '00:05.000 --> 00:08.000\n'
      'Before the start\n'
      '\n'
      '00:58.000 --> 01:04.500\n'
      'Showing at the start\n'
      'on two lines\n'
      '\n'
      '01:10.250 --> 01:12.000 line:90% align:center\n'
      '<i>After it</i>\n'
      '\n'
      '1:00:01.000 --> 1:00:03.000\n'
      'An hour in\n';

  test('counts the cues', () {
    expect(webVttCues(vtt), 4);
    expect(webVttCues('WEBVTT\n'), 0);
    expect(webVttCues('not subtitles --> at all'), 0);
  });

  test('moved back by nothing: every cue, its times written in full', () {
    final same = shiftWebVtt(vtt, Duration.zero);
    expect(webVttCues(same), 4);
    expect(same, startsWith('WEBVTT\n\n00:00:05.000 --> 00:00:08.000\n'));
    expect(same, contains('01:00:01.000 --> 01:00:03.000\nAn hour in\n'));
  });

  test('moved back: what ended is left out, what shows starts at 0, the '
      'rest keeps its words and its settings', () {
    expect(
      shiftWebVtt(vtt, const Duration(minutes: 1)),
      'WEBVTT\n'
      '\n'
      '00:00:00.000 --> 00:00:04.500\n'
      'Showing at the start\n'
      'on two lines\n'
      '\n'
      '00:00:10.250 --> 00:00:12.000 line:90% align:center\n'
      '<i>After it</i>\n'
      '\n'
      '00:59:01.000 --> 00:59:03.000\n'
      'An hour in\n',
    );
  });

  test('a cue that ends exactly at the start is left out', () {
    final moved = shiftWebVtt(vtt, const Duration(seconds: 8));
    expect(moved, isNot(contains('Before the start')));
    expect(webVttCues(moved), 3);
  });

  test('past the last cue: a WebVTT file with none', () {
    expect(shiftWebVtt(vtt, const Duration(hours: 2)), 'WEBVTT\n');
  });

  test('identifiers, notes, Windows line ends and a byte order mark', () {
    const text =
        '﻿WEBVTT - made by hand\r\n'
        '\r\n'
        'NOTE a remark\r\n'
        '\r\n'
        'intro\r\n'
        '00:20.000 --> 00:22.000\r\n'
        'Named cue\r\n'
        '\r\n'
        '\r\n'
        '00:30.000 --> 00:31.000\r\n'
        'Last\r\n';
    expect(
      shiftWebVtt(text, const Duration(seconds: 10)),
      'WEBVTT - made by hand\n'
      '\n'
      'NOTE a remark\n'
      '\n'
      'intro\n'
      '00:00:10.000 --> 00:00:12.000\n'
      'Named cue\n'
      '\n'
      '00:00:20.000 --> 00:00:21.000\n'
      'Last\n',
    );
  });

  test('text that is not WebVTT comes back as WebVTT with what cues it '
      'has, never thrown', () {
    expect(shiftWebVtt('', const Duration(seconds: 1)), 'WEBVTT\n');
    expect(
      shiftWebVtt('<html>404</html>', const Duration(seconds: 1)),
      'WEBVTT\n\n<html>404</html>\n',
    );
    // A timing line the reader doesn't know is not passed on as a cue.
    expect(
      shiftWebVtt('WEBVTT\n\n00:01 --> 00:02\nOdd\n', Duration.zero),
      'WEBVTT\n',
    );
  });
}
