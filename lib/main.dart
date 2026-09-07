import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/theme_provider.dart';
import 'core/services/dialer_service.dart';
import 'presentation/screens/call_screen.dart';
import 'core/services/fcm_service.dart';
import 'core/services/call_logger_service.dart';
import 'core/services/incoming_call_sync_service.dart';
import 'presentation/providers/recording_extraction_provider.dart';
import 'presentation/providers/session_guard_provider.dart';
import 'core/services/call_service.dart';
import 'core/services/location_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/whatsapp_notification_handler.dart';

import 'core/services/analytics_service.dart';
import 'presentation/screens/whatsapp/whatsapp_campaign_create_screen.dart';
import 'presentation/screens/whatsapp/whatsapp_campaign_detail_screen.dart';
import 'presentation/screens/whatsapp/whatsapp_chats_screen.dart';
import 'presentation/providers/whatsapp_provider.dart';
import 'presentation/screens/splash_screen.dart';
// Original:
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
import 'core/services/autodialer_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  await Hive.initFlutter();
  
  // Initialize FCM
  await FCMService.initializeFirebase();

  // Log App Open to Firebase Analytics
  await AnalyticsService().logAppOpen();

  // Initialize Location Service
  await LocationService().initializeService();

  // Open Hive Box for Auth
  await Hive.openBox('authBox');

  // Initialize Local Notifications
  await LocalNotificationService.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey, // KEY ADDITION
      navigatorObservers: [AnalyticsService().observer],
      title: 'Trevion CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) => _DialerWrapper(child: child!),
      home: const SplashScreen(),
      routes: {
        '/dashboard/whatsapp/campaigns/create': (context) => const WhatsAppCampaignCreateScreen(),
        '/dashboard/whatsapp/chats': (context) {
          final convId = ModalRoute.of(context)?.settings.arguments as String?;
          return WhatsAppChatsScreen(initialConversationId: convId);
        },
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/dashboard/whatsapp/campaigns/details') {
          final String id = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => WhatsAppCampaignDetailScreen(campaignId: id),
          );
        }
        return null;
      },
    );
  }
}

class _DialerWrapper extends ConsumerStatefulWidget {
    final Widget child;
    const _DialerWrapper({required this.child});
    @override
    ConsumerState<_DialerWrapper> createState() => _DialerWrapperState();
}

class _DialerWrapperState extends ConsumerState<_DialerWrapper> with WidgetsBindingObserver {
    final _dialerService = DialerService();
    
  @override
  void initState() {
      super.initState();
      WidgetsBinding.instance.addObserver(this);
      
      // Start Global Call State Listener
      CallService().startCallListener();
      CallService().requestPermissions();
      CallLoggerService().checkPendingSession();
      // Sync incoming calls on app launch (Android only)
      if (Platform.isAndroid) {
        IncomingCallSyncService().syncIncomingCalls();
      }

      CallLoggerService.onSessionEnded = (phone, callId, companyId, userId, duration) {
          if (Platform.isAndroid) {
              debugPrint("Main: Session Ended for $phone. Triggering Recording Extraction...");
              ref.read(recordingExtractionProvider.notifier).handleCallEnd(phone, callId, companyId, userId, duration);
              // Trigger incoming call sync after call end to sync any missed/incoming activity
              IncomingCallSyncService().syncIncomingCalls();
          }
      };

      final authBox = Hive.isBoxOpen('authBox') ? Hive.box('authBox') : null;
      final accountType = authBox?.get('accountType');
      if (accountType != 'broker') {
        ref.read(sessionGuardProvider).startMonitoring();
      }

      // Initialize WhatsApp providers for background notifications
      ref.read(whatsappChatsProvider);
      ref.read(whatsappMessagesProvider);

      // Initialize WhatsApp notification handler
      final container = ProviderScope.containerOf(context, listen: false);
      WhatsAppNotificationHandler().initialize(container);
      // Original:
      // None
      AutoDialerService.instance.initialize(container);

      // Handle terminated state notification tap
      WhatsAppNotificationHandler().handleTerminatedMessage();

        _dialerService.callStateStream.listen((data) {
            // NOTE: logState is NOT called here because 
            // call_service.dart:startCallListener() already registers a listener 
            // on this same stream and handles logging. Calling it here would 
            // duplicate every event.
            debugPrint("DialerStream: $data");
            final type = data['type'];

            // Added CONNECTING
            if (type == 'RINGING' || type == 'DIALING' || type == 'ACTIVE' || type == 'INCOMING' || type == 'CONNECTING') {
                 
                 // Use Global Key to avoid context issues
                 final nav = navigatorKey.currentState;
                 
                 // Schedule navigation after build frame
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                     // Check if already on call screen (simplistic check)
                     if (!CallScreen.isOpen && nav != null) {
                        nav.push(
                            MaterialPageRoute(builder: (_) => CallScreen(initialData: data))
                        );
                     }
                 });
            }
        });
    }

    @override
    void dispose() {
        WidgetsBinding.instance.removeObserver(this);
        super.dispose();
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
        if (state == AppLifecycleState.paused) {
            AnalyticsService().logCustomEvent(name: 'app_backgrounded');
            LocationService().setAsBackground();
        } else if (state == AppLifecycleState.resumed) {
            AnalyticsService().logCustomEvent(name: 'app_resumed');
            LocationService().setAsForeground();
            LocationService().checkPermissionsOnResume();
            final authBox = Hive.isBoxOpen('authBox') ? Hive.box('authBox') : null;
            final accountType = authBox?.get('accountType');
            if (accountType != 'broker') {
              ref.read(sessionGuardProvider).checkNow();
            }
            CallLoggerService().checkPendingSession();
            // Sync incoming calls on app resume (Android only)
            if (Platform.isAndroid) {
              IncomingCallSyncService().syncIncomingCalls();
            }
        }
    }
    
    
    @override
    Widget build(BuildContext context) => widget.child;
}
