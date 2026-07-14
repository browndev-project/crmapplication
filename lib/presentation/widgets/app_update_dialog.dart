import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateDialog extends StatelessWidget {
  final String title;
  final String message;
  final String storeUrl;
  final bool forceUpdate;

  const AppUpdateDialog({
    super.key,
    required this.title,
    required this.message,
    required this.storeUrl,
    required this.forceUpdate,
  });

  Future<void> _launchStore() async {
    final Uri url = Uri.parse(storeUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
     theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !forceUpdate,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Beautiful Icon Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (forceUpdate ? Colors.red : Colors.blue).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  forceUpdate ? Icons.system_update_alt_rounded : Icons.update_rounded,
                  size: 48,
                  color: forceUpdate ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                title.isNotEmpty ? title : (forceUpdate ? 'Critical Update Required' : 'Update Available'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.headlineMedium?.color,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                message.isNotEmpty ? message : 'A new version of the app is available. Please update to get the latest features.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: theme.hintColor.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!forceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _launchStore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: forceUpdate ? Colors.red : theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        forceUpdate ? 'Update Now' : 'Update',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
