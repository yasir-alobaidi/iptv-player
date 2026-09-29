import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/live_tv/domain/channel_names.dart';

/// [row] with the name the screens show and its badge, worked out from
/// its provider name (`cleanChannelName`). Every channel sync writes goes
/// through here, in the sync isolate: both columns are the provider's, so
/// a re-sync rewrites them with the name.
ChannelsCompanion withCleanName(ChannelsCompanion row) {
  final cleaned = cleanChannelName(row.name.value);
  return row.copyWith(
    cleanName: Value(cleaned.name),
    quality: Value(cleaned.quality?.name),
  );
}
