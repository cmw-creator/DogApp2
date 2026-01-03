import 'dart:async';

import 'package:flutter/material.dart';

enum InAppNotificationSeverity {
  info,
  warning,
  danger,
}

class InAppNotificationEvent {
  final String title;
  final String message;
  final InAppNotificationSeverity severity;
  final String? actionLabel;
  final VoidCallback? onAction;
  final DateTime timestamp;
  final Duration? autoDismiss;

  InAppNotificationEvent({
    required this.title,
    required this.message,
    required this.severity,
    this.actionLabel,
    this.onAction,
    DateTime? timestamp,
    this.autoDismiss,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 全局应用内通知（替代系统通知）。
///
/// 用法：
/// - 在 `MaterialApp.builder` 里包一层 `InAppNotificationOverlay`
/// - 调用 `InAppNotification.instance.show(...)` 即可弹出
class InAppNotification {
  InAppNotification._();
  static final InAppNotification instance = InAppNotification._();

  final StreamController<InAppNotificationEvent> _controller =
      StreamController<InAppNotificationEvent>.broadcast();

  Stream<InAppNotificationEvent> get stream => _controller.stream;

  void show({
    required String title,
    required String message,
    InAppNotificationSeverity severity = InAppNotificationSeverity.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? autoDismiss,
  }) {
    _controller.add(
      InAppNotificationEvent(
        title: title,
        message: message,
        severity: severity,
        actionLabel: actionLabel,
        onAction: onAction,
        autoDismiss: autoDismiss,
      ),
    );
  }
}

class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({Key? key, required this.child})
      : super(key: key);

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  StreamSubscription<InAppNotificationEvent>? _sub;
  bool _showing = false;
  final List<InAppNotificationEvent> _queue = [];

  @override
  void initState() {
    super.initState();
    _sub = InAppNotification.instance.stream.listen(_enqueue);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color _colorFor(InAppNotificationSeverity s, ColorScheme scheme) {
    switch (s) {
      case InAppNotificationSeverity.info:
        return scheme.primary;
      case InAppNotificationSeverity.warning:
        return Colors.orange;
      case InAppNotificationSeverity.danger:
        return scheme.error;
    }
  }

  IconData _iconFor(InAppNotificationSeverity s) {
    switch (s) {
      case InAppNotificationSeverity.info:
        return Icons.notifications;
      case InAppNotificationSeverity.warning:
        return Icons.warning_amber_rounded;
      case InAppNotificationSeverity.danger:
        return Icons.crisis_alert;
    }
  }

  void _enqueue(InAppNotificationEvent event) {
    if (!mounted) return;
    _queue.add(event);
    _drain();
  }

  Future<void> _drain() async {
    if (_showing) return;
    _showing = true;
    try {
      while (mounted && _queue.isNotEmpty) {
        final event = _queue.removeAt(0);

        // 避免在构建/路由切换中弹窗
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;

        // 优先用横幅（不打断用户）；需要确认时才用弹窗。
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          final scheme = Theme.of(context).colorScheme;
          final color = _colorFor(event.severity, scheme);
          final bar = MaterialBanner(
            leading: Icon(_iconFor(event.severity), color: color),
            content: Text('${event.title}\n${event.message}'),
            actions: [
              if (event.actionLabel != null && event.onAction != null)
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentMaterialBanner();
                    event.onAction?.call();
                  },
                  child: Text(event.actionLabel!),
                ),
              TextButton(
                onPressed: () => messenger.hideCurrentMaterialBanner(),
                child: const Text('关闭'),
              ),
            ],
          );
          messenger.hideCurrentMaterialBanner();
          messenger.showMaterialBanner(bar);

          final dismiss = event.autoDismiss ?? const Duration(seconds: 4);
          Future.delayed(dismiss, () {
            if (mounted) messenger.hideCurrentMaterialBanner();
          });
        } else {
          // 如果拿不到 ScaffoldMessenger（极少），降级为弹窗。
          await showDialog<void>(
            context: context,
            builder: (ctx) {
              final scheme = Theme.of(ctx).colorScheme;
              final color = _colorFor(event.severity, scheme);
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(_iconFor(event.severity), color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(event.title)),
                  ],
                ),
                content: Text(event.message),
                actions: [
                  if (event.actionLabel != null && event.onAction != null)
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        event.onAction?.call();
                      },
                      child: Text(event.actionLabel!),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        }
      }
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
