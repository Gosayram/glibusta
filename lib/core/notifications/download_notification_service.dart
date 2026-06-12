import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/models/download_task.dart';
import '../logging/app_logger.dart';

part 'download_notification_service.g.dart';

@riverpod
DownloadNotificationService downloadNotificationService(Ref ref) {
  final service = DownloadNotificationService();
  ref.onDispose(() => service.dispose());
  return service;
}

class DownloadNotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final AppLogger _logger = AppLogger();

  static const _downloadChannelId = 'glibusta_downloads';
  static const _downloadChannelName = 'Загрузки книг';
  static const _downloadChannelDescription = 'Прогресс загрузки книг и статус';

  int _notificationId(String taskId) {
    return 1000 + (taskId.hashCode & 0x7FFFFFFF) % 9000;
  }

  Future<void> showProgress({
    required DownloadTask task,
    required double speedBytesPerSec,
  }) async {
    final received = task.downloadedBytes ?? 0;
    final total = task.totalBytes;
    final title = task.bookTitle ?? 'Загрузка';
    final format = task.format.name.toUpperCase();

    String body;
    if (total != null && total > 0) {
      final progress = (received / total * 100).toInt();
      final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
      final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
      final speed = _formatSpeed(speedBytesPerSec);
      body = '$format — $progress% ($receivedMb / $totalMb МБ) • $speed';
    } else {
      final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
      final speed = _formatSpeed(speedBytesPerSec);
      body = '$format — $receivedMb МБ • $speed';
    }

    final maxProgress = total != null && total > 0 ? 100 : 0;

    final androidDetails = AndroidNotificationDetails(
      _downloadChannelId,
      _downloadChannelName,
      channelDescription: _downloadChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showProgress: true,
      maxProgress: maxProgress,
      progress: total != null && total > 0 ? (received / total * 100).toInt() : 0,
      onlyAlertOnce: true,
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: _notificationId(task.id),
        title: title,
        body: body,
        notificationDetails: details,
      );
    } on Object catch (e) {
      _logger.warning(
        'Failed to show progress notification: $e',
        name: 'DownloadNotification',
        error: e,
      );
    }
  }

  Future<void> showCompleted(DownloadTask task) async {
    final title = task.bookTitle ?? 'Загрузка завершена';
    final format = task.format.name.toUpperCase();
    final body = '$format — загрузка завершена';

    final androidDetails = const AndroidNotificationDetails(
      _downloadChannelId,
      _downloadChannelName,
      channelDescription: _downloadChannelDescription,
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: _notificationId(task.id),
        title: title,
        body: body,
        notificationDetails: details,
      );
    } on Object catch (e) {
      _logger.warning(
        'Failed to show completed notification: $e',
        name: 'DownloadNotification',
        error: e,
      );
    }
  }

  Future<void> showFailed(DownloadTask task, String? error) async {
    final title = task.bookTitle ?? 'Ошибка загрузки';
    final format = task.format.name.toUpperCase();
    final body = '$format — ${error ?? 'Неизвестная ошибка'}';

    final androidDetails = const AndroidNotificationDetails(
      _downloadChannelId,
      _downloadChannelName,
      channelDescription: _downloadChannelDescription,
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: _notificationId(task.id),
        title: title,
        body: body,
        notificationDetails: details,
      );
    } on Object catch (e) {
      _logger.warning(
        'Failed to show failed notification: $e',
        name: 'DownloadNotification',
        error: e,
      );
    }
  }

  Future<void> cancel(String taskId) async {
    try {
      await _plugin.cancel(id: _notificationId(taskId));
    } on Object catch (e) {
      _logger.warning('Failed to cancel notification: $e', name: 'DownloadNotification', error: e);
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '';
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} Б/с';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} КБ/с';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} МБ/с';
  }

  void dispose() {}
}
