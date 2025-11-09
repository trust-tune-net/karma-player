import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrimaryScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const PrimaryScreenHeader({
    super.key,
    required this.title,
    this.trailing,
    this.bottom,
    this.backgroundColor = const Color(0xFF090909),
    this.minHeight = 72,
  });

  final String title;
  final Widget? trailing;
  final PreferredSizeWidget? bottom;
  final Color backgroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SizedBox(
              height: minHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.25,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 24),
                    Expanded(child: trailing!),
                  ],
                ],
              ),
            ),
          ),
          if (bottom != null) bottom!,
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x33000000),
                  Color(0x11000000),
                  Color(0x33000000),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(minHeight + (bottom == null ? 1 : bottom!.preferredSize.height + 1));
}

