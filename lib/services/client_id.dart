import 'package:flutter/foundation.dart';

/// 为每个运行实例生成一个稳定的 clientId（进程级/页面级）。
///
/// - Web: 使用时间戳+随机数，保证同机开两个 Edge 标签页不会同名。
/// - 其他平台: 使用平台名即可（足够区分）。
class ClientId {
  ClientId._();

  static final String value = _generate();

  static String _generate() {
    if (kIsWeb) {
      final ms = DateTime.now().millisecondsSinceEpoch;
      final rand = (ms ^ (ms << 13) ^ (ms >> 7)) & 0xFFFFFFFF;
      return 'web-$ms-$rand';
    }
    return 'app';
  }
}
