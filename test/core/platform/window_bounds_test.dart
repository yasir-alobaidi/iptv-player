import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';

void main() {
  group('WindowBounds JSON', () {
    test('round-trips', () {
      const bounds = WindowBounds(
        size: Size(1600, 980),
        position: Offset(120, 64),
        maximized: true,
      );

      expect(WindowBounds.decode(bounds.encode()), bounds);
    });

    test('reads numbers written as strings', () {
      final bounds = WindowBounds.fromJson({'width': '1280', 'height': '800'});

      expect(bounds?.size, const Size(1280, 800));
      expect(bounds?.position, isNull);
    });

    test('rejects rubbish instead of throwing', () {
      expect(WindowBounds.decode('not json'), isNull);
      expect(WindowBounds.decode('[1, 2]'), isNull);
      expect(WindowBounds.fromJson({}), isNull);
      expect(WindowBounds.fromJson({'width': 0, 'height': 600}), isNull);
      expect(WindowBounds.fromJson({'width': -4, 'height': 600}), isNull);
      expect(
        WindowBounds.fromJson({'width': double.nan, 'height': 600}),
        isNull,
      );
    });

    test('a half-written position is dropped, not half-restored', () {
      final bounds = WindowBounds.fromJson({
        'width': 1280,
        'height': 800,
        'x': 40,
      });

      expect(bounds?.position, isNull);
    });
  });

  group('resolveStartupBounds', () {
    test('first run opens at the default size, centred', () {
      final bounds = resolveStartupBounds(null, canRestorePosition: true);

      expect(bounds.size, WindowSizes.initial);
      expect(bounds.position, isNull);
    });

    test('a saved size smaller than the minimum is grown', () {
      final bounds = resolveStartupBounds(
        const WindowBounds(size: Size(600, 400)),
        canRestorePosition: true,
      );

      expect(bounds.size, WindowSizes.minimum);
    });

    test('the position is dropped where it cannot be restored', () {
      const saved = WindowBounds(
        size: Size(1400, 900),
        position: Offset(200, 100),
      );

      expect(
        resolveStartupBounds(saved, canRestorePosition: true).position,
        const Offset(200, 100),
      );
      expect(
        resolveStartupBounds(saved, canRestorePosition: false).position,
        isNull,
        reason: 'Wayland cannot place its own windows',
      );
    });

    test('a negative position is kept: monitors sit left of and above', () {
      const saved = WindowBounds(
        size: Size(1400, 900),
        position: Offset(-1920, -200),
      );

      expect(
        resolveStartupBounds(saved, canRestorePosition: true).position,
        const Offset(-1920, -200),
      );
    });

    test('an absurd position is dropped', () {
      const saved = WindowBounds(
        size: Size(1400, 900),
        position: Offset(90000, 12),
      );

      expect(
        resolveStartupBounds(saved, canRestorePosition: true).position,
        isNull,
      );
    });

    test('maximized survives', () {
      final bounds = resolveStartupBounds(
        const WindowBounds(size: Size(1400, 900), maximized: true),
        canRestorePosition: true,
      );

      expect(bounds.maximized, isTrue);
    });
  });

  group('isWaylandSession', () {
    test('reads the session type', () {
      expect(isWaylandSession({'XDG_SESSION_TYPE': 'wayland'}), isTrue);
      expect(isWaylandSession({'XDG_SESSION_TYPE': 'x11'}), isFalse);
      expect(isWaylandSession({'WAYLAND_DISPLAY': 'wayland-0'}), isTrue);
      expect(isWaylandSession({}), isFalse);
    });

    test('GDK_BACKEND=x11 means XWayland, where positioning works', () {
      expect(
        isWaylandSession({
          'XDG_SESSION_TYPE': 'wayland',
          'WAYLAND_DISPLAY': 'wayland-0',
          'GDK_BACKEND': 'x11',
        }),
        isFalse,
      );
    });
  });

  group('InMemoryWindowBoundsStore', () {
    test('gives back what it was given', () async {
      final store = InMemoryWindowBoundsStore();
      expect((await store.load()).valueOrNull, isNull);

      const bounds = WindowBounds(size: Size(1280, 800));
      await store.save(bounds);

      expect((await store.load()).valueOrNull, bounds);
    });
  });
}
