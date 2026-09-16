import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/desktop_shell.dart';

import 'app/app_harness.dart';

void main() {
  testWidgets('the app opens on the shell', (tester) async {
    final app = await pumpApp(tester);

    expect(find.byType(DesktopShell), findsOneWidget);
    expect(app.location, AppDestination.home.path);
  });
}
