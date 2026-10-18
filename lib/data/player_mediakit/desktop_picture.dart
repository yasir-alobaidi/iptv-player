import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/player/player_engine.dart';

/// The size, in physical pixels, mpv draws the desktop's picture at for
/// High picture quality: where [fit] puts a video of [video]'s display
/// size in a [box] of logical pixels, times [devicePixelRatio]. That is
/// the fitted picture for contain (Fit, 16:9, 4:3), and the whole box for
/// cover (Fill: mpv crops it, `panscan`) and fill (Stretch: mpv stretches
/// it, `keepaspect=no`).
///
/// Where the picture is narrower or shorter than its box, the bars on
/// either side are whole pixels: with an odd pixel left over, the picture
/// would sit half a pixel off the screen's and the screen's scaling would
/// soften it again.
///
/// At least 2 × 2, and at most the larger of 3840 × 2160 and the video's
/// own size, made smaller evenly so it keeps its shape. Null, which is
/// the video's own size, while the box is empty or unbounded or the
/// video's size isn't known.
(int, int)? highQualityPictureSize({
  required Size video,
  required Size box,
  required double devicePixelRatio,
  BoxFit fit = BoxFit.contain,
}) {
  if (video.isEmpty ||
      !video.isFinite ||
      box.isEmpty ||
      !box.isFinite ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return null;
  }
  final screen = box * devicePixelRatio;
  final drawn = applyBoxFit(fit, video, box).destination * devicePixelRatio;
  final shrink = math.min(
    math.max(_largest.width, video.width) / drawn.width,
    math.max(_largest.height, video.height) / drawn.height,
  );
  // Past 4K the screen scales the picture anyway.
  if (shrink < 1) {
    return (
      math.max(2, (drawn.width * shrink).round()),
      math.max(2, (drawn.height * shrink).round()),
    );
  }
  int side(double length, double room) {
    final whole = room.round();
    final bar = math.max(0, ((whole - length) / 2).round());
    return math.max(2, whole - 2 * bar);
  }

  return (side(drawn.width, screen.width), side(drawn.height, screen.height));
}

const _largest = Size(3840, 2160);

/// The desktop's picture. media_kit draws mpv into a texture at the
/// video's own size unless it is given another (`setSize`), and Flutter
/// then scales that texture to the screen, so mpv's own scalers and its
/// `keepaspect` and `panscan` have nothing to act on. This keeps:
///
/// - [fit], the picture widget's fit for the Picture size: Fill crops
///   and Stretch stretches the texture itself (they did nothing before);
/// - for High, the texture at the size the picture takes on screen
///   ([highQualityPictureSize]), so mpv scales the picture itself with
///   the filters the engine sets. A new size is sent once the frame that
///   asked for it is done, then at most every [interval] while it keeps
///   changing (a window dragged, the preview growing to full screen).
///   Standard puts the video's own size back.
///
/// media_kit's controller puts the texture back to the video's own size
/// by itself whenever the video's size changes, and still holds the size
/// it was given, so it wouldn't send that again: [video] has it sent
/// again. The texture's reported size catches one of the controller's
/// that landed after ours, a few times at most.
final class DesktopPicture {
  new({
    required this._setSize,
    required this._texture,
    required this._warn,
    this.interval = const Duration(milliseconds: 150),
  }) {
    _texture.addListener(_onTexture);
  }

  /// media_kit's `VideoController.setSize`.
  final Future<void> Function({int? width, int? height}) _setSize;

  /// The texture's size as media_kit reports it (`VideoController.rect`).
  final ValueListenable<Rect?> _texture;
  final void Function(String message) _warn;
  final Duration interval;

  final ValueNotifier<BoxFit> _fit = ValueNotifier(BoxFit.contain);

  /// The picture widget's fit for the Picture size; contain leaves the
  /// view's own.
  ValueListenable<BoxFit> get fit => _fit;

  PictureQuality _quality = PictureQuality.standard;
  Size? _video;

  /// Each view shown, by its state. The largest is the one mpv draws for.
  final _views = <Object, _ViewBox>{};

  /// The view drawn for last, kept while none is shown: a stream opening
  /// hides the picture (in the preview and the full-screen player at
  /// once), and the next one is drawn for the same place.
  _ViewBox? _place;

  /// What was sent to the controller: null is the video's own size.
  (int, int)? _sent;

  /// The video's size changed since the size was sent: the controller
  /// has put its own back.
  bool _stale = false;

  /// The texture was seen back at the video's own size (see [_onTexture]),
  /// and how many times since it last had ours.
  bool _reverted = false;
  int _resends = 0;
  static const _maxResends = 3;

  /// A send waits for the frame that asked to be done.
  bool _queued = false;

  /// A send is under way (the controller answers through a platform
  /// channel), and another was asked for meanwhile.
  bool _busy = false;
  bool _again = false;

  /// The [interval] after a size went out, and whether anything changed
  /// during it.
  Timer? _calm;
  bool _waiting = false;

  bool _warned = false;
  bool _disposed = false;

  /// What the thing playing asked for (the engine sets it at every open).
  PictureQuality get quality => _quality;
  set quality(PictureQuality quality) {
    if (quality == _quality) return;
    _quality = quality;
    _schedule();
  }

  /// The fit for the Picture size chosen.
  BoxFit get pictureFit => _fit.value;
  set pictureFit(BoxFit fit) {
    if (fit == _fit.value) return;
    _fit.value = fit;
    _schedule();
  }

  /// The video's display size (mpv's `dw` × `dh`, turned for a rotation).
  void video(int width, int height) {
    if (width <= 0 || height <= 0) return;
    final size = Size(width.toDouble(), height.toDouble());
    if (size == _video) return;
    _video = size;
    _stale = true;
    _resends = 0;
    _schedule();
  }

  /// The picture where it shows: [picture] builds media_kit's `Video`
  /// with the fit to use. [fit] is the view's own under Fit, 16:9 and
  /// 4:3.
  Widget view({
    required Widget Function(BoxFit fit) picture,
    Key? key,
    BoxFit fit = BoxFit.contain,
  }) => _PictureView(key: key, owner: this, fit: fit, picture: picture);

  void _report(Object view, _ViewBox box) {
    if (_views[view] == box) return;
    _views[view] = box;
    _schedule();
  }

  void _forget(Object view) {
    final box = _views.remove(view);
    if (box == null) return;
    // With none left, the place drawn for stays.
    _place ??= box;
    _schedule();
  }

  /// The largest view shown, or the one drawn for last while none is.
  _ViewBox? _currentPlace() {
    _ViewBox? largest;
    for (final box in _views.values) {
      if (largest == null || box.pixels > largest.pixels) largest = box;
    }
    return _place = largest ?? _place;
  }

  /// The texture's size for High, or null for the video's own.
  (int, int)? _target() {
    final place = _currentPlace();
    final video = _video;
    if (_quality != PictureQuality.high || video == null || place == null) {
      return null;
    }
    return highQualityPictureSize(
      video: video,
      box: place.box,
      devicePixelRatio: place.devicePixelRatio,
      fit: _fit.value == BoxFit.contain ? place.fit : _fit.value,
    );
  }

  /// Sends what changed once the frame that changed it is done (a view
  /// reports from its layout), or, within [interval] of the last size
  /// sent, once that time is up.
  void _schedule() {
    if (_disposed) return;
    if (_calm != null) {
      _waiting = true;
      return;
    }
    if (_queued) return;
    _queued = true;
    scheduleMicrotask(() {
      _queued = false;
      unawaited(_run());
    });
  }

  /// One send at a time, so the controller's sizes land in order.
  Future<void> _run() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _send();
      } while (_again && !_disposed);
    } finally {
      _busy = false;
    }
  }

  Future<void> _send() async {
    if (_disposed) return;
    final target = _target();
    final video = _video;
    final own = video == null
        ? null
        : (video.width.round(), video.height.round());
    final stale = _stale;
    _stale = false;
    final reverted = _reverted && own != null && _textureIs(own);
    _reverted = false;
    final List<(int, int)?> sizes;
    if (target == null) {
      if (_sent == null) return;
      sizes = const [null];
    } else if (target != _sent) {
      sizes = [target];
    } else if ((stale || reverted) && target != own) {
      // The controller sends a size only when it isn't the one it was
      // given last: the video's own first, then ours.
      sizes = [null, target];
    } else {
      return;
    }
    _sent = target;
    _calm = Timer(interval, _calmed);
    try {
      for (final size in sizes) {
        if (size == null) {
          await _setSize();
        } else {
          await _setSize(width: size.$1, height: size.$2);
        }
      }
    } on Object catch (error) {
      if (_warned) return;
      _warned = true;
      _warn("Couldn't size the picture for High quality: $error");
    }
  }

  void _calmed() {
    _calm = null;
    if (!_waiting) return;
    _waiting = false;
    _schedule();
  }

  bool _textureIs((int, int) size) {
    final rect = _texture.value;
    return rect != null && (rect.width.round(), rect.height.round()) == size;
  }

  /// The texture back at the video's own size while ours was sent is the
  /// controller's resize landing after ours, or only the texture passing
  /// through it on its way to ours (the two sent together): it is looked
  /// at again when the next send is due, and ours is sent again if the
  /// texture is still at the video's own, a few times at most.
  void _onTexture() {
    final sent = _sent;
    final video = _video;
    final rect = _texture.value;
    if (sent == null || video == null || rect == null) return;
    final size = (rect.width.round(), rect.height.round());
    if (size == sent) {
      _resends = 0;
      return;
    }
    final own = (video.width.round(), video.height.round());
    if (size != own || _resends >= _maxResends) return;
    _resends++;
    _reverted = true;
    _schedule();
  }

  void dispose() {
    _disposed = true;
    _calm?.cancel();
    _calm = null;
    _texture.removeListener(_onTexture);
    _fit.dispose();
  }
}

/// A view's box (logical pixels), its device pixel ratio and its own fit.
@immutable
final class _ViewBox {
  const new(this.box, this.devicePixelRatio, this.fit);

  final Size box;
  final double devicePixelRatio;
  final BoxFit fit;

  double get pixels =>
      box.width * box.height * devicePixelRatio * devicePixelRatio;

  @override
  bool operator ==(Object other) =>
      other is _ViewBox &&
      other.box == box &&
      other.devicePixelRatio == devicePixelRatio &&
      other.fit == fit;

  @override
  int get hashCode => Object.hash(box, devicePixelRatio, fit);
}

class _PictureView extends StatefulWidget {
  const new({
    required this.owner,
    required this.fit,
    required this.picture,
    super.key,
  });

  final DesktopPicture owner;
  final BoxFit fit;
  final Widget Function(BoxFit fit) picture;

  @override
  State<_PictureView> createState() => _PictureViewState();
}

class _PictureViewState extends State<_PictureView> {
  @override
  void dispose() {
    widget.owner._forget(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Read in the layout; sent after it.
      widget.owner._report(
        this,
        _ViewBox(
          constraints.biggest,
          MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
          widget.fit,
        ),
      );
      return ValueListenableBuilder<BoxFit>(
        valueListenable: widget.owner.fit,
        builder: (context, fit, _) =>
            widget.picture(fit == BoxFit.contain ? widget.fit : fit),
      );
    },
  );
}
