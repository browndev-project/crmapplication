import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomPermissionDialog extends StatefulWidget {
  const CustomPermissionDialog({super.key});

  @override
  State<CustomPermissionDialog> createState() => _CustomPermissionDialogState();
}

class _CustomPermissionDialogState extends State<CustomPermissionDialog> {
  int _currentStep = 0;
  bool _isCheckingPermission = false;

  Future<void> _handleStoragePermission() async {
    setState(() => _isCheckingPermission = true);

    // Use scoped storage permissions only.
    // READ_MEDIA_AUDIO covers Android 13+ (API 33+).
    // READ_EXTERNAL_STORAGE (max SDK 32) covers Android 12 and below.
    // MANAGE_EXTERNAL_STORAGE is not requested — it violates Google Play policy.
    PermissionStatus status = await Permission.audio.request();

    // Fallback for Android 12 and below if audio permission is not available.
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    setState(() => _isCheckingPermission = false);

    if (status.isGranted) {
      // Move to step 2 if granted.
      setState(() {
        _currentStep = 1;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio access is required to read call recordings.'),
          ),
        );
      }
    }
  }

  Future<void> _openPhoneApp() async {
    final Uri launchUri = Uri(scheme: 'tel', path: '');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Could not open the Phone app automatically.')),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      child: SizedBox(
        width: double.infinity,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _currentStep == 0 ? _buildStep1(theme, isDark) : _buildStep2(theme, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(ThemeData theme, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.folder_special_rounded,
            size: 48,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Audio Access Permission',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.headlineMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Trevion CRM needs access to audio files to securely retrieve call recordings. Only recording files will be accessed — no other files.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.hintColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isCheckingPermission ? null : _handleStoragePermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isCheckingPermission 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
              'Open Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _currentStep = 1; // Skip for now
            });
          },
          child: Text('Skip for now', style: TextStyle(color: theme.hintColor)),
        ),
      ],
    );
  }

  Widget _buildStep2(ThemeData theme, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              size: 40,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Enable Call Recording',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.headlineMedium?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'To automatically log calls, please enable native call recording on your device (Samsung/Others).',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: theme.hintColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInstructionStep(theme, '1', 'Open the Phone App', Icons.phone),
              _buildInstructionStep(theme, '2', 'Tap the 3-dots menu & select Settings', Icons.more_vert),
              _buildInstructionStep(theme, '3', 'Tap "Record calls"', Icons.voicemail),
              _buildInstructionStep(theme, '4', 'Turn on "Auto record calls"', Icons.toggle_on, isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _openPhoneApp,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide(color: theme.primaryColor),
                ),
                child: Text(
                  'Open Phone App',
                  style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructionStep(ThemeData theme, String stepNumber, String text, IconData icon, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ),
          Icon(
            icon,
            size: 18,
            color: theme.hintColor.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
