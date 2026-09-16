part of '../state.dart';

@riverpod
ProfilesState profilesState(Ref ref) {
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final profiles = ref.watch(profilesProvider);
  return ProfilesState(profiles: profiles, currentProfileId: currentProfileId);
}

@riverpod
Profile? currentProfile(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  return ref.watch(
    profilesProvider.select((state) => state.getProfile(profileId)),
  );
}

@riverpod
Profile? profile(Ref ref, int? profileId) {
  return ref.watch(
    profilesProvider.select((state) => state.getProfile(profileId)),
  );
}

@riverpod
OverwriteType overwriteType(Ref ref, int? profileId) {
  return ref.watch(
    profileProvider(
      profileId,
    ).select((state) => state?.overwriteType ?? OverwriteType.standard),
  );
}

@riverpod
Future<ClashConfig> clashConfig(Ref ref, int profileId) async {
  final configMap = await ref.read(coreHandlerProvider).getConfig(profileId);
  return clashConfigTask(configMap);
}

@riverpod
Future<SetupState> setupState(Ref ref, int? profileId) async {
  final profile = ref.watch(profileProvider(profileId));
  final scriptId = profile?.scriptId;
  final profileLastUpdateDate = profile?.lastUpdateDate?.millisecondsSinceEpoch;
  final overwriteType = profile?.overwriteType ?? OverwriteType.standard;
  final dns = ref.watch(patchClashConfigProvider.select((state) => state.dns));
  final overrideDns = ref.watch(overrideDnsProvider);
  List<ProxyGroup> proxyGroups = [];
  List<Rule> rules = [];
  List<Rule> addedRules = [];
  List<ProxyGroup> routeGroups = [];
  List<Rule> routeRules = [];
  Map<String, dynamic> routeRuleProviders = {};
  Script? script;
  if (profileId != null) {
    routeGroups = await database.proxyGroupsDao
        .queryRouteManaged(profileId)
        .get();
    routeRules = await database.rulesDao
        .queryProfileRouteRules(profileId)
        .get();
    final providers = await database.routeRuleProvidersDao
        .query(profileId)
        .get();
    routeRuleProviders = {
      for (final provider in providers)
        provider.name: {
          'type': 'http',
          'url': provider.url,
          'behavior': provider.behavior,
          'format': provider.format,
          'interval': provider.interval,
        },
    };
    if (overwriteType == OverwriteType.standard) {
      addedRules = await database.rulesDao.queryAddedRules(profileId).get();
    } else if (overwriteType == OverwriteType.script) {
      script = scriptId == null
          ? null
          : await database.scriptsDao.get(scriptId).getSingleOrNull();
    } else {
      rules = await database.rulesDao.queryProfileCustomRules(profileId).get();
      proxyGroups = await database.proxyGroupsDao.query(profileId).get();
    }
  }
  return SetupState(
    rules: rules,
    proxyGroups: proxyGroups,
    profileId: profileId,
    profileLastUpdateDate: profileLastUpdateDate,
    overwriteType: overwriteType,
    addedRules: addedRules,
    routeGroups: routeGroups,
    routeRules: routeRules,
    routeRuleProviders: routeRuleProviders,
    script: script,
    overrideDns: overrideDns,
    dns: dns,
    matchTarget: overwriteType == OverwriteType.standard
        ? profile?.matchTarget
        : null,
  );
}
