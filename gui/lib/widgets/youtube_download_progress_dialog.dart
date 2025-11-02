import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Beautiful non-blocking progress toast for YouTube downloads
class YouTubeDownloadProgressToast extends StatefulWidget {
  final String title;
  final String? artist;
  final double progress;
  final VoidCallback? onCancel;
  final VoidCallback? onDismiss;

  const YouTubeDownloadProgressToast({
    super.key,
    required this.title,
    this.artist,
    this.progress = 0.0,
    this.onCancel,
    this.onDismiss,
  });

  @override
  State<YouTubeDownloadProgressToast> createState() => _YouTubeDownloadProgressToastState();
}

class _YouTubeDownloadProgressToastState extends State<YouTubeDownloadProgressToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start below screen
      end: Offset.zero, // End at position
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Slide in immediately
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void dismiss() {
    _slideController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).toInt();

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFA855F7).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon with pulsing animation
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFA855F7).withOpacity(0.3 + (_pulseController.value * 0.2)),
                          const Color(0xFFA855F7).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      size: 24,
                      color: Color(0xFFA855F7),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Title
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.artist != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.artist!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF888888),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Progress bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: const Color(0xFF2A2A2E),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFFA855F7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Downloading...',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFAAAAAA),
                              ),
                            ),
                            Text(
                              '$progressPercent%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFA855F7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Beta phase message in yellow
                        Text(
                          'Beta phase - Takes a while to begin, please be patient',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.yellow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Cancel button and dismiss button
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dismiss button (X)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: const Color(0xFF888888),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: dismiss,
                    tooltip: 'Dismiss',
                  ),
                  if (widget.onCancel != null) ...[
                    const SizedBox(height: 8),
                    // Cancel download button
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: const Color(0xFF888888).withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFAAAAAA),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

