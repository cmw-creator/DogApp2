class WebEventSource {
  WebEventSource._();

  static WebEventSource? connect(
    String url, {
    void Function()? onOpen,
    void Function(dynamic error)? onError,
    void Function(String data)? onMessage,
  }) {
    // Non-web platforms: no-op; return null.
    return null;
  }

  void close() {}
}
