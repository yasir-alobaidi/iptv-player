import 'package:flutter/services.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/core/platform/system_facts.dart';

/// [SystemFacts] on a TV (ADR-059), over `MainActivity`'s `bijou/system`
/// channel (`SystemInfo.kt`): the model and its chip, Android, the GPU's
/// drivers as the system names them, and the memory. Read tolerantly
/// ([androidSystemFactsFrom]); what can't be read is left out.
final class AndroidSystemFacts implements SystemFactsReader {
  const new({this._channel = const MethodChannel('bijou/system')});

  final MethodChannel _channel;

  @override
  Future<SystemFacts> read() async {
    try {
      return androidSystemFactsFrom(
        await _channel.invokeMethod<Object?>('facts'),
      );
    } on Object {
      return const SystemFacts();
    }
  }
}

/// The version a TV's build was made as, from its package over
/// `bijou/system` (ADR-059): Flutter writes no `version.json` into an APK.
/// Unknown when it can't be read, never an error.
Future<AppVersion> androidAppVersion({
  MethodChannel channel = const MethodChannel('bijou/system'),
}) async {
  try {
    return AppVersion.fromJson(await channel.invokeMethod<Object?>('version'));
  } on Object {
    return AppVersion.unknown;
  }
}

/// `facts`' answer as the report says it; nothing when it isn't a map.
SystemFacts androidSystemFactsFrom(Object? answer) {
  if (answer is! Map) return const SystemFacts();
  String? text(String key) => switch (answer[key]) {
    final String value when value.trim().isNotEmpty => value.trim(),
    _ => null,
  };
  int? number(String key) => switch (answer[key]) {
    final num value => value.toInt(),
    _ => null,
  };
  String? prop(String name) => text('prop:$name');

  final release = text('release');
  final sdk = number('sdk');
  final patch = text('securityPatch');
  final kernel = text('kernel');

  // `TCL 43V8C`: the brand once, as people say it.
  final manufacturer = text('manufacturer');
  final model = text('model');
  final name = [
    if (manufacturer != null &&
        !(model?.toLowerCase().startsWith(manufacturer.toLowerCase()) ?? false))
      manufacturer,
    ?model,
  ].join(' ');
  final socModel = text('socModel') ?? prop('ro.soc.model');
  final soc = [
    text('socManufacturer') ?? prop('ro.soc.manufacturer'),
    socModel,
  ].nonNulls.join(' ');
  final device = [
    if (name.isNotEmpty) name,
    if (text('device') case final device?) 'device $device',
    if (text('board') case final board?) 'board $board',
    if (text('hardware') case final hardware?) 'hardware $hardware',
    if (prop('ro.board.platform') case final platform?) 'platform $platform',
    if (prop('ro.mediatek.platform') case final platform?) 'MediaTek $platform',
    if (socModel != null) 'chip $soc',
    ?text('abis'),
    if (text('build') case final build?) 'build $build',
  ].join(' · ');

  final egl = prop('ro.hardware.egl');
  final vulkanDriver = prop('ro.hardware.vulkan');
  final vulkan = text('vulkan');
  final glEs = text('glEs') ?? prop('ro.opengles.version');
  final graphics = [
    if (egl != null) 'EGL $egl',
    if (vulkan != null)
      'Vulkan $vulkan${vulkanDriver == null ? '' : ' ($vulkanDriver)'}'
    else if (answer.containsKey('vulkan'))
      'no Vulkan',
    if (glEs != null) 'OpenGL ES $glEs',
    if (prop('ro.hardware.gralloc') case final gralloc?) 'gralloc $gralloc',
  ].join(' · ');

  String gb(int mb) => '${(mb / 1024).toStringAsFixed(1)} GB';
  final total = number('totalMb');
  final available = number('availableMb');
  final low = number('lowMemoryMb');
  final heap = number('heapMb');
  final largeHeap = number('largeHeapMb');
  final storage = number('freeStorageMb');
  final memory = [
    if (total != null)
      [
        gb(total),
        if (available != null) '${gb(available)} free',
        if (low != null) 'low at ${gb(low)}',
      ].join(', '),
    if (answer['lowRam'] == true) 'a low-RAM device',
    if (heap != null)
      [
        'the app may use $heap MB',
        if (largeHeap != null) '(large $largeHeap MB)',
      ].join(' '),
    if (storage != null) 'storage ${gb(storage)} free',
  ].join(' · ');

  return SystemFacts(
    os: release == null
        ? null
        : [
            'Android $release',
            if (sdk != null) '(API $sdk${patch == null ? '' : ', $patch'})',
          ].join(' '),
    kernel: kernel == null ? null : 'Linux $kernel',
    graphics: graphics.isEmpty ? const [] : [GraphicsCard(name: graphics)],
    device: device.isEmpty ? null : device,
    memory: memory.isEmpty ? null : memory,
  );
}
