import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Database database;

  setUp(() {
    database = Database(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'route rule providers DAO creates updates queries and deletes',
    () async {
      const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
      const provider = RouteRuleProvider(
        id: 10,
        name: 'private',
        profileId: 1,
        url: 'https://example.com/private.yaml',
        behavior: 'domain',
        format: 'yaml',
        interval: 86400,
      );
      await database.profiles.put(profile.toCompanion());

      await database.routeRuleProvidersDao.put(provider);
      expect(await database.routeRuleProvidersDao.query(1).get(), [provider]);

      final updated = provider.copyWith(interval: 3600);
      await database.routeRuleProvidersDao.put(updated);
      expect(await database.routeRuleProvidersDao.query(1).get(), [updated]);

      expect(await database.routeRuleProvidersDao.removeById(10), 1);
      expect(await database.routeRuleProvidersDao.query(1).get(), isEmpty);
    },
  );

  test('proxy group DAO separates route-managed and custom groups', () async {
    const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
    const custom = ProxyGroup(id: 20, name: 'Custom', type: GroupType.Selector);
    const route = ProxyGroup(
      id: 21,
      name: 'Route',
      type: GroupType.Selector,
      routeManaged: true,
    );
    await database.profiles.put(profile.toCompanion());
    await database.proxyGroups.put(custom.toCompanion(profile.id));
    await database.proxyGroups.put(route.toCompanion(profile.id));

    expect(await database.proxyGroupsDao.query(profile.id).get(), [
      custom.copyWith(profileId: 1),
    ]);
    expect(await database.proxyGroupsDao.queryRouteManaged(profile.id).get(), [
      route.copyWith(profileId: 1),
    ]);
  });

  test('route rules round-trip through the existing link table', () async {
    const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
    const rule = Rule(
      id: 30,
      ruleAction: RuleAction.DOMAIN_SUFFIX,
      content: 'example.com',
      ruleTarget: 'Route',
    );
    await database.profiles.put(profile.toCompanion());

    await database.rulesDao.putProfileRouteRule(profile.id, rule);

    expect(await database.rulesDao.queryProfileRouteRules(profile.id).get(), [
      rule,
    ]);
    final rawLink = await database
        .customSelect('SELECT scene FROM profile_rule_mapping')
        .getSingle();
    expect(rawLink.read<String>('scene'), RuleScene.route.name);
  });
}
