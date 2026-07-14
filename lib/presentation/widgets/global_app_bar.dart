import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/login_provider.dart';
import '../screens/login_screen.dart';
import '../providers/theme_provider.dart';
import '../screens/profile_screen.dart';
import '../providers/navigation_provider.dart';

class GlobalAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  const GlobalAppBar({
    super.key, 
    required this.title,
    this.showBackButton = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(66); // Premium height for bigger logo

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Retrieve User Name & Role from Hive
    final box = Hive.box('authBox');
    final userJson = box.get('user_data');
    String userName = 'User';
    String userRole = 'Staff';

    if (userJson != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        userName = userMap['name'] ?? 'User';
        userRole = userMap['role'] ?? 'Staff';
        // Capitalize Role
        if (userRole.isNotEmpty) {
           userRole = userRole[0].toUpperCase() + userRole.substring(1).replaceAll('_', ' ');
        }
      } catch (e) {
        // Fallback
      }
    }

    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: showBackButton 
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color, size: 26),
              onPressed: () {
                final handler = ref.read(backHandlerProvider);
                if (handler != null && handler()) return;

                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop();
                  return;
                }

                final history = ref.read(routeHistoryProvider);
                if (history.length > 1) {
                  final newHistory = List<String>.from(history);
                  newHistory.removeLast();
                  final prevRoute = newHistory.last;
                  ref.read(routeHistoryProvider.notifier).state = newHistory;
                  ref.read(currentRouteProvider.notifier).state = prevRoute;
                } else {
                  ref.read(currentRouteProvider.notifier).state = 'Dashboard';
                }
              },
            )
          : Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu_rounded, color: Theme.of(context).iconTheme.color, size: 28),
                onPressed: () {
                  ScaffoldState? scaffoldState;
                  ctx.visitAncestorElements((element) {
                    if (element.widget is Scaffold) {
                      final scaffold = element.widget as Scaffold;
                      if (scaffold.drawer != null) {
                        scaffoldState = (element as StatefulElement).state as ScaffoldState;
                        return false;
                      }
                    }
                    return true;
                  });

                  if (scaffoldState != null) {
                    scaffoldState!.openDrawer();
                  } else {
                    try {
                      Scaffold.of(ctx).openDrawer();
                    } catch (_) {}
                  }
                },
              ),
            ),
      ),
      title: Image.asset(
        isDark ? 'assets/images/logo_full_light.png' : 'assets/images/logo_full_dark.png',
        height: 44, // Bigger logo
        fit: BoxFit.contain,
      ),
      actions: [
        // 0. Custom actions (Reminder, Attendance, etc.)
        if (actions != null) 
          ...actions!.map((a) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: a,
          )),

        // 1. Theme Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: InkWell(
              onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                  color: Theme.of(context).iconTheme.color,
                  size: 24,
                ),
              ),
            ),
          ),
        ),

        // 2. Profile Icon with Menu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Theme(
               data: Theme.of(context).copyWith(
                 popupMenuTheme: PopupMenuThemeData(
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                     side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                   ),
                   color: Theme.of(context).cardColor,
                   elevation: 8,
                 )
               ),
               child: PopupMenuButton<String>(
                 offset: const Offset(0, 50),
                 tooltip: "Profile Menu",
                 child: Container(
                   width: 40,
                   height: 40,
                   decoration: BoxDecoration(
                     color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                     borderRadius: BorderRadius.circular(10),
                   ),
                   child: Icon(Icons.person_outline_rounded, color: Theme.of(context).iconTheme.color, size: 24),
                 ),
                 itemBuilder: (context) => [
                   PopupMenuItem<String>(
                     enabled: false,
                     height: 50,
                     child: Row(
                       children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               Text(userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                               Text(userRole, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), 
                            ],
                          )
                       ]
                     ),
                   ),
                   const PopupMenuDivider(),
                   PopupMenuItem<String>(
                     value: 'profile',
                     child: Row(
                       children: [
                          Icon(Icons.badge_outlined, size: 20, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7)),
                          const SizedBox(width: 12),
                          const Text('My Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                       ],
                     ),
                   ),
                   PopupMenuItem<String>(
                     value: 'logout',
                     child: Row(
                       children: [
                          const Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                          const SizedBox(width: 12),
                          const Text('Logout', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   ),
                 ],
                 onSelected: (value) {
                   if (value == 'logout') {
                     _handleLogout(context, ref);
                   } else if (value == 'profile') {
                     Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                   }
                 },
               ),
            ),
          ),
        ),
        const SizedBox(width: 8), // Refined End margin
      ],
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text("Are you sure you want to logout of your session?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx); 
                 await ref.read(loginProvider.notifier).logout();
                 if (context.mounted) {
                   Navigator.of(context).pushAndRemoveUntil(
                       MaterialPageRoute(builder: (_) => const LoginScreen()),
                       (route) => false
                   );
                 }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
  }
}
