import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Service responsible for validating whether the host machine holds
/// an active, unexpired AsarNegar subscription before granting access to DeskNegar.
/// Follows the Single Responsibility Principle.
class SubscriptionGuard {
  SubscriptionGuard._();

  /// Validates the existence and validity of the AsarNegar license token.
  /// Checks %APPDATA%\DeskNegar\config\asarnegar_license.token,
  /// falling back to %APPDATA%\AsarNegar\asarnegar_license.token.
  static bool hasActiveSubscription() {
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData == null || appData.isEmpty) {
        return false;
      }

      // 1. Primary path in DeskNegar configuration directory
      final primaryFile = File('$appData/DeskNegar/config/asarnegar_license.token');
      if (primaryFile.existsSync()) {
        if (_isTokenValid(primaryFile)) {
          return true;
        }
      }

      // 2. Fallback path in AsarNegar directory
      final altFile = File('$appData/AsarNegar/asarnegar_license.token');
      if (altFile.existsSync()) {
        if (_isTokenValid(altFile)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('[SubscriptionGuard] Token validation error: $e');
      return false;
    }
  }

  static bool _isTokenValid(File file) {
    try {
      final raw = file.readAsStringSync().trim();
      if (raw.isEmpty) return false;

      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return false;

      // Status must explicitly be active
      final status = data['status'];
      if (status != 'active') return false;

      // Expiry timestamp check
      final expiresAtStr = data['expiresAt'] as String?;
      if (expiresAtStr == null || expiresAtStr.isEmpty) return false;

      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt == null) return false;

      // Must be in the future
      if (DateTime.now().isAfter(expiresAt)) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[SubscriptionGuard] Token parsing error: $e');
      return false;
    }
  }

  /// Renders a full-screen, Persian-tailored subscription lock view when an active license is absent.
  static Widget buildLockScreen(
    BuildContext context, {
    required VoidCallback onRefresh,
    required Widget themeToggle,
    required Widget popupMenu,
    required Widget logo,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.titleLarge?.color;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: Theme.of(context).colorScheme.background,
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  themeToggle,
                  const SizedBox(width: 8),
                  popupMenu,
                ],
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 46,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'نیاز به اشتراک فعال اثرنگار',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'استفاده از سامانه دسک‌نگار و امکانات اتصال از راه دور، منوط به داشتن اشتراک فعال در سامانه اثرنگار است.\n\nجهت فعال‌سازی، لطفاً ابتدا نرم‌افزار اثرنگار را روی این رایانه اجرا نموده و از بخش «مدیریت اشتراک»، نسبت به تهیه یا تمدید اشتراک اقدام فرمایید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: textColor?.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text(
                            'بررسی مجدد اشتراک',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F65BA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
