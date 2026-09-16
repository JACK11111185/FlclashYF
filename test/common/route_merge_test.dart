import 'package:fl_clash/common/route_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeAdditiveRouteConfig', () {
    test('rejects a route group name used by an existing group', () {
      final config = <String, dynamic>{
        'proxy-groups': [
          <String, dynamic>{'name': 'Taken', 'type': 'select'},
        ],
      };

      expect(
        () => mergeAdditiveRouteConfig(
          config,
          groups: [
            <String, dynamic>{'name': 'Taken', 'type': 'select'},
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a route group name used by an existing proxy', () {
      final config = <String, dynamic>{
        'proxies': [
          <String, dynamic>{'name': 'Taken', 'type': 'ss'},
        ],
      };

      expect(
        () => mergeAdditiveRouteConfig(
          config,
          groups: [
            <String, dynamic>{'name': 'Taken', 'type': 'select'},
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects duplicate names among route groups', () {
      final groups = [
        <String, dynamic>{'name': 'Repeated', 'type': 'select'},
        <String, dynamic>{'name': 'Repeated', 'type': 'url-test'},
      ];

      expect(
        () => mergeAdditiveRouteConfig(<String, dynamic>{}, groups: groups),
        throwsArgumentError,
      );
    });

    test('rejects a duplicate rule provider name', () {
      final config = <String, dynamic>{
        'rule-providers': {
          'taken': <String, dynamic>{'type': 'file', 'path': './taken.yaml'},
        },
      };

      expect(
        () => mergeAdditiveRouteConfig(
          config,
          ruleProviders: {
            'taken': <String, dynamic>{
              'type': 'http',
              'url': 'https://example.com/taken.yaml',
            },
          },
        ),
        throwsArgumentError,
      );
    });

    test('merges rule providers without replacing existing providers', () {
      final config = <String, dynamic>{
        'rule-providers': {
          'existing': <String, dynamic>{
            'type': 'http',
            'url': 'https://example.com/existing.yaml',
          },
        },
      };
      final routeProviders = <String, dynamic>{
        'route': <String, dynamic>{
          'type': 'http',
          'url': 'https://example.com/route.yaml',
        },
      };

      final result = mergeAdditiveRouteConfig(
        config,
        ruleProviders: routeProviders,
      );

      expect(result['rule-providers'], {
        'existing': config['rule-providers']['existing'],
        'route': routeProviders['route'],
      });
    });

    test('does not add empty route sections to a config', () {
      final config = <String, dynamic>{
        'mixed-port': 7890,
        'meta': <String, dynamic>{'enabled': true},
      };

      final result = mergeAdditiveRouteConfig(config);

      expect(result, config);
      expect(result, isNot(same(config)));
      expect(result.containsKey('proxy-groups'), isFalse);
      expect(result.containsKey('rules'), isFalse);
      expect(result.containsKey('rule-providers'), isFalse);
    });

    test('does not mutate inputs or share nested mutable structures', () {
      final config = <String, dynamic>{
        'meta': <String, dynamic>{'enabled': true},
        'proxy-groups': [
          <String, dynamic>{
            'name': 'Existing',
            'type': 'select',
            'proxies': ['DIRECT'],
          },
        ],
        'rules': ['MATCH,Existing'],
        'rule-providers': {
          'existing': <String, dynamic>{'type': 'file'},
        },
      };
      final groups = [
        <String, dynamic>{
          'name': 'Route',
          'type': 'select',
          'proxies': ['Existing'],
        },
      ];
      final rules = ['DOMAIN,example.com,Route'];
      final providers = <String, dynamic>{
        'route': <String, dynamic>{'type': 'http'},
      };

      final result = mergeAdditiveRouteConfig(
        config,
        groups: groups,
        rules: rules,
        ruleProviders: providers,
      );
      (result['meta'] as Map<String, dynamic>)['enabled'] = false;
      (result['proxy-groups'] as List)[0]['proxies'].add('REJECT');
      (result['proxy-groups'] as List)[1]['proxies'].add('DIRECT');
      (result['rule-providers'] as Map)['existing']['type'] = 'http';
      (result['rule-providers'] as Map)['route']['type'] = 'file';

      expect(config['meta'], {'enabled': true});
      expect(config['proxy-groups'][0]['proxies'], ['DIRECT']);
      expect(groups[0]['proxies'], ['Existing']);
      expect(config['rule-providers']['existing'], {'type': 'file'});
      expect(providers['route'], {'type': 'http'});
      expect(config['rules'], ['MATCH,Existing']);
      expect(rules, ['DOMAIN,example.com,Route']);
    });

    test('appends groups and prepends rules while preserving config', () {
      final config = <String, dynamic>{
        'mixed-port': 7890,
        'proxy-groups': [
          <String, dynamic>{
            'name': 'Existing',
            'type': 'select',
            'proxies': ['DIRECT'],
          },
        ],
        'rules': ['MATCH,Existing'],
      };
      final routeGroups = [
        <String, dynamic>{
          'name': 'Route',
          'type': 'select',
          'proxies': ['Existing'],
        },
      ];
      final routeRules = ['DOMAIN,example.com,Route'];

      final result = mergeAdditiveRouteConfig(
        config,
        groups: routeGroups,
        rules: routeRules,
      );

      expect(result['mixed-port'], 7890);
      expect(result['proxy-groups'], [
        config['proxy-groups'][0],
        routeGroups[0],
      ]);
      expect(result['rules'], ['DOMAIN,example.com,Route', 'MATCH,Existing']);
    });
  });
}
