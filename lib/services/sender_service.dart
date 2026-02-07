import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Service to send data to a receiver Flutter app over local network (hotspot)
class SenderService {
  static final SenderService _instance = SenderService._internal();
  factory SenderService() => _instance;
  SenderService._internal();

  Socket? _socket;

  // Connection status
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _receiverIp;
  String? get receiverIp => _receiverIp;

  int _port = 8888;
  int get port => _port;

  // Stream controller for connection status updates
  final _connectionController =
      StreamController<SenderConnectionStatus>.broadcast();
  Stream<SenderConnectionStatus> get connectionStream =>
      _connectionController.stream;

  /// Connect to a receiver
  Future<bool> connect(String ip, {int? port}) async {
    if (_isConnected) {
      await disconnect();
    }

    try {
      _receiverIp = ip;
      _port = port ?? 8888;

      _connectionController.add(
        SenderConnectionStatus(
          status: SenderState.connecting,
          message: 'Connecting to $_receiverIp:$_port...',
        ),
      );

      _socket = await Socket.connect(
        _receiverIp!,
        _port,
        timeout: const Duration(seconds: 10),
      );

      _isConnected = true;
      _connectionController.add(
        SenderConnectionStatus(
          status: SenderState.connected,
          message: 'Connected to $_receiverIp:$_port',
          ip: _receiverIp,
          port: _port,
        ),
      );

      debugPrint('Connected to $_receiverIp:$_port');

      // Listen for responses
      _socket!.listen(
        (data) {
          final response = utf8.decode(data);
          debugPrint('Received response: $response');
        },
        onError: (error) {
          debugPrint('Socket error: $error');
          _handleDisconnection('Connection error: $error');
        },
        onDone: () {
          debugPrint('Socket closed');
          _handleDisconnection('Connection closed');
        },
      );

      return true;
    } catch (e) {
      debugPrint('Failed to connect: $e');
      _connectionController.add(
        SenderConnectionStatus(
          status: SenderState.error,
          message: 'Failed to connect: $e',
        ),
      );
      return false;
    }
  }

  void _handleDisconnection(String message) {
    _isConnected = false;
    _socket = null;
    _connectionController.add(
      SenderConnectionStatus(
        status: SenderState.disconnected,
        message: message,
      ),
    );
  }

  /// Disconnect from receiver
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _isConnected = false;
    _connectionController.add(
      SenderConnectionStatus(
        status: SenderState.disconnected,
        message: 'Disconnected',
      ),
    );
    debugPrint('Disconnected');
  }

  /// Send a sold item update to receiver
  Future<bool> sendSoldItem({
    required String category,
    required String itemName,
    required int quantity,
  }) async {
    if (!_isConnected || _socket == null) {
      debugPrint('Not connected, cannot send');
      return false;
    }

    try {
      final data = {
        'type': 'sold',
        'category': category,
        'itemName': itemName,
        'quantity': quantity,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonStr = '${jsonEncode(data)}\n';
      _socket!.write(jsonStr);
      await _socket!.flush();

      debugPrint('Sent: $jsonStr');
      return true;
    } catch (e) {
      debugPrint('Failed to send: $e');
      return false;
    }
  }

  /// Send bulk update of all items
  Future<bool> sendBulkUpdate({
    required String category,
    required List<Map<String, dynamic>> items,
  }) async {
    if (!_isConnected || _socket == null) {
      debugPrint('Not connected, cannot send');
      return false;
    }

    try {
      final data = {
        'type': 'bulk_update',
        'category': category,
        'items': items,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonStr = '${jsonEncode(data)}\n';
      _socket!.write(jsonStr);
      await _socket!.flush();

      debugPrint('Sent bulk update: $jsonStr');
      return true;
    } catch (e) {
      debugPrint('Failed to send bulk update: $e');
      return false;
    }
  }

  void dispose() {
    disconnect();
    _connectionController.close();
  }
}

/// Sender connection status model
class SenderConnectionStatus {
  final SenderState status;
  final String message;
  final String? ip;
  final int? port;

  SenderConnectionStatus({
    required this.status,
    required this.message,
    this.ip,
    this.port,
  });
}

/// Sender states
enum SenderState { disconnected, connecting, connected, error }
