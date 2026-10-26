import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/features/diagnostics/data/lan_report_sharer.dart';
import 'package:iptv_player/features/diagnostics/domain/report_share.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report_share_providers.g.dart';

/// Hands the report to a phone on the same network (ADR-059). Tests
/// override it.
@Riverpod(keepAlive: true)
ReportSharer reportSharer(Ref ref) =>
    LanReportSharer(log: ref.watch(appLogProvider));
