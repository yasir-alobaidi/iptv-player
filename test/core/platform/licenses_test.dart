import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/licenses.dart';
import 'package:iptv_player/core/platform/tool_licenses.dart';
import 'package:iptv_player/design/fonts.dart';

void main() {
  setUp(() {
    LicenseRegistry.reset();
    resetToolLicensesForTest();
    resetBundledFontLicensesForTest();
  });
  tearDown(LicenseRegistry.reset);

  test('FFmpeg and mpv are in the list, each with what the app does with '
      'it and the whole text of its licence', () async {
    registerToolLicenses();

    final licenses = await collectLicenses();
    final byName = {for (final l in licenses) l.package: l.text};

    final ffmpeg = byName['FFmpeg']!;
    expect(ffmpeg, contains('ffmpeg and ffprobe programs as separate'));
    expect(ffmpeg, contains('GNU GENERAL PUBLIC LICENSE'));
    expect(ffmpeg, contains('Version 3, 29 June 2007'));

    final mpv = byName['mpv (libmpv)']!;
    expect(mpv, contains('libmpv'));
    expect(mpv, contains('GNU LESSER GENERAL PUBLIC LICENSE'));
    expect(mpv, contains('Version 2.1, February 1999'));
    expect(mpv, contains('Version 2, June 1991'));
  });

  test('registering twice adds them once', () async {
    registerToolLicenses();
    registerToolLicenses();

    final licenses = await collectLicenses();

    expect(licenses.where((l) => l.package == 'FFmpeg'), hasLength(1));
    expect(
      licenses.singleWhere((l) => l.package == 'FFmpeg').entries,
      hasLength(1),
    );
  });

  test('packages come A to Z whatever their case, each once, with every '
      'licence it has', () async {
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(['zebra'], 'Z terms');
      yield const LicenseEntryWithLineBreaks(['Alpha', 'beta'], 'Shared terms');
      yield const LicenseEntryWithLineBreaks(['beta'], 'More for beta');
    });

    final licenses = await collectLicenses();

    expect([for (final l in licenses) l.package], ['Alpha', 'beta', 'zebra']);
    final beta = licenses[1];
    expect(beta.entries, hasLength(2));
    expect(beta.text, contains('Shared terms'));
    expect(beta.text, contains('More for beta'));
  });

  test("the bundled fonts' licences are in the same list", () async {
    registerBundledFontLicenses();

    final names = [for (final l in await collectLicenses()) l.package];

    expect(names, containsAll(['Manrope', 'JetBrains Mono']));
  });
}
