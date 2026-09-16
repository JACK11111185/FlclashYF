import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('main navigation uses semantic outlined icons', () {
    final items = Navigation().getItems(
      openLogs: true,
      hasProxies: true,
      hasNetworking: true,
    );

    expect(
      {for (final item in items) item.label: item.icon.icon},
      {
        PageLabel.dashboard: Icons.space_dashboard_outlined,
        PageLabel.proxies: Icons.article_outlined,
        PageLabel.profiles: Icons.folder_outlined,
        PageLabel.route: Icons.alt_route_outlined,
        PageLabel.requests: Icons.view_timeline_outlined,
        PageLabel.connections: Icons.ballot_outlined,
        PageLabel.resources: Icons.storage_outlined,
        PageLabel.networking: Icons.hub_outlined,
        PageLabel.logs: Icons.adb_outlined,
        PageLabel.tools: Icons.construction_outlined,
      },
    );
  });
}
