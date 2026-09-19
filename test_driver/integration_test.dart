// The host side of `flutter drive`: runs an integration test on the
// device and writes its reportData to build/integration_response_data.json
// (docs/06, the frame-time measurement in profile mode).

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
