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
