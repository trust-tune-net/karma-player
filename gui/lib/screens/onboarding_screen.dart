import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: '🎵',
      title: 'Welcome to KarmaPlayer',
      subtitle: 'Your AI-powered music companion',
      description: 'Discover, organize, and enjoy music\nwith audiophile-grade quality\n\nTotally open source, pluggable architecture',
    ),
    _OnboardingPage(
      icon: '📚',
      title: 'Your Music, Organized',
      subtitle: 'Automatically scans ~/Music',
      description: 'Real metadata. No estimates.\nExact bit depth, sample rates, codec details.\n\nCheck Settings for more details.',
    ),
    _OnboardingPage(
      icon: '🔍',
      title: 'Discover & Download',
      subtitle: 'Search remore, and download via torrents or stream via YouTube',
      description: 'Community-powered quality rankings\nFind what you love, support what matters',
    ),
    _OnboardingPage(
      icon: '🔒',
      title: 'Privacy by Design',
      subtitle: 'Your data stays yours',
      description: 'No tracking. No middlemen.\nJust music, the way it should be.\n\nIf we get traction, economic model 95% to artists.',
    ),
    _OnboardingPage(
      icon: '⚡️',
      title: 'Power to Creators, Privacy to Listeners',
      subtitle: 'The Trust Tune Vision',
      description: 'Trust Tune Network is building a public trust layer\n'
          'for digital media — where quality, reputation, and\n'
          'provenance are verifiable by anyone, not controlled\n'
          'by corporations.\n\n'
          'Karma Player is the first app powered by this vision:\n'
          'community-owned curation, transparent rewards,\n'
          'and fair economics for creators.\n\n'
          'Because trust should be public, not proprietary.\n'
          'Because creators deserve fair economics.\n'
          'Because you deserve transparency.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _skip() {
    _markOnboardingComplete();
    widget.onComplete();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _markOnboardingComplete();
      widget.onComplete();
    }
  }

  void _previous() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (only on first 4 pages)
            if (_currentPage < 4)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF888888),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPageContent(_pages[index]);
                },
              ),
            ),

            // Navigation dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _buildDot(index == _currentPage),
              ),
            ),

            const SizedBox(height: 32),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previous,
                      child: Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF888888),
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Next/Get Started button
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA855F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large icon
          Text(
            page.icon,
            style: const TextStyle(fontSize: 96),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFFFFF),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          if (page.subtitle.isNotEmpty) ...[
            Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFA855F7),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFFAAAAAA),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFA855F7)
            : const Color(0xFF888888).withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _OnboardingPage {
  final String icon;
  final String title;
  final String subtitle;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}
