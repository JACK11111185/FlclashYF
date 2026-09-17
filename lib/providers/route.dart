import 'package:drift/drift.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routeGroupsProvider = StreamProvider.autoDispose
    .family<List<ProxyGroup>, int>(
      (ref, profileId) =>
          database.proxyGroupsDao.queryRouteManaged(profileId).watch(),
    );

final routeRulesProvider = StreamProvider.autoDispose.family<List<Rule>, int>(
  (ref, profileId) =>
      database.rulesDao.queryProfileRouteRules(profileId).watch(),
);

final routeRuleProviderItemsProvider = StreamProvider.autoDispose
    .family<List<RouteRuleProvider>, int>(
      (ref, profileId) =>
          database.routeRuleProvidersDao.query(profileId).watch(),
    );

class RouteStore {
  const RouteStore(this.profileId);

  final int profileId;

  Future<void> putGroup(ProxyGroup group) async {
    await database.proxyGroupsDao.put(group, profileId);
  }

  Future<void> removeGroup(int id) async {
    await database.proxyGroups.remove(
      (row) => row.profileId.equals(profileId) & row.id.equals(id),
    );
  }

  Future<void> putRule(Rule rule) {
    return database.rulesDao.putProfileRouteRule(profileId, rule);
  }

  Future<void> putRoutes({
    required List<Rule> rules,
    List<RouteRuleProvider> providers = const [],
  }) {
    return database.transaction(() async {
      for (final provider in providers) {
        await database.routeRuleProvidersDao.put(provider);
      }
      for (final rule in rules) {
        await database.rulesDao.putProfileRouteRule(profileId, rule);
      }
    });
  }

  Future<void> removeRule(int id) {
    return database.rulesDao.delRules([id]);
  }

  Future<void> putProvider(RouteRuleProvider provider) async {
    await database.routeRuleProvidersDao.put(provider);
  }

  Future<void> removeProvider(int id) async {
    await database.routeRuleProvidersDao.removeById(id);
  }
}

final routeStoreProvider = Provider.autoDispose.family<RouteStore, int>(
  (ref, profileId) => RouteStore(profileId),
);
