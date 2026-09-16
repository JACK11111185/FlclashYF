Map<String, dynamic> mergeAdditiveRouteConfig(
  Map<String, dynamic> config, {
  List<Map<String, dynamic>> groups = const [],
  List<dynamic> rules = const [],
  Map<String, dynamic> ruleProviders = const {},
}) {
  final existingProxyNames = <dynamic>{
    for (final group in config['proxy-groups'] ?? const [])
      if (group is Map) group['name'],
    for (final proxy in config['proxies'] ?? const [])
      if (proxy is Map) proxy['name'],
  };
  for (final group in groups) {
    final name = group['name'];
    if (!existingProxyNames.add(name)) {
      throw ArgumentError.value(name, 'groups', 'Duplicate proxy name');
    }
  }

  final existingProviderNames = <dynamic>{...?config['rule-providers']?.keys};
  for (final name in ruleProviders.keys) {
    if (!existingProviderNames.add(name)) {
      throw ArgumentError.value(
        name,
        'ruleProviders',
        'Duplicate rule provider name',
      );
    }
  }

  final result = _copyMap(config);
  if (config.containsKey('proxy-groups') || groups.isNotEmpty) {
    result['proxy-groups'] = _copyValue([
      ...?config['proxy-groups'],
      ...groups,
    ]);
  }
  if (config.containsKey('rules') || rules.isNotEmpty) {
    result['rules'] = _copyValue([...rules, ...?config['rules']]);
  }
  if (config.containsKey('rule-providers') || ruleProviders.isNotEmpty) {
    result['rule-providers'] = _copyValue({
      ...?config['rule-providers'],
      ...ruleProviders,
    });
  }
  return result;
}

Map<String, dynamic> _copyMap(Map<dynamic, dynamic> source) {
  return source.map((key, value) => MapEntry(key as String, _copyValue(value)));
}

dynamic _copyValue(dynamic value) {
  return switch (value) {
    Map<dynamic, dynamic>() => _copyMap(value),
    List<dynamic>() => value.map(_copyValue).toList(),
    Set<dynamic>() => value.map(_copyValue).toSet(),
    _ => value,
  };
}
