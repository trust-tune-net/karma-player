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
      icon: '🌐',
      title: 'Trust Tune Network',
      subtitle: 'A public trust layer for music',
      description: 'Trust Tune keeps audio quality, provenance, and\n'
          'reputation open. KarmaPlayer connects you straight to that\n'
          'shared truth — creators, curators, and listeners aligned.',
    ),
    _OnboardingPage(
      icon: '🛠️',
      title: 'Verified Audio Quality',
      subtitle: 'FLAC Mode, engineered ears-first',
      description: 'Every file you add is fingerprinted, checked for lossless.\n'
          'Switch on FLAC Mode, plug in reference headphones or a solid stereo,\n'
          'and line up a favorite track — you will hear the headroom, depth,\n'
          'and dynamics most streaming services shave off.\n\n'
          'Waveform stats, bit depth, sample rate, and codec details surface\n'
          'instantly so you know exactly what you have.',
    ),
    _OnboardingPage(
      icon: '🎯',
      title: 'Dialed-In Discovery',
      subtitle: 'Filters built for crate diggers',
      description: 'Toggle filters — format, bit depth.\n'
          'Hog Mode takes exclusive control of your audio stack, silences\n'
          'system intrusions, keeps the DAC bit-perfect, and routes output\n'
          'solely through KarmaPlayer.\n\n'
          'Everything you keep ends up in your local library for instant,\n'
          'offline playback — zero dependency on the internet.',
    ),
    _OnboardingPage(
      icon: '🤝',
      title: 'Community Proof, Private Playback',
      subtitle: 'Anonymous listeners, shared trust',
      description: 'Upcoming releases get vetted by anonymous listeners who\n'
          'sign for quality without revealing identity.\n\n'
          'Consensus lands in your library; your playback stays local.\n'
          'Streams take a breath because we fingerprint, fetch proofs,\n'
          'and buffer lossless before a single sample plays.',
    ),
    _OnboardingPage(
      icon: '🚀',
      title: 'Sharing, Scaled by Trust Tune',
      subtitle: 'Future-ready apps and exchanges',
      description: 'New apps are coming alive on the Trust Tune Network —\n'
          'provenance-tracked playlists and collaborative drops ready to explore.\n\n'
          'Share a link and friends inherit the validation trail and audio proofs.\n'
          'Trust, quality, and community follow every share.',
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
            // Skip button (hidden on final page)
            if (_currentPage < _pages.length - 1)
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large icon
            Text(
              page.icon,
              style: const TextStyle(fontSize: 96),
            ),
            const SizedBox(height: 24),

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
            const SizedBox(height: 12),

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
              const SizedBox(height: 16),
            ],

            // Description
            Text(
              page.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFFAAAAAA),
                height: 1.6,
              ),
            ),
          ],
        ),
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
