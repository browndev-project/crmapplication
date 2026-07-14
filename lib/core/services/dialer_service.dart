import 'dart:async';
import 'package:flutter/services.dart';

class DialerService {
  static const MethodChannel _channel = MethodChannel('com.trevioncrm/dialer');
  
  final StreamController<Map<String, dynamic>> _callStateController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get callStateStream => _callStateController.stream;

  static final DialerService _instance = DialerService._internal();

  factory DialerService() {
    return _instance;
  }

  DialerService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onCallStateChanged') {
      final args = call.arguments;
      if (args is Map) {
         _callStateController.add(Map<String, dynamic>.from(args));
      }
    }
  }

  Future<void> requestDefaultDialerRole() async {
    await _channel.invokeMethod('requestRole');
  }

  Future<bool> checkIsDefault() async {
    try {
      final bool isDefault = await _channel.invokeMethod('checkIsDefault');
      return isDefault;
    } on PlatformException {
      return false;
    }
  }

  Future<void> placeCall(String number) async {
    await _channel.invokeMethod('placeCall', {'number': number});
  }

  Future<void> answerCall() async {
    await _channel.invokeMethod('acceptCall');
  }

  Future<void> hangupCall() async {
    await _channel.invokeMethod('hangupCall');
  }

  Future<void> setHold(bool hold) async {
    await _channel.invokeMethod('setHold', {'hold': hold});
  }

  Future<String?> getSimNumber() async {
    try {
      final String? number = await _channel.invokeMethod('getSimNumber');
      return number;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveSims() async {
    try {
      final List<dynamic>? sims = await _channel.invokeMethod('getActiveSims');
      if (sims != null) {
        return sims.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  Future<void> startOverlay(String name, String number, {bool makeCall = false, Map<String, dynamic>? extraData}) async {
    try {
       await _channel.invokeMethod('startOverlay', {
           'name': name,
           'number': number,
           'makeCall': makeCall,
           'extraData': extraData
       });
    } catch(e) {
       // Silently fail if overlay not supported
    }
  }

  Future<void> stopOverlay() async {
    try {
      await _channel.invokeMethod('stopOverlay');
    } catch (e) {
      // ignore
    }
  }
}