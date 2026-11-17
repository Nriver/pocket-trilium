class DeepLinkTarget {
  final String notePath;
  final Map<String, String> params;

  const DeepLinkTarget(this.notePath, [this.params = const {}]);

  String get fragment {
    if (params.isEmpty) return notePath;
    final query = params.entries
        .map((entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    return '$notePath?$query';
  }
}

class DeepLinkParser {
  static final RegExp _noteSegment =
      RegExp(r'^[_a-z0-9]{4,}$', caseSensitive: false);
  static const Set<String> _reservedHosts = {'note', 'open', 'link', 'n'};
  static const Set<String> _viewParams = {
    'viewMode',
    'attachmentId',
    'bookmark',
    'block',
    'column',
    'columnTitle',
    'columnIcon',
    'columnColor',
    'card',
    'page',
    'annotation',
    'searchTerms',
  };

  static DeepLinkTarget? parse(String? raw) {
    if (raw == null) return null;
    final String text = raw.trim();
    if (text.isEmpty) return null;

    final Uri? uri = Uri.tryParse(text);
    if (uri == null) return null;

    switch (uri.scheme.toLowerCase()) {
      case 'trilium':
        return _parseTrilium(uri, text);
      case 'http':
      case 'https':
        return _parseWeb(uri);
      default:
        return null;
    }
  }

  static DeepLinkTarget? _parseTrilium(Uri uri, String raw) {
    final String? nested = uri.queryParameters['url'];
    if (nested != null && nested.trim().isNotEmpty) {
      final DeepLinkTarget? inner = parse(nested);
      if (inner != null) return inner;
    }

    final DeepLinkTarget? fromFragment = _parseFragment(
      uri.fragment,
      requireRoot: false,
    );
    if (fromFragment != null) return fromFragment;

    final List<String> segments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final DeepLinkTarget? target = _targetFromPath(
        segments.join('/'),
        _parseQuery(uri.query),
      );
      if (target != null) return target;
    }

    final String host = _rawHost(raw) ?? uri.host;
    if (host.isNotEmpty && !_reservedHosts.contains(host.toLowerCase())) {
      return _targetFromPath(host, _parseQuery(uri.query));
    }

    return null;
  }

  static String? _rawHost(String raw) {
    final int schemeEnd = raw.indexOf('://');
    if (schemeEnd < 0) return null;

    String rest = raw.substring(schemeEnd + 3);
    final int end = rest.indexOf(RegExp(r'[/?#]'));
    if (end >= 0) {
      rest = rest.substring(0, end);
    }
    final int at = rest.lastIndexOf('@');
    if (at >= 0) {
      rest = rest.substring(at + 1);
    }
    return rest.isEmpty ? null : rest;
  }

  static DeepLinkTarget? _parseWeb(Uri uri) {
    if (uri.fragment.isEmpty) return null;
    return _parseFragment(uri.fragment, requireRoot: true);
  }

  static DeepLinkTarget? _parseFragment(
    String fragment, {
    required bool requireRoot,
  }) {
    String raw = fragment.trim();
    if (raw.startsWith('#')) {
      raw = raw.substring(1);
    }
    if (raw.isEmpty) return null;

    final int queryIndex = raw.indexOf('?');
    final String pathPart =
        queryIndex >= 0 ? raw.substring(0, queryIndex) : raw;
    final String queryPart =
        queryIndex >= 0 ? raw.substring(queryIndex + 1) : '';

    final String? path = _normalizePath(pathPart);
    if (path == null) return null;

    if (requireRoot && path.split('/').first != 'root') {
      return null;
    }

    return DeepLinkTarget(path, _filterParams(_parseQuery(queryPart)));
  }

  static DeepLinkTarget? _targetFromPath(
    String path,
    Map<String, String> params,
  ) {
    final String? normalized = _normalizePath(path);
    if (normalized == null) return null;
    return DeepLinkTarget(normalized, _filterParams(params));
  }

  static String? _normalizePath(String raw) {
    final List<String> segments = raw
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .map(_decode)
        .toList();

    if (segments.isEmpty) return null;
    if (!segments.every(_noteSegment.hasMatch)) return null;
    return segments.join('/');
  }

  static String _decode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  static Map<String, String> _parseQuery(String raw) {
    final Map<String, String> result = {};
    if (raw.isEmpty) return result;

    for (final String pair in raw.split('&')) {
      if (pair.isEmpty) continue;
      final int index = pair.indexOf('=');
      final String name = _decode(index >= 0 ? pair.substring(0, index) : pair);
      final String value = index >= 0 ? _decode(pair.substring(index + 1)) : '';
      if (name.isEmpty) continue;
      result[name] = value;
    }
    return result;
  }

  static Map<String, String> _filterParams(Map<String, String> params) {
    return {
      for (final entry in params.entries)
        if (_viewParams.contains(entry.key)) entry.key: entry.value,
    };
  }
}
