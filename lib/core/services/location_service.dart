import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'auth_service.dart';
import '../../main.dart';

@pragma('vm:entry-point')
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const String notificationChannelId = 'location_service';
  static const int notificationId = 888;
  static const int _intervalMinutes = 1;

  /// Initializes the background service.
  /// This should be called during app initialization (e.g., in main.dart).
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configure notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Location Tracking',
      description: 'Reports your location to the CRM system.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Control starting manually to ensure permissions and readiness
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Location Tracking',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    debugPrint('📍 LocationService: Service configured');
  }

  /// Starts the tracking service.
  Future<void> startTracking() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    
    if (isRunning) {
      debugPrint('📍 LocationService: Service is already running');
      return;
    }

    debugPrint('📍 LocationService: Starting background service tracking...');
    
    // 1. Request permissions properly before starting
    bool hasPermission = await _handlePermissions();
    if (!hasPermission) {
      debugPrint('❌ LocationService: Cannot start service without background location permission');
      return;
    }

    // 2. Start the service
    try {
      bool started = await service.startService();
      debugPrint('📍 LocationService: Service start attempt: $started');
    } catch (e) {
      debugPrint('❌ LocationService: Exception while starting service: $e');
    }
  }

  /// Stops the tracking service.
  void stopTracking() {
    final service = FlutterBackgroundService();
    debugPrint('📍 LocationService: Stopping background service');
    service.invoke('stopService');
  }

  void setAsForeground() {
    FlutterBackgroundService().invoke('setAsForeground');
  }

  void setAsBackground() {
    FlutterBackgroundService().invoke('setAsBackground');
  }

  bool _isDialogShowing = false;

  /// Checks and closes the permission dialog if permission was granted while in settings.
  /// Called from AppLifecycleState.resumed in main.dart.
  Future<void> checkPermissionsOnResume() async {
    if (!_isDialogShowing) return;
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) {
      debugPrint('📍 LocationService: Permission granted on resume, closing dialog');
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted && _isDialogShowing) {
        // Pop the dialog - use rootNavigator to ensure we close the dialog specifically
        Navigator.of(context, rootNavigator: true).pop(true);
        _isDialogShowing = false;
      }
    }
  }

  Future<bool> _handlePermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    while (permission != LocationPermission.always) {
      // 1. If denied (first time or previously denied), request it to show system popup
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.always) break;
      }

      // 2. If still not 'always' (could be denied, deniedForever, or whileInUse)
      String title;
      String message;

      if (permission == LocationPermission.deniedForever) {
        title = "Location Permission Denied";
        message = "Location access is permanently denied. This app requires 'Allow all the time' to sync background data.\n\nPlease click 'OPEN SETTINGS', go to 'Permissions' -> 'Location' and select 'Allow all the time'.";
      } else if (permission == LocationPermission.whileInUse) {
        title = "Background Access Needed";
        message = "You have currently allowed location only 'While using the app'.\n\nFor CRM sync to work in the background, you MUST change it to 'Allow all the time' in the settings.";
      } else {
        title = "Location Required";
        message = "This app needs 'Always' location access to track your activity.\n\nPlease click 'OPEN SETTINGS' and select 'Allow all the time'.";
      }

      // 3. Show our explanation dialog and wait
      // This will stay open while the user is in settings,
      // and will be popped by checkPermissionsOnResume() when they return.
      final result = await _showPermissionDialog(title, message);
      
      // If the user pressed CANCEL, we might want to break and return false
      if (result == false) {
        debugPrint('📍 LocationService: Permission check cancelled by user');
        return false;
      }
      
      // 4. Re-check after dialog is closed (either by resume pop or manual pop)
      permission = await Geolocator.checkPermission();
      
      // Safety break to prevent infinite loop if something goes wrong
      if (permission == LocationPermission.always) break;
      
      // If we are here and still don't have permission, it means the user closed the dialog
      // or came back without granting. We loop again to show the dialog until they grant or we add a cancel.
      // To avoid rapid looping, add a small delay
      await Future.delayed(const Duration(seconds: 1));
    }
    
    return true;
  }

  Future<dynamic> _showPermissionDialog(String title, String message) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;

    _isDialogShowing = true;
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              // We DON'T pop the dialog here. 
              // We want it to stay so that when the user returns, 
              // checkPermissionsOnResume() can close it automatically.
              await Geolocator.openAppSettings();
            },
            child: const Text("OPEN SETTINGS"),
          ),
        ],
      ),
    );
    _isDialogShowing = false;
    return result;
  }

  static bool _isUpdating = false;

  /// Entry point for the background service (Separate Isolate).
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // CRITICAL: Call this first for Android to prevent ForegroundServiceDidNotStartInTimeException
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }

    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    String appState = "foreground";

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
        appState = "foreground";
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
        appState = "background";
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Initialize Hive for the background isolate
    try {
      await Hive.initFlutter();
    } catch (e) {
      debugPrint('📍 [BG] LocationService: Hive already initialized or error: $e');
    }

    // Timer for periodic updates
    Timer.periodic(const Duration(minutes: _intervalMinutes), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Location Tracking Active",
            content: "Last sync: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          );
        }
      }

      await _performLocationUpdate(appState);
    });

    // Initial update
    await _performLocationUpdate(appState);
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  static Future<void> _performLocationUpdate(String currentAppState) async {
    if (_isUpdating) {
      debugPrint('📍 [BG] LocationService: Update already in progress, skipping...');
      return;
    }

    _isUpdating = true;
    try {
      debugPrint('📍 [BG] LocationService: Fetching current location...');
      
      // 1. Get Position with robust error handling
      Position? position;
      try {
        // Check if location services are enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('❌ [BG] LocationService: Location services are disabled');
          _isUpdating = false;
          return;
        }

        // Check permissions in background isolate
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          debugPrint('❌ [BG] LocationService: Location permission is $permission');
          _isUpdating = false;
          return;
        }

        // Use AndroidSettings for better background reliability
        LocationSettings locationSettings;
        if (Platform.isAndroid) {
          locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            forceLocationManager: true, // More stable in background on many devices
          );
        } else {
          locationSettings = AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.fitness,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          );
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        ).timeout(const Duration(seconds: 25));
      } catch (e) {
        debugPrint('❌ [BG] LocationService: Exception while getting position: $e');
        _isUpdating = false;
        return;
      }

      // 2. Get Auth Data
      Box? authBox;
      try {
        authBox = await Hive.openBox('authBox');
      } catch (e) {
        debugPrint('❌ [BG] LocationService: Error opening Hive box: $e');
        _isUpdating = false;
        return;
      }

      final userId = authBox.get('user_id');
      final sessionId = authBox.get('sessionId');
      final token = authBox.get('accessToken');

      if (userId == null || sessionId == null) {
        debugPrint('❌ [BG] LocationService: No active user session');
        _isUpdating = false;
        return;
      }

      // 3. Get Device Info
      final deviceInfoPlugin = DeviceInfoPlugin();
      String model = 'Unknown';
      String platformStr = 'Unknown';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        model = '${androidInfo.brand} ${androidInfo.model}';
        platformStr = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        model = iosInfo.name;
        platformStr = 'iOS ${iosInfo.systemVersion}';
      }

      // 4. Construct Payload
      final payload = {
        "userId": userId,
        "sessionId": sessionId,
        "location": {
          "latitude": position.latitude,
          "longitude": position.longitude,
          "accuracy": position.accuracy,
          "altitude": position.altitude,
          "speed": position.speed,
          "heading": position.heading,
          "timestamp": position.timestamp.toIso8601String()
        },
        "deviceInfo": {
          "platform": platformStr,
          "version": platformStr.split(' ').last,
          "model": model,
          "isMockLocation": position.isMocked
        },
        "appState": currentAppState
      };

      debugPrint('🚀 [BG] [LOCATION UPDATE] Payload: ${jsonEncode(payload)}');

      // 5. Post to backend
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/location/webhook');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 [BG] LocationService: Response Status: ${response.statusCode}');

    } catch (e) {
      debugPrint('❌ [BG] LocationService Error: $e');
    } finally {
      _isUpdating = false;
    }
  }
}
