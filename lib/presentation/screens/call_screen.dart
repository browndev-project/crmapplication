import 'package:flutter/material.dart';
import '../../core/services/dialer_service.dart';

class CallScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const CallScreen({super.key, required this.initialData});

  static bool isOpen = false;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final DialerService _dialerService = DialerService();
  
  String _status = "CONNECTING";
  String _number = "Unknown";
  bool _isOnHold = false;
  DateTime? _callStartTime;
  
  @override
  void initState() {
    super.initState();
    CallScreen.isOpen = true; // Mark as open
    _parseData(widget.initialData);
    
    // Listen to updates
    _dialerService.callStateStream.listen((data) {
       setState(() {
          _parseData(data);
       });
    });
  }
  
  @override
  void dispose() {
    CallScreen.isOpen = false; // Mark as closed
    super.dispose();
  }
  
  bool _isPopping = false;

  void _parseData(Map<String, dynamic> data) {
      if (data['type'] != null) _status = data['type'];
      if (data['data'] != null) {
          // data format "STATE|NUMBER"
          final parts = (data['data'] as String).split('|');
          if (parts.length > 1) _number = parts[1];
      }
      
      if (_status == 'ACTIVE' && _callStartTime == null) {
          _callStartTime = DateTime.now();
      }
      
      if (_status == 'DISCONNECTED' && !_isPopping) {
          _isPopping = true;
          // Wait a bit then close
          Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                 Navigator.of(context).pop();
              }
          });
      }
  }

  @override
  Widget build(BuildContext context) {
    final isIncoming = _status == 'RINGING';
    final isDisconnected = _status == 'DISCONNECTED';
    
    return Scaffold(
      backgroundColor: isDisconnected ? Theme.of(context).disabledColor : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).cardColor,
              child: Icon(Icons.person, size: 60, color: Theme.of(context).iconTheme.color),
            ),
            const SizedBox(height: 20),
            Text(_number, style: TextStyle(color: Theme.of(context).textTheme.headlineMedium?.color, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(isDisconnected ? 'Call Ended' : _status, style: TextStyle(color: isDisconnected ? Colors.redAccent : Theme.of(context).textTheme.bodyMedium?.color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Spacer(),
            
            if (isIncoming) 
               _buildIncomingActions()
            else if (isDisconnected)
                // Manual Close Button if auto-close fails or user wants to exit faster
               Padding(
                   padding: const EdgeInsets.only(bottom: 50),
                   child: FloatingActionButton.extended(
                       onPressed: () => Navigator.of(context).pop(),
                       label: const Text('Close'),
                       icon: const Icon(Icons.close),
                       backgroundColor: Colors.grey[700],
                   ),
               )
            else 
               _buildActiveActions(),
               
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIncomingActions() {
      return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
              FloatingActionButton(
                  heroTag: 'reject',
                  backgroundColor: Colors.red,
                  onPressed: () => _dialerService.hangupCall(),
                  child: const Icon(Icons.call_end),
              ),
              FloatingActionButton(
                  heroTag: 'accept',
                  backgroundColor: Colors.green,
                  onPressed: () => _dialerService.answerCall(),
                  child: const Icon(Icons.call),
              ),
          ],
      );
  }
  
  Widget _buildActiveActions() {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               IconButton(
                   iconSize: 48,
                   icon: Icon(_isOnHold ? Icons.play_arrow : Icons.pause, color: Theme.of(context).iconTheme.color),
                   onPressed: () {
                       final newHold = !_isOnHold;
                       _dialerService.setHold(newHold);
                       setState(() => _isOnHold = newHold);
                   },
               ),
               // Add Mute, Speaker here
            ],
          ),
          const SizedBox(height: 30),
          FloatingActionButton(
              heroTag: 'hangup',
              backgroundColor: Colors.red,
              onPressed: () => _dialerService.hangupCall(),
              child: const Icon(Icons.call_end),
          ),
        ],
      );
  }
}
