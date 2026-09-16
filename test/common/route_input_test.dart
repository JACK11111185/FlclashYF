import 'package:fl_clash/common/route_input.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyRouteInput', () {
    test('classifies exact IPv4 addresses as host CIDRs', () {
      final result = classifyRouteInput('192.0.2.1');

      expect(result?.action, RuleAction.IP_CIDR);
      expect(result?.content, '192.0.2.1/32');
      expect(result?.url, isNull);
      expect(result?.display, '192.0.2.1/32');
    });

    test('classifies exact IPv6 addresses as host CIDRs', () {
      final result = classifyRouteInput('2001:db8::1');

      expect(result?.action, RuleAction.IP_CIDR6);
      expect(result?.content, '2001:db8::1/128');
      expect(result?.url, isNull);
    });

    test('accepts IPv4 CIDRs including boundary prefixes', () {
      for (final input in ['0.0.0.0/0', '192.0.2.1/24', '255.255.255.255/32']) {
        final result = classifyRouteInput(input);
        expect(result?.action, RuleAction.IP_CIDR, reason: input);
        expect(result?.content, input, reason: input);
      }
    });

    test('accepts IPv6 CIDRs including boundary prefixes', () {
      for (final input in ['::/0', '2001:db8::/64', '::1/128']) {
        final result = classifyRouteInput(input);
        expect(result?.action, RuleAction.IP_CIDR6, reason: input);
        expect(result?.content, input, reason: input);
      }
    });

    test('classifies only HTTP and HTTPS URLs as rule-set URLs', () {
      for (final input in [
        'https://example.com/rules.yaml',
        'http://例子.测试/rules.txt?token=secret#part',
      ]) {
        final result = classifyRouteInput(input);
        expect(result?.action, isNull, reason: input);
        expect(result?.content, isNull, reason: input);
        expect(result?.url, input, reason: input);
      }
    });

    test(
      'provides a URL display that omits credentials query and fragment',
      () {
        final result = classifyRouteInput(
          'https://user:password@example.com/rules.yaml?token=secret#part',
        );

        expect(result?.display, 'https://example.com/rules.yaml');
        expect(
          result?.url,
          'https://user:password@example.com/rules.yaml?token=secret#part',
        );
      },
    );

    test('classifies exact domains and preserves Unicode', () {
      for (final input in ['example.com', 'sub.example.com', '例子.测试']) {
        final result = classifyRouteInput(input);
        expect(result?.action, RuleAction.DOMAIN, reason: input);
        expect(result?.content, input, reason: input);
        expect(result?.display, input, reason: input);
      }
    });

    test('normalizes domain suffix markers', () {
      for (final input in ['*.example.com', '.example.com']) {
        final result = classifyRouteInput(input);
        expect(result?.action, RuleAction.DOMAIN_SUFFIX, reason: input);
        expect(result?.content, 'example.com', reason: input);
        expect(result?.display, 'example.com', reason: input);
      }
    });

    test('rejects malformed and unsupported inputs', () {
      const rejected = [
        '',
        ' example.com',
        'example.com ',
        'example .com',
        'localhost',
        'plainword',
        'ftp://example.com/rules.yaml',
        'mailto:user@example.com',
        'example.com:443',
        'https://example.com:bad/rules.yaml',
        'https:///rules.yaml',
        '256.0.0.1',
        '192.0.2.1/33',
        '192.0.2.1/-1',
        '192.0.2.1/24/1',
        '2001:db8::1/129',
        '2001:db8::g/64',
        '*.localhost',
        '*.*.example.com',
        '-bad.example',
        'bad-.example',
        'bad..example',
        'bad_example.com',
        'example.com/path',
        '[2001:db8::1]:443',
      ];

      for (final input in rejected) {
        expect(classifyRouteInput(input), isNull, reason: input);
      }
    });
  });
}
