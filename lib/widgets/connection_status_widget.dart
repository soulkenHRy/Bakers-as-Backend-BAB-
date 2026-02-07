import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_service.dart';

/// Widget to display network connection status and controls
class ConnectionStatusWidget extends StatefulWidget {
  const ConnectionStatusWidget({super.key});

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  final NetworkService _networkService = NetworkService();
  ConnectionStatus? _currentStatus;

  @override
  void initState() {
    super.initState();
    _networkService.connectionStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getStatusIcon(), color: _getStatusColor(), size: 24),
                const SizedBox(width: 8),
                Text(
                  'Network Receiver',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildToggleButton(),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton() {
    if (_networkService.isRunning) {
      return ElevatedButton.icon(
        onPressed: _stopServer,
        icon: const Icon(Icons.stop, size: 18),
        label: const Text('Stop'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[100],
          foregroundColor: Colors.red[900],
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: _startServer,
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('Start'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[100],
          foregroundColor: Colors.green[900],
        ),
      );
    }
  }

  Widget _buildStatusInfo() {
    if (!_networkService.isRunning) {
      return const Text(
        'Tap Start to begin receiving data from another device',
        style: TextStyle(color: Colors.grey),
      );
    }

    final ip = _networkService.serverIp ?? 'Unknown';
    final port = _networkService.port;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('IP Address: '),
            Text(ip, style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: ip));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('IP copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copy IP',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Port: $port'),
        const SizedBox(height: 4),
        if (_currentStatus != null) ...[
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentStatus!.message,
                  style: TextStyle(color: _getStatusColor(), fontSize: 12),
                ),
              ),
            ],
          ),
          if (_currentStatus!.connectedClients > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Connected devices: ${_currentStatus!.connectedClients}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ],
    );
  }

  IconData _getStatusIcon() {
    if (!_networkService.isRunning) {
      return Icons.wifi_off;
    }
    switch (_currentStatus?.status) {
      case NetworkConnectionState.connected:
        return Icons.wifi;
      case NetworkConnectionState.listening:
        return Icons.wifi_find;
      case NetworkConnectionState.error:
        return Icons.wifi_off;
      default:
        return Icons.wifi_off;
    }
  }

  Color _getStatusColor() {
    if (!_networkService.isRunning) {
      return Colors.grey;
    }
    switch (_currentStatus?.status) {
      case NetworkConnectionState.connected:
        return Colors.green;
      case NetworkConnectionState.listening:
        return Colors.orange;
      case NetworkConnectionState.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _startServer() async {
    final success = await _networkService.startServer();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to start server. Make sure hotspot is enabled.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopServer() async {
    await _networkService.stopServer();
  }
}
