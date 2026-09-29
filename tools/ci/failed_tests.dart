// Names every test that failed in a `flutter test --file-reporter
// json:<file>` run as a GitHub Actions error annotation.
//
// A job's log needs rights on the repository to read, but its annotations
// show on the run's public summary page — so a failure on the Windows
// runner, which can't be reproduced on Linux, is named for anyone.
//
//   dart run tools/ci/failed_tests.dart test-results.json

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tools/ci/failed_tests.dart <results.json>');
    exit(64);
  }
  final file = File(args.single);
  if (!file.existsSync()) {
    stdout.writeln(
      '::warning title=Test results::${args.single} was not written',
    );
    return;
  }

  final suites = <int, String>{};
  final tests = <int, ({String name, int suite})>{};
  final errors = <int, String>{};
  final prints = <int, List<String>>{};
  final failed = <int>[];
  for (final line in file.readAsLinesSync()) {
    final Object? event;
    try {
      event = jsonDecode(line);
    } on FormatException {
      continue;
    }
    if (event is! Map) continue;
    switch (event['type']) {
      case 'suite':
        if (event['suite'] case {'id': final int id, 'path': final path}) {
          suites[id] = '$path';
        }
      case 'testStart':
        if (event['test'] case {
          'id': final int id,
          'name': final name,
          'suiteID': final int suite,
        }) {
          tests[id] = (name: '$name', suite: suite);
        }
      case 'print':
        if (event['testID'] case final int id) {
          (prints[id] ??= []).add('${event['message']}');
        }
      case 'error':
        final error = '${event['error']}';
        if (event['testID'] case final int id) {
          errors.putIfAbsent(id, () => error);
        }
      case 'testDone':
        if (event['testID'] case final int id
            when event['result'] != 'success' && event['skipped'] != true) {
          failed.add(id);
        }
    }
  }

  final root = Directory.current.path.replaceAll(r'\', '/');
  for (final id in failed) {
    final test = tests[id];
    final path = _relative(
      (suites[test?.suite] ?? 'unknown').replaceAll(r'\', '/'),
      root,
    );
    final name = test?.name ?? 'test $id';
    var error = (errors[id] ?? '').trim().split('\n').first;
    if (error.startsWith(_seeAbove)) {
      error = _caught(prints[id] ?? const []) ?? error;
    }
    final shown = error.length > 300 ? '${error.substring(0, 300)}…' : error;
    stdout.writeln(
      '::error file=${_property(path)},title=Failed test::'
      '${_message('$name${shown.isEmpty ? '' : ' — $shown'}')}',
    );
  }
  stdout.writeln('${failed.length} failed of ${tests.length} tests');
}

/// What a widget test reports when the framework caught the failure: the
/// exception itself was printed before it.
const _seeAbove = 'Test failed. See exception logs above.';

/// The exception a widget test printed, on one line: what was thrown
/// (up to its stack) and the test's line that expected otherwise.
String? _caught(List<String> lines) {
  final start = lines.indexWhere(_thrown.hasMatch);
  if (start < 0) return null;
  final what = <String>[];
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('When the exception was thrown') ||
        line.startsWith('The relevant error-causing widget')) {
      break;
    }
    if (line.trim().isNotEmpty) what.add(line.trim());
  }
  final at = lines.map(_testLine.firstMatch).nonNulls.firstOrNull;
  return [
    what.join(' / '),
    if (at != null) '(${at[1]!.split('/').last}:${at[3]})',
  ].join(' ');
}

final _thrown = RegExp('^The following .* (was thrown|assertion)');
final _testLine = RegExp(r'([\w/]+_test\.dart)(:| line )(\d+)');

String _relative(String path, String root) =>
    path.startsWith('$root/') ? path.substring(root.length + 1) : path;

/// Workflow-command escaping (GitHub's `toCommandValue` rules).
String _message(String text) =>
    text.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');

String _property(String text) =>
    _message(text).replaceAll(':', '%3A').replaceAll(',', '%2C');
