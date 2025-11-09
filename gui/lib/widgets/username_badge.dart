import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/username_service.dart';
import '../services/device_service.dart';
import '../services/api_auth_service.dart';
import '../main.dart';

/// Reddit-style username badge with device ID tooltip.
///
/// Displays generated username (e.g., "Feisty-Sky-6018") in a pill-shaped badge.
/// Hovering shows tooltip with raw device ID (UUID).
class UsernameBadge extends StatefulWidget {
  const UsernameBadge({super.key});

  @override
  State<UsernameBadge> createState() => _UsernameBadgeState();
}

class _UsernameBadgeState extends State<UsernameBadge> {
  late final UsernameService _usernameService;
  late final DeviceService _deviceService;

  String? _username;
  String? _deviceId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService();

    // Convert gRPC URL (port 50051) to HTTP API URL (port 3000)
    String httpApiUrl = appSettings.searchApiUrl
        .replaceFirst('0.0.0.0', '127.0.0.1')
        .replaceFirst(':50051', ':3000');

    _usernameService = UsernameService(
      deviceService: _deviceService,
      apiAuthService: ApiAuthService(),
      apiBaseUrl: httpApiUrl,
    );
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      final username = await _usernameService.getUsername();
      final deviceId = await _deviceService.getDeviceId();

      if (mounted) {
        setState(() {
          _username = username;
          _deviceId = deviceId;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingBadge();
    }

    if (_error != null) {
      return _buildErrorBadge();
    }

    if (_username == null) {
      return const SizedBox.shrink();
    }

    return _buildUsernameBadge();
  }

  Widget _buildLoadingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkGray.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.lightGray.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading...',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.lightGray.withOpacity(0.5),
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBadge() {
    return Tooltip(
      message: 'Failed to load username: $_error',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 14,
              color: AppColors.red.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Error',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.red.withOpacity(0.8),
                letterSpacing: 0.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameBadge() {
    return Tooltip(
      message: 'Device ID: $_deviceId\nTap to copy',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _copyDeviceIdToClipboard,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.purple.withOpacity(0.25),
                  AppColors.purpleLight.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.purple.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // User icon
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.purple.withOpacity(0.9),
                  ),
                ),
                const SizedBox(width: 8),
                // Username text
                Text(
                  _username!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple.withOpacity(0.95),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyDeviceIdToClipboard() async {
    if (_deviceId == null) return;

    try {
      // Copy to clipboard
      // Note: Clipboard API requires `import 'package:flutter/services.dart'`
      await Clipboard.setData(ClipboardData(text: _deviceId!));

      if (mounted) {
        // Show snackbar confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Device ID copied to clipboard',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: AppColors.green.withOpacity(0.9),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to copy: $e',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: AppColors.red.withOpacity(0.9),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}
