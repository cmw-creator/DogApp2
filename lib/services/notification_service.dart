import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';

/// 简易 SSE 通知服务
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> _history = [];
  StreamSubscription<List<int>>? _subscription;
  bool _running = false;
  http.Client? _client;
  final StringBuffer _buffer = StringBuffer();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  List<Map<String, dynamic>> get historySnapshot =>
      List<Map<String, dynamic>>.from(_history);

  void start() {
    if (_running) return;
    _running = true;
    _connect();
  }

  void stop() {
    _running = false;
    _subscription?.cancel();
    _client?.close();
    _subscription = null;
    _client = null;
  }

  void _connect() async {
    while (_running) {
      try {
        _client = http.Client();
        final req = http.Request('GET', Uri.parse('${Api.serverUrl}/notifications/subscribe'));
        final resp = await _client!.send(req);
        if (resp.statusCode != 200) throw Exception('status ${resp.statusCode}');

        _subscription = resp.stream.listen(_handleChunk,
            onError: (_) => _retry(), onDone: _retry, cancelOnError: true);
        return; // 等待流结束
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void _retry([dynamic _]) {
    _subscription?.cancel();
    _client?.close();
    _subscription = null;
    _client = null;
    if (_running) {
      Future.delayed(const Duration(seconds: 2), _connect);
    }
  }

  void _handleChunk(List<int> chunk) {
    _buffer.write(utf8.decode(chunk));

    // SSE 事件以空行分隔（\n\n）。可能跨 chunk，需要累积缓冲再拆分。
    final text = _buffer.toString();
    final parts = text.split('\n\n');

    // 最后一个片段可能是不完整的，保留在缓冲
    _buffer.clear();
    if (!text.endsWith('\n\n')) {
      _buffer.write(parts.removeLast());
    }

    for (final part in parts) {
      // 每个 part 可能包含多行 data: ...
      for (final line in part.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final dataPart = trimmed.substring(5).trim();
        if (dataPart.isEmpty) continue;
        try {
          final decoded = json.decode(dataPart);
          if (decoded is Map<String, dynamic>) {
            _history.add(decoded);
            if (_history.length > 100) _history.removeAt(0);
            _controller.add(decoded);
          }
        } catch (_) {
          // ignore decode errors
        }
      }
    }
  }
}
