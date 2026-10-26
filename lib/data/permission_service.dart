import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles Android storage permission requests, adapting to SDK version.
/// - Android 13+ (API 33+): uses READ_MEDIA_VIDEO
/// - Android 10-12 (API 29-32): uses READ_EXTERNAL_STORAGE
/// - Android ≤9 (API ≤28): uses READ_EXTERNAL_STORAGE
///
/// Uses flutter's native SystemChannels instead of device_info_plus to keep
/// the package footprint small.
class PermissionService {
  static int? _androidSdkVersion;

  static const _channel = MethodChannel('flutter/system_info');

  static Future<int> _getSdkVersion() async {
    if (_androidSdkVersion != null) return _androidSdkVersion!;
    if (!Platform.isAndroid) return 0;
    try {
      // android.os.Build.VERSION.SDK_INT is available via SystemChannels
      final result = await _channel.invokeMethod<int>('getSdkVersion');
      _androidSdkVersion = result ?? 0;
    } catch (_) {
      // Fallback: assume Android 13+ to use the safer permission
      _androidSdkVersion = 33;
    }
    return _androidSdkVersion!;
  }

  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _getSdkVersion();
    if (sdk >= 33) {
      return (await Permission.videos.status).isGranted;
    }
    return (await Permission.storage.status).isGranted;
  }

  static Future<PermissionStatus> requestStoragePermission() async {
    if (!Platform.isAndroid) return PermissionStatus.granted;
    final sdk = await _getSdkVersion();
    if (sdk >= 33) return Permission.videos.request();
    return Permission.storage.request();
  }

  static Future<bool> ensureStoragePermission() async {
    if (await hasStoragePermission()) return true;
    final status = await requestStoragePermission();
    return status.isGranted;
  }

  static Future<bool> isPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;
    final sdk = await _getSdkVersion();
    if (sdk >= 33) {
      return (await Permission.videos.status).isPermanentlyDenied;
    }
    return (await Permission.storage.status).isPermanentlyDenied;
  }

  static Future<void> openSettings() => openAppSettings();

  static Future<bool> requestWithRationale(BuildContext context) async {
    if (await hasStoragePermission()) return true;

    if (await isPermanentlyDenied()) {
      if (context.mounted) await _showPermanentlyDeniedDialog(context);
      return false;
    }

    if (context.mounted) {
      final ok = await _showRationaleDialog(context);
      if (!ok) return false;
    }

    final status = await requestStoragePermission();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      await _showPermanentlyDeniedDialog(context);
    }
    return false;
  }

  static Future<bool> _showRationaleDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Autorisation requise'),
            content: const Text(
              'VidéoLib a besoin d\'accéder à vos fichiers vidéo '
              'pour afficher et lire vos vidéos locales.\n\n'
              'Aucune donnée n\'est envoyée à un serveur externe.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Autoriser'),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Autorisation refusée'),
        content: const Text(
          'L\'accès au stockage a été refusé définitivement.\n\n'
          'Veuillez l\'activer manuellement dans les paramètres de l\'application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }
}
