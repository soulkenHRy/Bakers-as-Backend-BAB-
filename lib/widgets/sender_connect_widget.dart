import 'package:flutter/material.dart';
import '../services/sender_service.dart';

/// Widget for connecting to a receiver
class SenderConnectWidget extends StatefulWidget {
  const SenderConnectWidget({super.key});

  @override
  State<SenderConnectWidget> createState() => _SenderConnectWidgetState();
}

class _SenderConnectWidgetState extends State<SenderConnectWidget> {
  final SenderService _senderService = SenderService();
  final TextEditingController _ipController = TextEditingController();
  SenderConnectionStatus? _currentStatus;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _senderService.connectionStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _isConnecting = status.status == SenderState.connecting;
        });
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
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
                  'Sender Connection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_senderService.isConnected) ...[
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Receiver IP Address',
                  hintText: 'e.g., 192.168.43.1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _connect,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    foregroundColor: Colors.green[900],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connected to ${_senderService.receiverIp}:${_senderService.port}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[900],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            if (_currentStatus != null &&
                _currentStatus!.status == SenderState.error)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _currentStatus!.message,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_currentStatus?.status) {
      case SenderState.connected:
        return Icons.link;
      case SenderState.connecting:
        return Icons.sync;
      case SenderState.error:
        return Icons.link_off;
      default:
        return Icons.link_off;
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus?.status) {
      case SenderState.connected:
        return Colors.green;
      case SenderState.connecting:
        return Colors.orange;
      case SenderState.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the receiver IP address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final success = await _senderService.connect(ip);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect. Check IP and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _senderService.disconnect();
  }
}
