// Names every finding of a `flutter analyze` run, saved to a file, as a
// GitHub Actions annotation; an analyzer that stopped without findings
// (a crash, a missing package) gets its log's last lines instead.
//
// As with failed_tests.dart: a job's log needs rights on the repository
// to read, but annotations show on the run's public summary page, so an
// analyzer failure only the Windows runner sees is named for anyone.
//
//   dart run tools/ci/analyze_findings.dart analyze.log

import 'dart:io';

/// `  error • message • lib/a.dart:3:11 • code`; Windows consoles may
/// print `-` for the bullet and `\` in the path.
final _finding = RegExp(
  r'^\s*(error|warning|info) [•-] (.*) [•-] (\S+?):(\d+):(\d+) [•-] (\S+)\s*$',
);

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tools/ci/analyze_findings.dart <log>');
    exit(64);
  }
  final file = File(args.single);
  if (!file.existsSync()) {
    stdout.writeln('::warning title=Analyze::${args.single} was not written');
    return;
  }
  final lines = file.readAsLinesSync();
  var named = 0;
  for (final line in lines) {
    final match = _finding.firstMatch(line);
    if (match == null) continue;
    final level = match[1] == 'info' ? 'notice' : match[1];
    final path = match[3]!.replaceAll(r'\', '/');
    final where = 'file=$path,line=${match[4]},col=${match[5]}';
    final title = _property(match[6]!);
    stdout.writeln('::$level $where,title=$title::${_message(match[2]!)}');
    named++;
  }
  if (named == 0) {
    final tail = lines.where((l) => l.trim().isNotEmpty).toList();
    final last = tail.sublist(tail.length > 15 ? tail.length - 15 : 0);
    stdout.writeln(
      '::error title=Analyze stopped::${_message(last.join('\n'))}',
    );
  }
}

/// Workflow commands end a message at a newline, and a property at a
/// comma or colon: GitHub's escapes.
String _message(String text) =>
    text.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');

String _property(String text) =>
    _message(text).replaceAll(':', '%3A').replaceAll(',', '%2C');
