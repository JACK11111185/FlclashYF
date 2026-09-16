import 'dart:io';

import 'package:fl_clash/enum/enum.dart';

class RouteInput {
  const RouteInput({
    required this.action,
    required this.content,
    required this.url,
    required this.display,
  });

  final RuleAction? action;
  final String? content;
  final String? url;
  final String display;
}

RouteInput? classifyRouteInput(String input) {
  if (input.isEmpty || input.trim() != input || input.contains(RegExp(r'\s'))) {
    return null;
  }

  final uri = Uri.tryParse(input);
  if (uri?.hasScheme == true) {
    if ((uri!.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.hasEmptyPath && input.contains(':///')) {
      return null;
    }
    try {
      if (uri.hasPort && uri.port <= 0) return null;
    } on FormatException {
      return null;
    }
    final display = '${uri.scheme}://${uri.host}${uri.path}';
    return RouteInput(
      action: null,
      content: null,
      url: input,
      display: display,
    );
  }

  final slash = input.indexOf('/');
  if (slash != -1) {
    if (slash != input.lastIndexOf('/')) return null;
    final address = input.substring(0, slash);
    final prefix = int.tryParse(input.substring(slash + 1));
    final parsed = InternetAddress.tryParse(address);
    if (parsed == null || prefix == null) return null;
    final isV4 = parsed.type == InternetAddressType.IPv4;
    if (prefix < 0 || prefix > (isV4 ? 32 : 128)) return null;
    return RouteInput(
      action: isV4 ? RuleAction.IP_CIDR : RuleAction.IP_CIDR6,
      content: input,
      url: null,
      display: input,
    );
  }

  final address = InternetAddress.tryParse(input);
  if (address != null) {
    final isV4 = address.type == InternetAddressType.IPv4;
    final content = '$input/${isV4 ? 32 : 128}';
    return RouteInput(
      action: isV4 ? RuleAction.IP_CIDR : RuleAction.IP_CIDR6,
      content: content,
      url: null,
      display: content,
    );
  }

  if (_looksLikeIPv4(input)) return null;

  var domain = input;
  var action = RuleAction.DOMAIN;
  if (domain.startsWith('*.')) {
    domain = domain.substring(2);
    action = RuleAction.DOMAIN_SUFFIX;
  } else if (domain.startsWith('.')) {
    domain = domain.substring(1);
    action = RuleAction.DOMAIN_SUFFIX;
  }
  if (!_validDomain(domain)) return null;
  return RouteInput(
    action: action,
    content: domain,
    url: null,
    display: domain,
  );
}

bool _looksLikeIPv4(String value) {
  final labels = value.split('.');
  return labels.length == 4 &&
      labels.every((label) => int.tryParse(label) != null);
}

bool _validDomain(String value) {
  if (!value.contains('.') || value.length > 253) return false;
  final labels = value.split('.');
  if (labels.any((label) => label.isEmpty || label.length > 63)) return false;
  final asciiLabel = RegExp(
    r'^[A-Za-z0-9\u0080-\uFFFF](?:[A-Za-z0-9\u0080-\uFFFF-]*[A-Za-z0-9\u0080-\uFFFF])?$',
  );
  return labels.every(asciiLabel.hasMatch);
}
