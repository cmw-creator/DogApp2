// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebEventSource {
  final html.EventSource _inner;

  WebEventSource._(this._inner);

  static WebEventSource? connect(
    String url, {
    void Function()? onOpen,
    void Function(dynamic error)? onError,
    void Function(String data)? onMessage,
  }) {
    final es = html.EventSource(url);
    if (onOpen != null) es.onOpen.listen((_) => onOpen());
    if (onError != null) es.onError.listen((event) => onError(event));
    if (onMessage != null) {
      es.onMessage.listen((event) {
        final data = event.data;
        if (data != null) onMessage(data.toString());
      });
    }
    return WebEventSource._(es);
  }

  void close() => _inner.close();
}
