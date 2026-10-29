import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WebViewScripts {
  static const String _assetDir = 'assets/js/';
  static final Map<String, String> _scripts = {};

  static Future<void> preload() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final paths = manifest.listAssets().where(
            (path) => path.startsWith(_assetDir) && path.endsWith('.js'),
      );

      for (final path in paths) {
        _scripts[path.substring(_assetDir.length)] =
        await rootBundle.loadString(path);
      }
    } catch (e) {
      debugPrint('加载网页脚本失败: $e');
    }
  }

  static String get(
      String name, {
        Map<String, String> replacements = const {},
      }) {
    final template = _scripts[name];

    if (template == null) {
      debugPrint('未找到网页脚本: $name');
      return '';
    }

    var script = template;
    replacements.forEach((key, value) {
      script = script.replaceAll(key, value);
    });

    return script;
  }
}
