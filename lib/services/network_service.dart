import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../item_data.dart';

/// Service to receive data from another Flutter app over local network (hotspot)
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  ServerSocket? _serverSocket;
  final List<Socket> _connectedClients = [];

  // Stream controller to broadcast received data
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  // Stream for connection status updates
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;

  // Current server status
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? _serverIp;
  String? get serverIp => _serverIp;

  int _port = 8888; // Default port
  int get port => _port;

  /// Get the device's local IP address
  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        // Skip loopback interfaces
        if (interface.name.toLowerCase().contains('lo')) continue;

        for (var addr in interface.addresses) {
          // Prefer hotspot/wlan interfaces
          if (interface.name.toLowerCase().contains('wlan') ||
              interface.name.toLowerCase().contains('ap') ||
              interface.name.toLowerCase().contains('swlan')) {
            return addr.address;
          }
        }
      }

      // Fallback to first available non-loopback address
      for (var interface in interfaces) {
        if (interface.name.toLowerCase().contains('lo')) continue;
        if (interface.addresses.isNotEmpty) {
          return interface.addresses.first.address;
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }

  /// Start the server to listen for incoming connections
  Future<bool> startServer({int? port}) async {
    if (_isRunning) {
      debugPrint('Server already running');
      return true;
    }

    try {
      _port = port ?? 8888;
      _serverIp = await getLocalIpAddress();

      if (_serverIp == null) {
        debugPrint('Could not get local IP address');
        _connectionController.add(
          ConnectionStatus(
            status: NetworkConnectionState.error,
            message:
                'Could not get local IP address. Make sure hotspot is enabled.',
          ),
        );
        return false;
      }

      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );

      _isRunning = true;
      _connectionController.add(
        ConnectionStatus(
          status: NetworkConnectionState.listening,
          message: 'Server listening on $_serverIp:$_port',
          ip: _serverIp,
          port: _port,
        ),
      );

      debugPrint('Server started on $_serverIp:$_port');

      // Listen for incoming connections
      _serverSocket!.listen(
        _handleClientConnection,
        onError: (error) {
          debugPrint('Server error: $error');
          _connectionController.add(
            ConnectionStatus(
              status: NetworkConnectionState.error,
              message: 'Server error: $error',
            ),
          );
        },
        onDone: () {
          debugPrint('Server socket closed');
          _isRunning = false;
        },
      );

      return true;
    } catch (e) {
      debugPrint('Failed to start server: $e');
      _connectionController.add(
        ConnectionStatus(
          status: NetworkConnectionState.error,
          message: 'Failed to start server: $e',
        ),
      );
      return false;
    }
  }

  /// Handle a new client connection
  void _handleClientConnection(Socket client) {
    final clientAddress =
        '${client.remoteAddress.address}:${client.remotePort}';
    debugPrint('Client connected: $clientAddress');

    _connectedClients.add(client);
    _connectionController.add(
      ConnectionStatus(
        status: NetworkConnectionState.connected,
        message: 'Client connected: $clientAddress',
        connectedClients: _connectedClients.length,
      ),
    );

    // Buffer for incoming data
    StringBuffer buffer = StringBuffer();

    client.listen(
      (data) {
        try {
          final message = utf8.decode(data);
          buffer.write(message);

          // Check if we have complete JSON messages (newline-delimited)
          String content = buffer.toString();
          while (content.contains('\n')) {
            int newlineIndex = content.indexOf('\n');
            String jsonStr = content.substring(0, newlineIndex);
            content = content.substring(newlineIndex + 1);
            buffer = StringBuffer(content);

            if (jsonStr.trim().isNotEmpty) {
              try {
                final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
                debugPrint('Received data: $jsonData');
                _dataController.add(jsonData);

                // Send acknowledgment
                client.write('{"status": "received"}\n');
              } catch (e) {
                debugPrint('Error parsing JSON: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Error processing data: $e');
        }
      },
      onError: (error) {
        debugPrint('Client error: $error');
        _removeClient(client);
      },
      onDone: () {
        debugPrint('Client disconnected: $clientAddress');
        _removeClient(client);
      },
    );
  }

  void _removeClient(Socket client) {
    _connectedClients.remove(client);
    client.close();
    _connectionController.add(
      ConnectionStatus(
        status: _connectedClients.isEmpty
            ? NetworkConnectionState.listening
            : NetworkConnectionState.connected,
        message: 'Client disconnected',
        connectedClients: _connectedClients.length,
      ),
    );
  }

  /// Stop the server
  Future<void> stopServer() async {
    // Close all client connections
    for (var client in _connectedClients) {
      await client.close();
    }
    _connectedClients.clear();

    // Close the server socket
    await _serverSocket?.close();
    _serverSocket = null;
    _isRunning = false;

    _connectionController.add(
      ConnectionStatus(
        status: NetworkConnectionState.disconnected,
        message: 'Server stopped',
      ),
    );

    debugPrint('Server stopped');
  }

  /// Parse received item data
  static List<ItemData> parseItemDataList(Map<String, dynamic> data) {
    final List<ItemData> items = [];

    if (data.containsKey('items') && data['items'] is List) {
      for (var itemJson in data['items']) {
        items.add(ItemData.fromJson(itemJson));
      }
    }

    return items;
  }

  void dispose() {
    stopServer();
    _dataController.close();
    _connectionController.close();
  }
}

/// Connection status model
class ConnectionStatus {
  final NetworkConnectionState status;
  final String message;
  final String? ip;
  final int? port;
  final int connectedClients;

  ConnectionStatus({
    required this.status,
    required this.message,
    this.ip,
    this.port,
    this.connectedClients = 0,
  });
}

/// Connection states
enum NetworkConnectionState { disconnected, listening, connected, error }
