import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LibraryTrackFilterHeader extends SliverPersistentHeaderDelegate {
  LibraryTrackFilterHeader({
    required this.controller,
    required this.filterText,
    required this.onClear,
  });

  final TextEditingController controller;
  final String filterText;
  final VoidCallback onClear;

  @override
  double get minExtent => 90.0;

  @override
  double get maxExtent => 90.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF000000),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracks',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Filter tracks...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: filterText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: onClear,
                        tooltip: 'Clear filter',
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant LibraryTrackFilterHeader oldDelegate) {
    return filterText != oldDelegate.filterText;
  }
}
