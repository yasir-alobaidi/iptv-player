import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

import '../../app/app_harness.dart';
import 'onboarding_fakes.dart';

/// ADR-068: onboarding on a phone held upright is one column at full
/// width — the type cards and the fields one under another, the actions
/// across the bottom — and nothing runs off the screen.
void main() {
  const phone = Size(390, 844);
  late OnboardingFakes fakes;
  setUp(() => fakes = OnboardingFakes());

  Future<void> pump(WidgetTester tester, String location) => pumpApp(
    tester,
    initialLocation: location,
    size: phone,
    overrides: [
      ...fakes.overrides,
      formFactorProvider.overrideWithValue(FormFactor.mobile),
    ],
  );

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is AppTextField && w.label == label,
    description: 'field "$label"',
  );

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(
      find.descendant(of: field(label), matching: find.byType(EditableText)),
      text,
    );
    await tester.pump();
  }

  /// Every button on screen lies within the phone's width.
  void expectAllButtonsOnScreen(WidgetTester tester) {
    for (final element in find.byType(AppButton).evaluate()) {
      final box = element.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$element');
      expect(rect.right, lessThanOrEqualTo(phone.width), reason: '$element');
    }
  }

  testWidgets('Welcome: the button across the card, on screen', (tester) async {
    await pump(tester, welcomeRoutePath);

    expect(tester.takeException(), isNull);
    expectAllButtonsOnScreen(tester);
    final button = tester.getRect(
      find.widgetWithText(AppButton, 'Add your first source'),
    );
    final card = tester.getRect(
      find
          .ancestor(
            of: find.widgetWithText(AppButton, 'Add your first source'),
            matching: find.byType(Container),
          )
          .last,
    );
    expect(button.width, greaterThan(card.width * 0.7));
  });

  testWidgets('Connect: the type cards and the fields one under another; '
      'after a passing test Back, Test again and Start sync stay on '
      'screen', (tester) async {
    await pump(tester, addSourceRoutePath);

    final login = tester.getRect(
      find.widgetWithText(ChoiceCard, 'Server login'),
    );
    final link = tester.getRect(
      find.widgetWithText(ChoiceCard, 'Playlist link'),
    );
    expect(link.top, greaterThan(login.bottom - 1));
    expect(link.left, login.left);
    final username = tester.getRect(field('Username'));
    final password = tester.getRect(field('Password'));
    expect(password.top, greaterThan(username.bottom - 1));
    expect(password.width, username.width);

    await type(tester, 'Server address', 'line.northwind.test:8080');
    await type(tester, 'Username', 'living-room');
    await type(tester, 'Password', 'secret');
    await tester.tap(find.text('Test connection'));
    await settleApp(tester);

    expect(find.text('Start sync'), findsOneWidget);
    expect(find.text('Test again'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectAllButtonsOnScreen(tester);
    // Test again across the width, Back beside Start sync under it.
    final again = tester.getRect(find.widgetWithText(AppButton, 'Test again'));
    final start = tester.getRect(find.widgetWithText(AppButton, 'Start sync'));
    expect(start.top, greaterThan(again.bottom - 1));
    expect(start.right, closeTo(again.right, 0.5));
  });

  testWidgets("Sync: a stage's name stays whole beside a long account "
      'line', (tester) async {
    fakes.sources.seed();
    fakes.sync.emit(
      'src-1',
      SyncRunning(
        SyncProgress(
          stage: SyncStage.movies,
          account: ProviderAccount(
            status: 'Active',
            expiresAt: DateTime.utc(2027, 10, 27, 12),
          ),
          categories: 549,
          channels: 12340,
          movies: 8021,
          stageTotal: 13800,
        ),
      ),
    );
    await pump(tester, sourceSyncPath('src-1'));

    expect(tester.takeException(), isNull);
    final account = tester.renderObject<RenderParagraph>(find.text('Account'));
    final line = tester.renderObject<RenderParagraph>(
      find.text('Active · expires Oct 27, 2027'),
    );
    // One line, never "Accou / nt".
    expect(account.size.height, lessThan(account.text.style!.fontSize! * 2));
    expect(account.didExceedMaxLines, isFalse);
    expect(
      account.localToGlobal(Offset(account.size.width, 0)).dx,
      lessThan(line.localToGlobal(Offset.zero).dx),
    );
  });

  testWidgets('Pick categories: one column of rows, the kinds across '
      'the width', (tester) async {
    fakes.categories.lists.addAll(sampleCategories());
    await pump(tester, pickCategoriesPath('src-1'));

    expect(tester.takeException(), isNull);
    expectAllButtonsOnScreen(tester);
    // The first cluster (UK) is open: its tiles one under another.
    final sports = tester.getRect(find.text('Sports').first);
    final news = tester.getRect(find.text('News').first);
    expect(news.left, sports.left);
    expect(news.top, greaterThan(sports.bottom));
  });
}
