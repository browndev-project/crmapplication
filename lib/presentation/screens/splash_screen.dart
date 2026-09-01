import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/login_provider.dart';
import '../providers/navigation_provider.dart';
import '../../core/services/promo_campaign_service.dart';
import '../../core/services/force_update_service.dart';
import 'login_screen.dart';
import 'main_wrapper_screen.dart';
import 'broker_portal/broker_shell_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _startAppFlow();
  }

  Future<void> _startAppFlow() async {
    _controller.forward();

    // Start checking login status & pre-fetching promo banner controls in parallel
    final authCheckFuture = ref.read(loginProvider.notifier).checkLoginStatus();
    final promoCheckFuture = PromoCampaignService.fetchAppControls();
    final citiesCheckFuture = PromoCampaignService.fetchCities();

    // Wait at least 2.5 seconds to show the animation beautifully
    await Future.delayed(const Duration(milliseconds: 2500));

    // Ensure session verification and promo controls pre-fetching are complete
    await Future.wait([authCheckFuture, promoCheckFuture, citiesCheckFuture]);

    if (!mounted) return;

    // Check for Force Update (Google Play In-App Update / Version check)
    final isForceUpdateActive = await ForceUpdateService.checkAndTriggerUpdate(context);
    if (isForceUpdateActive || !mounted) {
      return;
    }

    final authState = ref.read(loginProvider);
    if (authState.isAuthenticated) {
      if (authState.user?.isBroker == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BrokerShellScreen()),
        );
      } else {
        ref.read(currentRouteProvider.notifier).state = 'Dashboard';
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainWrapperScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background subtle gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                ),
              ),
            ),
          ),
          // Animated Logo
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/images/logo_full_dark.png',
                  width: 260,
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Loading spinner

        ],
      ),
    );
  }
}
