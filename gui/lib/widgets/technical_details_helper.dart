import 'dart:io';
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

/// Shared helper methods for displaying technical audio details
class TechnicalDetailsHelper {
  /// Builds an info row with label and value
  static Widget buildInfoRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontFamily: mono ? 'monospace' : null,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// Formats channel information with proper capitalization
  static String formatChannels(String? layout, int? channels) {
    if (layout == null && channels == null) return 'Unknown';
    if (layout != null && channels != null) {
      return '${capitalizeLayout(layout)} ($channels.0)'; // "Stereo (2.0)"
    }
    if (channels != null) return '$channels.0';
    return capitalizeLayout(layout!);
  }

  /// Capitalizes channel layout names
  static String capitalizeLayout(String layout) {
    if (layout == 'stereo') return 'Stereo';
    if (layout == '5.1') return '5.1 Surround';
    if (layout == '5.1(side)') return '5.1 Surround';
    if (layout == '7.1') return '7.1 Surround';
    if (layout == '7.1(side)') return '7.1 Surround';
    if (layout == 'mono') return 'Mono';
    // Capitalize first letter for unknown layouts
    return layout[0].toUpperCase() + layout.substring(1);
  }

  /// Truncates long file paths
  static String truncatePath(String path) {
    if (path.length <= 50) return path;
    return '...${path.substring(path.length - 47)}';
  }

  /// Builds a clickable path row that opens the file location
  static Widget buildClickablePathRow(String label, String fullPath) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          // Open file manager and select the file (platform-specific)
          try {
            if (Platform.isMacOS) {
              await Process.run('open', ['-R', fullPath]);
            } else if (Platform.isWindows) {
              await Process.run('explorer', ['/select,', fullPath]);
            } else if (Platform.isLinux) {
              // Try nautilus first (GNOME), fallback to xdg-open with directory
              final dir = fullPath.substring(0, fullPath.lastIndexOf('/'));
              try {
                await Process.run('nautilus', ['--select', fullPath]);
              } catch (_) {
                await Process.run('xdg-open', [dir]);
              }
            }
          } catch (e, stackTrace) {
            print('Error opening file location: $e');
            AnalyticsService().captureError(
              e,
              stackTrace,
              context: 'open_file_location',
              extras: {
                'platform': Platform.operatingSystem,
                'path': fullPath,
              },
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 80,
                child: Text(
                  'Path',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        truncatePath(fullPath),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA855F7),
                          fontFamily: 'monospace',
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.folder_open,
                      size: 14,
                      color: Color(0xFFA855F7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
