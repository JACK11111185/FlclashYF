part of 'database.dart';

@DataClassName('RouteRuleProvider')
class RouteRuleProviders extends Table {
  @override
  String get tableName => 'route_rule_providers';

  IntColumn get id => integer()();

  TextColumn get name => text()();

  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get url => text()();

  TextColumn get behavior => text()();

  TextColumn get format => text()();

  IntColumn get interval => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [RouteRuleProviders])
class RouteRuleProvidersDao extends DatabaseAccessor<Database>
    with _$RouteRuleProvidersDaoMixin {
  RouteRuleProvidersDao(super.attachedDatabase);

  Selectable<RouteRuleProvider> query(int profileId) {
    return routeRuleProviders.select()
      ..where((row) => row.profileId.equals(profileId))
      ..orderBy([(row) => OrderingTerm.asc(row.name)]);
  }

  Future<int> put(RouteRuleProvider provider) {
    return routeRuleProviders.insertOnConflictUpdate(provider);
  }

  Future<int> removeById(int id) {
    return routeRuleProviders.remove((row) => row.id.equals(id));
  }
}
