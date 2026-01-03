import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'client_id.dart';
import 'web_event_source.dart';

/// 简易 SSE 通知服务
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> _history = [];
  final List<Map<String, dynamic>> _pendingForUi = [];
  StreamSubscription<List<int>>? _subscription;
  bool _running = false;
  http.Client? _client;
  final StringBuffer _buffer = StringBuffer();
  final String clientId = '${_defaultClientId()}-${ClientId.value}';

  bool _uiReady = false;

  bool debugEnabled = false;

  void _log(String msg) {
    if (!debugEnabled) return;
    debugPrint('[NotificationService][$clientId] $msg');
  }

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  List<Map<String, dynamic>> get historySnapshot =>
      List<Map<String, dynamic>>.from(_history);

  /// UI 是否已经完成首帧并开始监听通知流。
  ///
  /// 目的：避免事件在 app 启动早期到达时，因为还没人订阅 stream 而“看起来没反应”。
  void setUiReady() {
    if (_uiReady) return;
    _uiReady = true;
    _emitPendingToUi();
  }

  void _emitPendingToUi() {
    if (!_uiReady) return;
    if (_pendingForUi.isEmpty) return;

    final pending = List<Map<String, dynamic>>.from(_pendingForUi);
    _pendingForUi.clear();
    for (final e in pending) {
      _controller.add(e);
    }
  }

  void start() {
    if (_running) return;
    _running = true;
    _log('start() serverUrl=${Api.serverUrl}');
    if (kIsWeb) {
      _connectWeb();
    } else {
      _connect();
    }
  }

  void stop() {
    _running = false;
    _log('stop()');
    _subscription?.cancel();
    _client?.close();
    _subscription = null;
    _client = null;

    _es?.close();
    _es = null;
  }

  WebEventSource? _es;

  void _connectWeb() {
    if (!_running) return;
    final url = '${Api.serverUrl}/notifications/subscribe?client_id=$clientId';
    _log('connectWeb() url=$url');

    try {
      _es?.close();
      _es = WebEventSource.connect(
        url,
        onOpen: () => _log('EventSource open'),
        onError: (event) {
          _log('EventSource error; will reconnect');
          _es?.close();
          _es = null;
          if (_running) {
            Future.delayed(const Duration(seconds: 2), _connectWeb);
          }
        },
        onMessage: (dataStr) {
          _handleSseDataLine(dataStr);
        },
      );
    } catch (e) {
      _log('connectWeb exception: $e');
      if (_running) {
        Future.delayed(const Duration(seconds: 2), _connectWeb);
      }
    }
  }

  void _connect() async {
    while (_running) {
      try {
        _client = http.Client();
        _log('connecting...');
        final req = http.Request(
          'GET',
          Uri.parse('${Api.serverUrl}/notifications/subscribe?client_id=$clientId'),
        );
        final resp = await _client!.send(req);
        _log('connected status=${resp.statusCode}');
        if (resp.statusCode != 200) throw Exception('status ${resp.statusCode}');

        _subscription = resp.stream.listen(_handleChunk,
            onError: (_) => _retry(), onDone: _retry, cancelOnError: true);
        return; // 等待流结束
      } catch (e) {
        _log('connect error: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void _retry([dynamic _]) {
    _log('retry()');
    _subscription?.cancel();
    _client?.close();
    _subscription = null;
    _client = null;
    if (_running) {
      Future.delayed(const Duration(seconds: 2), _connect);
    }
  }

  void _handleChunk(List<int> chunk) {
    _buffer.write(utf8.decode(chunk, allowMalformed: true));

    // SSE 事件以空行分隔（\n\n 或 \r\n\r\n）。可能跨 chunk，需要累积缓冲再拆分。
    final text = _buffer.toString();
    final parts = text.replaceAll('\r\n', '\n').split('\n\n');

    // 最后一个片段可能是不完整的，保留在缓冲
    _buffer.clear();
    final normalized = text.replaceAll('\r\n', '\n');
    if (!normalized.endsWith('\n\n')) {
      _buffer.write(parts.removeLast());
    }

    for (final part in parts) {
      // 每个 part 可能包含多行 data: ...
      for (final line in part.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final dataPart = trimmed.substring(5).trim();
        if (dataPart.isEmpty) continue;
        _handleSseDataLine(dataPart);
      }
    }
  }

  void _handleSseDataLine(String dataPart) {
    if (dataPart.isEmpty) return;
    try {
      final decoded = json.decode(dataPart);
      if (decoded is! Map) return;
      final mapped = Map<String, dynamic>.from(decoded);
      final type = mapped['type']?.toString();
      _log('event type=$type raw=$mapped');
      _history.add(mapped);
      if (_history.length > 100) _history.removeAt(0);

      // 如果 UI 还没 ready，先缓存，等 UI ready 后补发。
      if (_uiReady) {
        _controller.add(mapped);
      } else {
        _pendingForUi.add(mapped);
        if (_pendingForUi.length > 50) _pendingForUi.removeAt(0);
      }

      // 对非 ping/hello 的业务通知发送 ack，方便另一端感知送达
      try {
        final id = mapped['id'];
        if (id is int && type != 'ping' && type != 'hello' && type != 'ack') {
          _log('sending ack id=$id');
          Api.ackNotification(id: id, clientId: clientId);
        }
      } catch (_) {}
    } catch (e) {
      _log('decode error: $e dataPart=$dataPart');
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistory({int limit = 50}) async {
    _log('fetchHistory limit=$limit');
    final list = await Api.getNotificationHistory(limit: limit);
    if (list == null) return [];
    final mapped = list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _log('history size=${mapped.length}');
    return mapped;
  }
}

String _defaultClientId() {
  try {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
  } catch (_) {}
  return 'unknown';
}
