import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';

/// Delete file (sketch F; hard rule 11): always asked, Keep focused. The
/// video and its subtitle files go to the system's trash; on a drive with
/// none it is asked once more before they are deleted for good. True when
/// the file is gone.
Future<bool> confirmDeleteFile(BuildContext context, LibraryItem item) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final library = container.read(libraryRepositoryProvider);
  final notices = container.read(appNoticesProvider);
  final name = libraryFileName(item);

  Future<bool> ask({
    required String title,
    required String body,
    required String action,
  }) async =>
      await showAppDialog<bool>(
        context,
        builder: (context) => AppDialog(
          title: title,
          primaryLabel: action,
          destructive: true,
          onPrimary: () => Navigator.of(context).pop(true),
          secondaryLabel: 'Keep',
          onSecondary: () => Navigator.of(context).pop(false),
          child: Text(
            body,
            style: context.tokens.text.body.copyWith(
              color: context.tokens.colors.textSecondary,
            ),
          ),
        ),
      ) ??
      false;

  if (!await ask(
    title: 'Delete "$name"?',
    body: deleteFileBody(item),
    action: 'Move to trash',
  )) {
    return false;
  }
  var outcome = await library.deleteFile(item.id);
  if (outcome case Ok(value: DeleteOutcome.noTrash)) {
    if (!context.mounted ||
        !await ask(
          title: 'This drive has no trash. Delete "$name" for good?',
          body: "It can't be undone.",
          action: 'Delete for good',
        )) {
      return false;
    }
    outcome = await library.deleteFile(item.id, permanently: true);
  }
  switch (outcome) {
    case Ok(value: DeleteOutcome.trashed):
      notices.show(AppNotice('Moved "$name" to the trash.'));
      return true;
    case Ok(value: DeleteOutcome.deleted):
      notices.show(AppNotice('Deleted "$name".'));
      return true;
    case Ok(value: DeleteOutcome.noTrash):
      return false;
    case Err(:final failure):
      notices.show(
        AppNotice(
          'Couldn\'t delete "$name". ${failureMessage(failure)}',
          tone: NoticeTone.error,
        ),
      );
      return false;
  }
}
