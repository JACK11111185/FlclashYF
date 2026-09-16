import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/dashboard/widgets/network_speed.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('network speed is compact and keeps both directions visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const TestApp(
        homeBuilder: _scaffold,
        child: NetworkSpeed(traffics: [Traffic(up: 1024, down: 2048)]),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(NetworkSpeed)).height,
      getWidgetHeight(1),
    );
    expect(find.textContaining('↑'), findsOne);
    expect(find.textContaining('↓'), findsOne);
    expect(find.byType(LineChart), findsOne);
    expect(tester.takeException(), isNull);
  });
}

Widget _scaffold(Widget child) => Scaffold(body: child);
