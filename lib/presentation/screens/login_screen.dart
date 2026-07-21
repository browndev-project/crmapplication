// ==========================================
// CODE VERSION: 1.0.0 (OLD CODE - COMMENTED OUT)
// ==========================================
/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/login_provider.dart';
import '../providers/navigation_provider.dart';
import 'main_wrapper_screen.dart';
import '../../core/services/app_update_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _uniqueIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(loginProvider.notifier).checkLoginStatus();
        AppUpdateService.checkUpdate(context);
    });
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   const SizedBox(height: 40),

                   // Card
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(32),
                     decoration: BoxDecoration(
                       color: Theme.of(context).cardColor,
                       borderRadius: BorderRadius.circular(24),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                           blurRadius: 30,
                           offset: const Offset(0, 15),
                         )
                       ]
                     ),
                     child: Column(
                       children: [
                         // Theme-aware full logo
                         Image.asset(
                           isDark ? 'assets/images/logo_full_light.png' : 'assets/images/logo_full_dark.png',
                           height: 40,
                           fit: BoxFit.contain,
                         ),
                         const SizedBox(height: 24),

                         // Welcome Back
                         Text(
                           'Welcome Back',
                           style: TextStyle(
                             fontSize: 28,
                             fontWeight: FontWeight.w900,
                             color: theme.textTheme.headlineMedium?.color,
                             letterSpacing: -1,
                           ),
                         ),

                         const SizedBox(height: 48),

                         // Unique ID Field
                         TextField(
                           controller: _uniqueIdController,
                           decoration: InputDecoration(
                             labelText: 'Unique ID',
                             hintText: 'Enter your Unique ID',
                             labelStyle: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600),
                             floatingLabelBehavior: FloatingLabelBehavior.auto,
                             border: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                             ),
                             enabledBorder: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                             ),
                             focusedBorder: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: theme.primaryColor, width: 2),
                             ),
                             filled: true,
                             fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                           ),
                         ),

                         const SizedBox(height: 20),

                         // Password Field
                         TextField(
                           controller: _passwordController,
                           obscureText: _obscurePassword,
                           decoration: InputDecoration(
                             labelText: 'Password',
                             hintText: 'Enter your Password',
                             labelStyle: TextStyle(color: theme.hintColor, fontWeight: FontWeight.w600),
                             floatingLabelBehavior: FloatingLabelBehavior.auto,
                             border: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                             ),
                             enabledBorder: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                             ),
                             focusedBorder: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: theme.primaryColor, width: 2),
                             ),
                             filled: true,
                             fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                             suffixIcon: IconButton(
                               icon: Icon(
                                 _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                 color: theme.hintColor,
                               ),
                               onPressed: () {
                                 setState(() {
                                   _obscurePassword = !_obscurePassword;
                                 });
                               },
                             ),
                           ),
                         ),

                         const SizedBox(height: 40),

                         // Sign In Button
                         SizedBox(
                           width: double.infinity,
                           height: 56,
                           child: ElevatedButton(
                             onPressed: loginState.isLoading ? null : _handleLogin,
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.black,
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(
                                 borderRadius: BorderRadius.circular(14),
                               ),
                               elevation: 0,
                             ),
                             child: loginState.isLoading 
                                ? const SizedBox(
                                    height: 24, 
                                    width: 24, 
                                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)
                                  ) 
                                : const Text(
                                   'SIGN IN',
                                   style: TextStyle(
                                     fontWeight: FontWeight.w900,
                                     fontSize: 16,
                                     letterSpacing: 1,
                                   ),
                                 ),
                           ),
                         ),
                         
                         const SizedBox(height: 40),
                         
                         const SizedBox(height: 24),

                         Text(
                           '© 2026 Brown Devs. All rights reserved.',
                           style: TextStyle(
                             color: theme.hintColor.withValues(alpha: 0.5),
                             fontSize: 11,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget dot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text('•', style: TextStyle(color: Colors.grey.withValues(alpha: 0.5))),
  );

  Widget footerLink(String text) {
    return GestureDetector(
      onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$text Section Coming Soon!'))
          );
      },
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
*/

// ==========================================
// CODE VERSION: 2.0.0 (REDESIGNED FULL CODE)
// ==========================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/login_provider.dart';
import '../providers/navigation_provider.dart';
import 'main_wrapper_screen.dart';
import '../../core/services/app_update_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _uniqueIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loginProvider.notifier).checkLoginStatus();
      AppUpdateService.checkUpdate(context);
    });
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
    final screenHeight = MediaQuery.of(context).size.height;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.black : const Color(0xFFF8F9FA);
    final inputFillColor = isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7);
    final inputTextColor = isDark ? Colors.white : Colors.black;
    final inputBorderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFD1D1D6);
    final inputFocusedBorderColor = isDark ? Colors.white : Colors.black;
    final inputLabelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
    final inputFloatingLabelColor = isDark ? Colors.white : Colors.black;
    final suffixIconColor = isDark ? Colors.white : const Color(0xFF8E8E93);

    final buttonBgColor = isDark ? Colors.white : Colors.black;
    final buttonTextColor = isDark ? Colors.black : Colors.white;

    final footerBgColor = isDark ? const Color(0xFF070A0F) : const Color(0xFFF2F2F7);
    final footerBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E5EA);
    final copyrightColor = isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top visual banner
            Container(
              height: screenHeight * 0.44,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
                image: DecorationImage(
                  image: AssetImage('assets/images/login_page.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF2E1A47).withValues(alpha: 0.6),
                      const Color(0xFF0F0A1C).withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // White pill logo box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Image.asset(
                          'assets/images/logo_full_dark.png',
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log in to access your dashboard',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom form elements
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  
                  // Unique ID Field
                  TextField(
                    controller: _uniqueIdController,
                    style: TextStyle(color: inputTextColor, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Unique ID',
                      labelStyle: TextStyle(color: inputLabelColor, fontSize: 16),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      floatingLabelStyle: TextStyle(color: inputFloatingLabelColor, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: inputBorderColor, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: inputFocusedBorderColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: inputFillColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: inputTextColor, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: inputLabelColor, fontSize: 16),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      floatingLabelStyle: TextStyle(color: inputFloatingLabelColor, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: inputBorderColor, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: inputFocusedBorderColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: inputFillColor,
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: suffixIconColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loginState.isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBgColor,
                        foregroundColor: buttonTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: loginState.isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: buttonTextColor,
                              ),
                            )
                          : Text(
                              'SIGN IN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: buttonTextColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  // Footer Links Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: BoxDecoration(
                      color: footerBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: footerBorderColor,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              footerLink("About Us"),
                              const SizedBox(height: 16),
                              footerLink("Terms & Conditions"),
                            ],
                          ),
                        ),
                        // Right Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              footerLink("Contact Us"),
                              const SizedBox(height: 16),
                              footerLink("Privacy Policy"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Copyright text
                  Text(
                    '© 2026 Brown Devs. All rights reserved.',
                    style: TextStyle(
                      color: copyrightColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget footerLink(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () async {
        String urlString = '';
        if (text == 'About Us') {
          urlString = 'https://trevion.browndevs.com/about';
        } else if (text == 'Contact Us') {
          urlString = 'https://www.browndevs.com/contact-us';
        } else if (text == 'Terms & Conditions' || text == 'Terms and Conditions') {
          urlString = 'https://trevion.browndevs.com/terms-and-conditions';
        } else if (text == 'Privacy Policy') {
          urlString = 'https://trevion.browndevs.com/privacyPolicy';
        }

        if (urlString.isNotEmpty) {
          final uri = Uri.parse(urlString);
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $urlString')),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error launching link: $e')),
              );
            }
          }
        }
      },
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
