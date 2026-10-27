import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';

import 'audit_look.dart';

export 'audit_look.dart';

/// The audit (Phase 9 decision 14): every screen in every state it has,
/// drawn at three text sizes in the smallest window and a large one, and
/// once more with reduce motion, and checked for what a reader of larger
/// text and a keyboard user would trip over:
///
/// - anything that overflows its box, or text cut off by it;
/// - a Tab walk that doesn't come back round, or leaves the focus on
///   nothing;
/// - a control neither Tab nor the arrows reach;
/// - a focus stop with no focus ring;
/// - with reduce motion, anything still moving after a blink.
///
/// A scene is a screen in one state: a function that pumps the app that
/// way for a given [AuditLook]. `auditScreen` makes a test of each scene
/// in each look, so a new row height that breaks 130 % fails by name.

/// Pumps the app as one screen in one state.
typedef AuditOpen = Future<void> Function(WidgetTester tester, AuditLook look);

/// A screen in one of its states.
@immutable
final class AuditScene {
  const new(
    this.state,
    this.open, {
    this.allow = const {},
    this.keyboard = true,
    this.close,
    this.phone = true,
  });

  /// "content", "loading", "no source" …
  final String state;
  final AuditOpen open;

  /// Findings this scene is allowed, each a piece of the finding's text
  /// and why it is no fault. Kept short: an allowance is a decision.
  final Map<String, String> allow;

  /// False for a scene whose keyboard is somebody else's (the player has
  /// no Tab stops: its keys are its own).
  final bool keyboard;

  /// Stops what the scene started (a stream, a cast), while the test
  /// still pumps.
  final Future<void> Function(WidgetTester tester)? close;

  /// False for a desktop's own screen (Casting, the Library, downloads,
  /// the keyboard's page): a phone never shows it, so the phone's looks
  /// leave it out (ADR-068).
  final bool phone;
}

/// One test per scene and look.
void auditScreen(String screen, List<AuditScene> scenes) {
  group(screen, () {
    for (final scene in scenes) {
      for (final look in auditLooksToRun) {
        if (!scene.phone && look.formFactor == FormFactor.mobile) continue;
        testWidgets('${scene.state} — ${look.name}', (tester) async {
          auditReport(
            '$screen, ${scene.state}',
            look,
            await audit(tester, scene, look, name: '$screen, ${scene.state}'),
            allow: scene.allow,
          );
        });
      }
    }
  });
}

/// Fails with [findings], less what [allow] lets pass (each key a piece of
/// a finding's text, its value why that is no fault).
void auditReport(
  String scene,
  AuditLook look,
  List<String> findings, {
  Map<String, String> allow = const {},
}) {
  final unexpected = [
    for (final finding in findings)
      if (!allow.keys.any(finding.contains)) finding,
  ];
  if (_reporting) {
    for (final finding in unexpected) {
      // The list, for whoever is working through it.
      // ignore: avoid_print
      print('AUDIT|$scene|${look.name}|$finding');
    }
    return;
  }
  expect(
    unexpected,
    isEmpty,
    reason:
        '$scene, ${look.name}:\n'
        '${unexpected.map((f) => '  • $f').join('\n')}',
  );
}

/// `AUDIT_REPORT=1 flutter test test/audit` prints every finding as a
/// line (`AUDIT|scene|look|finding`) and fails nothing: the whole
/// list at once, for a sweep.
final _reporting = Platform.environment['AUDIT_REPORT'] == '1';

/// Draws [scene] in [look] and returns everything wrong with it.
Future<List<String>> audit(
  WidgetTester tester,
  AuditScene scene,
  AuditLook look, {
  String? name,
}) => auditRun(tester, look, name: name, (check) async {
  await scene.open(tester, look);
  await auditSettle(tester);
  await check(keyboard: scene.keyboard);
  await scene.close?.call(tester);
});

/// Looks at what is on screen now, in the audit's look. A scene calls it
/// once it is drawn; [keyboard] false leaves the Tab walk out.
typedef AuditCheck = Future<void> Function({bool keyboard});

/// Runs [body] with [look] in force (`currentAuditLook`) and everything
/// the framework reports caught, and returns what [body]'s checks and the
/// framework found. With `AUDIT_SHOTS` set, the scene called [name] is
/// also drawn into that folder as it was checked.
Future<List<String>> auditRun(
  WidgetTester tester,
  AuditLook look,
  Future<void> Function(AuditCheck check) body, {
  String? name,
}) async {
  final findings = <String>{};
  // Every framework error, not only the first: a row that overflows is
  // reported once per row, and each belongs in the list. Described as it
  // is caught, while the widget that made the box is still in the tree.
  final reporter = FlutterError.onError;
  FlutterError.onError = (details) {
    try {
      findings.add(_describeError(details));
    } on Object {
      findings.add(details.exceptionAsString().split('\n').first.trim());
    }
  };
  currentAuditLook = look;
  var checked = false;
  try {
    await body(({keyboard = true}) async {
      checked = true;
      findings.addAll(_clippedText(tester));
      if (name != null) await _shoot(tester, name, look);
      if (look.reduceMotion) findings.addAll(await _stillMoving(tester));
      if (look.keyboard && keyboard) {
        // With what moving the focus breaks (a row that grows when
        // focused) caught as it goes.
        findings.addAll(await _keyboardFindings(tester));
      }
    });
    if (!checked) findings.add('the scene never asked to be looked at');
    // The screens let go of their fixtures (a watched database) before
    // anything fails: a test that fails with them held waits out its
    // whole timeout on the fixture's close.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  } on Object catch (error, stack) {
    // A step of the scene itself that doesn't work in this window (a
    // tap on something that isn't on screen here): the scene's fault,
    // said like any other.
    final at = _testLine.firstMatch('$stack')?[0];
    findings.add(
      "the scene couldn't be drawn: ${'$error'.split('\n').first}"
      '${at == null ? '' : ' ($at)'}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  } finally {
    currentAuditLook = null;
    FlutterError.onError = reporter;
  }
  final thrown = tester.takeException();
  if (thrown != null) findings.add('threw: $thrown');
  return findings.toList();
}

/// `AUDIT_SHOTS=<folder> flutter test …` draws every scene in every look
/// into that folder (`<scene>__<window>_<text>.png`), for looking at a
/// screen in each window size. Nothing is compared.
final String? _shots = Platform.environment['AUDIT_SHOTS'];

Future<void> _shoot(WidgetTester tester, String name, AuditLook look) async {
  final folder = _shots;
  if (folder == null || folder.isEmpty) return;
  final app = find.byType(MaterialApp);
  if (app.evaluate().length != 1) return;
  final scene = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final file = File(
    '$folder/${scene}__${look.size.width.toInt()}x'
    '${look.size.height.toInt()}_${look.text.name}'
    '${look.reduceMotion ? '_still' : ''}.png',
  );
  final updating = autoUpdateGoldenFiles;
  autoUpdateGoldenFiles = true;
  try {
    await expectLater(app, matchesGoldenFile(file.absolute.uri));
  } finally {
    autoUpdateGoldenFiles = updating;
  }
}

/// Real time for the fixtures' databases, then frames for what they
/// answered and the short transitions.
Future<void> auditSettle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

// ----------------------------------------------------------------- layout

final _location = RegExp(r'(lib/[\w/]+\.dart:\d+)');
final _testLine = RegExp(r'test/[\w/]+_test\.dart:\d+');

/// "A RenderFlex overflowed by 11 pixels on the bottom (lib/…/x.dart:42)".
String _describeError(FlutterErrorDetails details) {
  final what = details.exceptionAsString().split('\n').first.trim();
  final told = details.informationCollector?.call() ?? const [];
  // A layout error names the widget that made the box; the framework
  // knows where in the app's own code that was.
  final where = _location.firstMatch(
    [
      ...debugTransformDebugCreator(told).map((node) => node.toStringDeep()),
      '${details.stack ?? ''}',
    ].join('\n'),
  )?[1];
  return where == null ? what : '$what ($where)';
}

/// Text taller than the box it was given (its lower part isn't drawn), or
/// wider than it with nothing to say so (cut mid-letter).
List<String> _clippedText(WidgetTester tester) {
  final findings = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    final text = paragraph.text.toPlainText().trim();
    if (text.isEmpty || paragraph.size.isEmpty) continue;
    final needs = paragraph.textSize;
    final has = paragraph.size;
    final shown = text.length > 40 ? '${text.substring(0, 40)}…' : text;
    if (needs.height - has.height > 0.5) {
      findings.add(
        'text cut off below: "$shown" needs ${needs.height.round()} px and '
        'has ${has.height.round()} (${_owner(element)})',
      );
    } else if (paragraph.overflow == TextOverflow.clip) {
      // One line that may not wrap is laid out no wider than its box,
      // whatever it holds: ask what it would take with all the room.
      final oneLine = paragraph.maxLines == 1 || !paragraph.softWrap;
      final wants = oneLine
          ? paragraph.getMaxIntrinsicWidth(double.infinity)
          : needs.width;
      if (wants - has.width > 0.5) {
        findings.add(
          'text cut off at the right: "$shown" needs ${wants.round()} px '
          'and has ${has.width.round()} (${_owner(element)})',
        );
      }
    }
  }
  return findings;
}

/// Where in the app's own code the widget behind [element] was made
/// ("lib/…/x.dart:42"), as the framework says it for a layout error.
String _owner(Element element) {
  final described = debugTransformDebugCreator([
    DiagnosticsDebugCreator(DebugCreator(element)),
  ]).map((node) => node.toStringDeep()).join('\n');
  return _location.firstMatch(described)?[1] ?? 'unknown';
}

// ----------------------------------------------------------------- motion

/// With reduce motion nothing moves for longer than a blink: 100 ms after
/// the scene settled, no animation may still be running.
Future<List<String>> _stillMoving(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  final running = SchedulerBinding.instance.transientCallbackCount;
  if (running == 0) return const [];
  final suspects = <String, int>{};
  for (final type in const [Skeleton, CircularProgressIndicator, AppSpinner]) {
    final count = find.byType(type).evaluate().length;
    if (count > 0) suspects['$type'] = count;
  }
  final what = running == 1 ? '1 animation' : '$running animations';
  final seen = suspects.isEmpty ? '' : ' (on screen: $suspects)';
  return ['still moving with reduce motion: $what running$seen'];
}

// --------------------------------------------------------------- keyboard

/// Stops enough for the longest Tab walk a screen has.
const _maxStops = 160;

/// Tabs from where the scene left the focus until a stop comes round
/// again, checking the ring at each; then looks for controls the walk and
/// the arrows inside its one-stop lists never reach.
Future<List<String>> _keyboardFindings(WidgetTester tester) async {
  final findings = <String>[];
  final stops = <FocusNode>[];
  var round = false;
  for (var i = 0; i < _maxStops; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    // The ring is drawn the frame after the focus lands, and fades in;
    // a control below the fold glides into view as that frame ends (its
    // reveal, ADR-029), and the glide's clock starts on the next.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 250));
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node is FocusScopeNode || node.context == null) {
      findings.add(
        'Tab left the focus on nothing after '
        '${stops.isEmpty ? 'the start' : _describe(stops.last)}',
      );
      return findings;
    }
    if (stops.contains(node)) {
      round = true;
      break;
    }
    stops.add(node);
    if (!_hasRing(tester, node)) {
      findings.add('no focus ring on ${_describe(node)}');
    }
  }
  if (!round) {
    findings.add("Tab doesn't come back round (${stops.length} stops)");
    return findings;
  }
  if (stops.isEmpty) return findings;

  // Everything else that can take the focus must be inside a one-stop
  // list the walk entered (the arrows move there), or be where the
  // arrows lead from somewhere the walk stopped.
  final entered = {for (final stop in stops) ?_oneStopPane(stop)};
  final scope = stops.first.nearestScope;
  final missed = <FocusNode>{
    for (final node in scope?.traversalDescendants ?? const <FocusNode>[])
      if (node is! FocusScopeNode &&
          !stops.contains(node) &&
          node.canRequestFocus &&
          !node.skipTraversal &&
          _onStage(node) &&
          !entered.contains(_oneStopPane(node)))
        node,
  };
  if (missed.isEmpty) return findings;
  final reached = await _byArrows(tester, stops, missed);
  for (final node in missed.difference(reached)) {
    if (node.context == null) continue;
    findings.add('Tab and the arrows never reach ${_describe(node)}');
  }
  // What an arrow started after a pause (a preview that follows the
  // focus) starts now, while the scene can still stop it.
  await tester.pump(const Duration(seconds: 1));
  return findings;
}

const List<LogicalKeyboardKey> _arrows = [
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowUp,
];

/// Every control the arrow keys lead to from [stops], directly or by way
/// of another, looked for until [wanted] are all found or there is
/// nowhere new to go.
Future<Set<FocusNode>> _byArrows(
  WidgetTester tester,
  List<FocusNode> stops,
  Set<FocusNode> wanted,
) async {
  final reached = <FocusNode>{...stops};
  final queue = [...stops];
  var presses = 0;
  while (queue.isNotEmpty &&
      !reached.containsAll(wanted) &&
      presses < _maxStops * 4) {
    final from = queue.removeAt(0);
    for (final arrow in _arrows) {
      if (from.context == null || !from.canRequestFocus) break;
      from.requestFocus();
      await tester.pump();
      if (FocusManager.instance.primaryFocus != from) break;
      await tester.sendKeyEvent(arrow);
      await tester.pump();
      presses++;
      final now = FocusManager.instance.primaryFocus;
      if (now == null || now is FocusScopeNode || now.context == null) continue;
      if (reached.add(now)) queue.add(now);
    }
  }
  return reached;
}

/// The `FocusPane(tabStop: true)` around [node], if it is in one.
Element? _oneStopPane(FocusNode node) {
  Element? pane;
  final context = node.context;
  // A stop the walk passed may be gone by now (a page that rebuilt).
  if (context is! Element || !context.mounted) return null;
  context.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is FocusPane && widget.tabStop) {
      pane = ancestor;
      return false;
    }
    return true;
  });
  return pane;
}

/// Whether [node]'s control is laid out and on stage (not a screen kept
/// built behind the one showing).
bool _onStage(FocusNode node) {
  final context = node.context;
  if (context == null) return false;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return false;
  var onStage = true;
  context.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Offstage && widget.offstage) onStage = false;
    if (widget is Visibility && !widget.visible) onStage = false;
    if (widget is ExcludeFocus && widget.excluding) onStage = false;
    return onStage;
  });
  return onStage;
}

/// Whether a focus ring is drawn on or around [node]'s control. A text
/// field shows its focus its own way (the caret, and the accent border
/// the design system's fields draw), and so does a slider (the halo
/// round its thumb).
bool _hasRing(WidgetTester tester, FocusNode node) {
  final context = node.context;
  if (context != null) {
    final widget = context.widget;
    if (widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorWidgetOfExactType<Slider>() != null) {
      return true;
    }
  }
  final control = node.rect.inflate(12);
  for (final element in find.byType(CustomPaint).evaluate()) {
    final painter = (element.widget as CustomPaint).foregroundPainter;
    if (painter is! FocusRingPainter || painter.opacity <= 0) continue;
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final ring = box.localToGlobal(Offset.zero) & box.size;
    if (_overlap(ring, control)) return true;
  }
  return false;
}

bool _overlap(Rect a, Rect b) =>
    a.left <= b.right &&
    b.left <= a.right &&
    a.top <= b.bottom &&
    b.top <= a.bottom;

/// A control by its label, else by what it is.
String _describe(FocusNode node) {
  final context = node.context;
  if (context == null) return '${node.debugLabel ?? node}';
  final surface = context.widget is FocusableSurface
      ? context.widget as FocusableSurface
      : context.findAncestorWidgetOfExactType<FocusableSurface>();
  final label = surface?.semanticLabel;
  if (label != null && label.isNotEmpty) return '"$label"';
  if (node.debugLabel case final debug? when debug.isNotEmpty) {
    return '"$debug"';
  }
  return _owner(context as Element);
}
