import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../logging/app_logger.dart';

enum PermissionType { storage, notifications, camera }

class PermissionResult {
  const PermissionResult({
    required this.type,
    required this.granted,
    this.permanentlyDenied = false,
    this.message,
  });

  final PermissionType type;
  final bool granted;
  final bool permanentlyDenied;
  final String? message;
}

class PermissionStrategy {
  PermissionStrategy(this._logger);
  final AppLogger _logger;

  static const _rationales = {
    PermissionType.storage: 'Для доступа к книгам на вашем устройстве',
    PermissionType.notifications: 'Для уведомлений о загрузках',
    PermissionType.camera: 'Для сканирования QR-кодов',
  };

  String getRationale(PermissionType type) {
    return _rationales[type] ?? 'Для работы приложения';
  }

  Future<PermissionResult> requestIfNeeded(PermissionType type) async {
    final permission = _mapToPermission(type);
    if (permission == null) {
      return PermissionResult(
        type: type,
        granted: true,
        message: 'Разрешение не требуется на этой платформе',
      );
    }

    final status = await permission.status;

    if (status.isGranted) {
      return PermissionResult(type: type, granted: true);
    }

    if (status.isPermanentlyDenied) {
      _logger.warning(
        'Permission permanently denied: ${type.name}',
        name: 'Permissions',
      );
      return PermissionResult(
        type: type,
        granted: false,
        permanentlyDenied: true,
        message: 'Разрешение отклонено навсегда. Включите в настройках.',
      );
    }

    final result = await permission.request();
    final granted = result.isGranted;

    _logger.info(
      'Permission ${type.name}: ${granted ? "granted" : "denied"}',
      name: 'Permissions',
    );

    return PermissionResult(
      type: type,
      granted: granted,
      message: granted ? null : 'Доступ не предоставлен',
    );
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  Permission? _mapToPermission(PermissionType type) {
    switch (type) {
      case PermissionType.storage:
        return Permission.storage;
      case PermissionType.notifications:
        return Permission.notification;
      case PermissionType.camera:
        return Permission.camera;
    }
  }

  Future<bool> hasPermission(PermissionType type) async {
    final permission = _mapToPermission(type);
    if (permission == null) return true;
    final status = await permission.status;
    return status.isGranted;
  }
}

// --- Riverpod provider ---

final permissionStrategyProvider = Provider<PermissionStrategy>((ref) {
  throw UnimplementedError('Override in main');
});
