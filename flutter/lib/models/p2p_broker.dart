import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Handles P2P direct discovery and broker interaction with WordPress backend.
/// Enables direct connection between DeskNegar instances without external relay servers.
class P2PBroker {
  static const String baseUrl = 'https://salamifar.ir/wp-json/asar-negar/v1';
  static String _lastRegisteredId = '';
  static DateTime? _lastRegisteredTime;

  /// Registers this machine's Desk ID and local IP to WordPress broker.
  static Future<void> registerPresence(String deskId) async {
    final cleanId = deskId.replaceAll(' ', '').trim();
    if (cleanId.isEmpty || !RegExp(r'^\d{6,12}$').hasMatch(cleanId)) return;

    // Avoid redundant calls if registered within the last 60 seconds
    if (_lastRegisteredId == cleanId &&
        _lastRegisteredTime != null &&
        DateTime.now().difference(_lastRegisteredTime!).inSeconds < 60) {
      return;
    }

    try {
      final localIp = await _getLocalIp();
      final url = Uri.parse('$baseUrl/p2p/register');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'desk_id': cleanId,
          'local_ip': localIp,
          'port': 21118,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        _lastRegisteredId = cleanId;
        _lastRegisteredTime = DateTime.now();
        debugPrint('P2PBroker registered ID: $cleanId, local: $localIp');
      }
    } catch (e) {
      debugPrint('P2PBroker register notice: $e');
    }
  }

  /// Queries WordPress broker for peer's direct socket coordinates (target_address).
  static Future<String?> lookupPeer(String targetId) async {
    final cleanId = targetId.replaceAll(' ', '').trim();
    if (!RegExp(r'^\d{6,12}$').hasMatch(cleanId)) {
      return null;
    }
    try {
      final url = Uri.parse('$baseUrl/p2p/lookup?desk_id=$cleanId');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['found'] == true && data['data'] != null) {
          final targetAddress = data['data']['target_address'] as String?;
          if (targetAddress != null && targetAddress.isNotEmpty) {
            return targetAddress;
          }
        }
      }
    } catch (e) {
      debugPrint('P2PBroker lookup notice: $e');
    }
    return null;
  }

  static Future<String> _getLocalIp() async {
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '';
  }
}
