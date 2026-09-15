import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/app.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const IptvPlayerApp());

    expect(find.byType(Scaffold), findsOneWidget);
  });
}
