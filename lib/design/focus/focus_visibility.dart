import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Whether the focus shows, as a browser's `:focus-visible` has it: on a
/// desktop the focus rings are the keyboard's. A press of the mouse (or a
/// finger, a pen) hides every ring and puts the focus on the control it
/// pressed (`FocusableSurface`), so the keys go on from there; the next
/// key shows the rings again, the focused control's at once. The user, in
/// the Library: the ring stayed on Movies, the tab the screen opened on,
/// while each click moved only the underline.
///
/// Not Flutter's highlight mode: a mouse never leaves its traditional
/// mode, which shows the focus wherever a click left it, and its touch
/// mode, the one that hides the focus, hides the hover with it
/// (`FocusableActionDetector`).
///
/// One for the app, as the pointers and the keyboard it hears are:
/// [install]ed once on a desktop, before the first frame (bootstrap). A
/// TV, keys only, never installs it, and its rings always show.
abstract final class FocusVisibility {
  static final _shown = ValueNotifier<bool>(true);
  static var _installed = false;

  /// True while the focus rings show: always, until [install]; then from
  /// a key to the next press of a pointer.
  static ValueListenable<bool> get shown => _shown;

  /// Whether a press moves the focus (`FocusableSurface`): only where the
  /// press also hides the rings, or every control clicked would be ringed.
  static bool get installed => _installed;

  static void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// Undoes [install]: the rings show again, and a press moves no focus.
  @visibleForTesting
  static void uninstall() {
    if (!_installed) return;
    _installed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _shown.value = true;
  }

  /// Before the press's tap is told (a tap is decided after the global
  /// routes): the focus the tap moves comes in with its ring hidden.
  static void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _shown.value = false;
  }

  /// A key shows the rings, and goes on as usual. Not a modifier on its
  /// own: Shift with the wheel moves the Guide through time, and Alt goes
  /// to another window, both with the mouse in hand.
  static bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent && !_modifiers.contains(event.logicalKey)) {
      _shown.value = true;
    }
    return false;
  }

  static final Set<LogicalKeyboardKey> _modifiers =
      LogicalKeyboardKey.expandSynonyms({
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.alt,
        LogicalKeyboardKey.meta,
      });
}
