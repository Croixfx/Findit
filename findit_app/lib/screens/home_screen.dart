import 'dart:math' as math;
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onCompleted;
  const HomeScreen({super.key, this.onCompleted});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _pageController = PageController();
  late AnimationController _floatController;
  late AnimationController _fadeController;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;
  int _currentPage = 0;

  static const _pages = [
    _Page(
      colors: [Color(0xFF0A2463), Color(0xFF1565C0), Color(0xFF1E88E5)],
      icon: Icons.search_rounded,
      badgeIcon: Icons.location_on_rounded,
      badgeColor: Color(0xFFFF6B6B),
      chip: 'LOST & FOUND PLATFORM',
      title: 'Welcome to\nFindIt',
      subtitle:
          'Your smart companion for recovering lost belongings. We connect people with the institutions that found their items.',
    ),
    _Page(
      colors: [Color(0xFF00331E), Color(0xFF00695C), Color(0xFF00897B)],
      icon: Icons.inventory_2_rounded,
      badgeIcon: Icons.photo_camera_rounded,
      badgeColor: Color(0xFF4FC3F7),
      chip: 'BROWSE FOUND ITEMS',
      title: 'Search Items\nNear You',
      subtitle:
          'Institutions log every found item with photos, description, and location. Filter by category or date to spot yours.',
    ),
    _Page(
      colors: [Color(0xFF1A0040), Color(0xFF4527A0), Color(0xFF5E35B1)],
      icon: Icons.shield_rounded,
      badgeIcon: Icons.verified_rounded,
      badgeColor: Color(0xFF81C784),
      chip: 'PROVE OWNERSHIP',
      title: 'Claim What\nIs Yours',
      subtitle:
          'Describe unique details and upload proof photos. Our staff reviews your claim promptly and keeps you updated.',
    ),
    _Page(
      colors: [Color(0xFF4A0010), Color(0xFFC62828), Color(0xFFE53935)],
      icon: Icons.notifications_active_rounded,
      badgeIcon: Icons.chat_bubble_rounded,
      badgeColor: Color(0xFFFFD54F),
      chip: 'REAL-TIME UPDATES',
      title: 'Stay in the\nLoop',
      subtitle:
          'Receive push notifications at every step. Chat directly with the institution once your claim is approved.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -12, end: 12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _onPageChanged(int i) async {
    await _fadeController.reverse();
    if (mounted) setState(() => _currentPage = i);
    _fadeController.forward();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
      );
    } else {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
            colors: page.colors,
          ),
        ),
        child: Stack(
          children: [
            // Decorative orbs
            Positioned(
              top: -size.width * 0.35,
              right: -size.width * 0.2,
              child: _Orb(size: size.width * 0.8, opacity: 0.07),
            ),
            Positioned(
              bottom: -size.width * 0.3,
              left: -size.width * 0.2,
              child: _Orb(size: size.width * 0.7, opacity: 0.07),
            ),
            Positioned(
              top: size.height * 0.28,
              left: -size.width * 0.1,
              child: _Orb(size: size.width * 0.3, opacity: 0.05),
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // ── Top bar ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Logo
                        Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Text(
                            'FindIt',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ]),
                        // Skip
                        if (!isLast)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onCompleted,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Text(
                                  'Skip',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Pages ────────────────────────────────────────────────
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _pages.length,
                      itemBuilder: (_, i) {
                        final p = _pages[i];
                        final isActive = i == _currentPage;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),

                              // Illustration
                              Expanded(
                                child: Center(
                                  child: AnimatedBuilder(
                                    animation: _floatAnim,
                                    builder: (_, child) => Transform.translate(
                                      offset: isActive
                                          ? Offset(0, _floatAnim.value)
                                          : Offset.zero,
                                      child: child,
                                    ),
                                    child: _Illustration(page: p, size: size),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Text block
                              FadeTransition(
                                opacity: isActive ? _fadeAnim : const AlwaysStoppedAnimation(1),
                                child: Column(
                                  children: [
                                    // Chip label
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.25),
                                        ),
                                      ),
                                      child: Text(
                                        p.chip,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Title
                                    Text(
                                      p.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        height: 1.15,
                                        letterSpacing: -0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 14),

                                    // Subtitle
                                    Text(
                                      p.subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.76),
                                        fontSize: 14.5,
                                        height: 1.65,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 28),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // ── Bottom controls ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                    child: Column(
                      children: [
                        // Progress dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pages.length, (i) {
                            final active = i == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 6,
                              width: active ? 26 : 6,
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.28),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),

                        // CTA button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(scale: anim, child: child),
                            ),
                            child: isLast
                                ? ElevatedButton(
                                    key: const ValueKey('start'),
                                    onPressed: widget.onCompleted,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: page.colors[1],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Get Started',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 20),
                                      ],
                                    ),
                                  )
                                : ElevatedButton(
                                    key: const ValueKey('next'),
                                    onPressed: _next,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withOpacity(0.15),
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color:
                                              Colors.white.withOpacity(0.35),
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Continue',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 20),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration
// ─────────────────────────────────────────────────────────────────────────────

class _Illustration extends StatelessWidget {
  const _Illustration({required this.page, required this.size});
  final _Page page;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final r = math.min(size.width * 0.42, 160.0);
    return SizedBox(
      width: r * 2.4,
      height: r * 2.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: r * 2.2,
            height: r * 2.2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          // Mid ring
          Container(
            width: r * 1.75,
            height: r * 1.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          // Inner ring with dashed border effect
          Container(
            width: r * 1.35,
            height: r * 1.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.13),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
          ),
          // Icon core
          Container(
            width: r,
            height: r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.22),
            ),
            child: Icon(page.icon, color: Colors.white, size: r * 0.52),
          ),
          // Floating badge
          Positioned(
            right: r * 0.08,
            bottom: r * 0.15,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: page.badgeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: page.badgeColor.withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(page.badgeIcon, color: Colors.white, size: 22),
            ),
          ),
          // Small decorative dot top-left
          Positioned(
            top: r * 0.35,
            left: r * 0.18,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
          Positioned(
            top: r * 0.12,
            right: r * 0.38,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background orb
// ─────────────────────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────────────────────

class _Page {
  final List<Color> colors;
  final IconData icon;
  final IconData badgeIcon;
  final Color badgeColor;
  final String chip;
  final String title;
  final String subtitle;

  const _Page({
    required this.colors,
    required this.icon,
    required this.badgeIcon,
    required this.badgeColor,
    required this.chip,
    required this.title,
    required this.subtitle,
  });
}
