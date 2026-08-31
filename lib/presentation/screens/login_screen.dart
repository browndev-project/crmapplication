import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/login_provider.dart';
import '../providers/navigation_provider.dart';
import 'main_wrapper_screen.dart';
import 'promo/promo_campaign_screen.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/promo_campaign_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _uniqueIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late bool _showLoginForm;

  Map<String, dynamic>? _promoBannerData;
  late bool _isPromoBannerActive;

  @override
  void initState() {
    super.initState();
    // Synchronously read pre-fetched promo controls from Splash Screen background call
    _isPromoBannerActive = PromoCampaignService.isPromoActiveCached();
    _promoBannerData = PromoCampaignService.getCachedPromoData();
    _showLoginForm = !_isPromoBannerActive;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appControls = await AppUpdateService.checkUpdate(context);
      if (appControls != null && mounted) {
        final promo = appControls['promoBanner'];
        if (promo != null && promo['active'] == true) {
          setState(() {
            _promoBannerData = Map<String, dynamic>.from(promo);
            _isPromoBannerActive = true;
            _showLoginForm = false;
          });
        } else {
          setState(() {
            _isPromoBannerActive = false;
            _showLoginForm = true;
          });
        }
      } else if (mounted) {
        setState(() {
          _isPromoBannerActive = false;
          _showLoginForm = true;
        });
      }
      _loadSavedCredentials();
    });
  }

  Future<void> _loadSavedCredentials() async {
    final credentialsBox = await Hive.openBox('credentialsBox');
    final savedUsername = credentialsBox.get('last_username');
    final savedPassword = credentialsBox.get('last_password');
    if (savedUsername != null && savedPassword != null && mounted) {
      _uniqueIdController.text = savedUsername;
      _passwordController.text = savedPassword;
    }
  }

  @override
  void dispose() {
    _uniqueIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final uniqueId = _uniqueIdController.text.trim();
    final password = _passwordController.text.trim();

    if (uniqueId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Unique ID and Password')),
      );
      return;
    }
    await ref.read(loginProvider.notifier).login(uniqueId, password);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LoginState>(loginProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      }

      if (next.isAuthenticated) {
        ref.read(currentRouteProvider.notifier).state = 'Dashboard';
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainWrapperScreen()),
        );
      }
    });

    final loginState = ref.watch(loginProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: !_showLoginForm || !_isPromoBannerActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showLoginForm && _isPromoBannerActive) {
          setState(() => _showLoginForm = false);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFFFEfEFE) : const Color(0xFFFEfEFE),
          body: Stack(
            children: [
              // Top Image (login_top.png)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/images/login_top.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),

              // Bottom Image (login_bottom.png)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/images/login_bottom.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),

              // Main Scrollable Body
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 24.0,
                        right: 24.0,
                        top: 16.0,
                        bottom: isKeyboardOpen ? 24.0 : 110.0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _showLoginForm
                            ? _buildLoginFormView(context, isDark, loginState)
                            : _buildWelcomeLandingView(context, isDark),
                      ),
                    ),
                  ),
                ),
              ),

              // Pinned Bottom Footer Section (Shifted up near bottom cubes, hidden when keyboard is open)
              if (!isKeyboardOpen)
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '© ${DateTime.now().year} Brown Devs. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            const urlString = 'https://trevion.browndevs.com/privacyPolicy';
                            final uri = Uri.parse(urlString);
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            } catch (_) {}
                          },
                          child: const Text(
                            'View Policies',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0052FF),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildWelcomeLandingView(BuildContext context, bool isDark) {
    return Column(
      key: const ValueKey('welcome_landing_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),


            const SizedBox(height: 62),

            if (_isPromoBannerActive) ...[
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PromoCampaignScreen(
                        initialPromoData: _promoBannerData,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFFFEDD5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _promoBannerData?['smallImageUrl'] != null && _promoBannerData!['smallImageUrl'].toString().trim().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            _promoBannerData!['smallImageUrl'],
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildFallbackBannerContent(isDark),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildFallbackBannerContent(isDark),
                        ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 3. Login Action Card (Blue Button)
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _showLoginForm = true);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0052FF), Color(0xFF1E64FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0052FF).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.login_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Access your Trevion dashboard',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 2: LOGIN CREDENTIALS FORM VIEW
  // ==========================================
  Widget _buildLoginFormView(
      BuildContext context, bool isDark, LoginState loginState) {
    return Column(
      key: const ValueKey('login_form_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [


        const SizedBox(height: 245
        ),

        // Header Title
        Text(
          'Login to Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Welcome back! Please login to continue',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 44),

        // Unique ID Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unique ID',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: _uniqueIdController,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'Enter Unique ID',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Password Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'Enter Password',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Sign In Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loginState.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: loginState.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackBannerContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Celebrate the bond of trust',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF991B1B),
                ),
              ),
            ),
            const Text('🏵️', style: TextStyle(fontSize: 22)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Special offers for a stronger partnership!',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[300] : const Color(0xFF78350F),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_offer_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Limited Time Offer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Text('🎁', style: TextStyle(fontSize: 26)),
          ],
        ),
      ],
    );
  }
}
