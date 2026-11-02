import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();

  int _currentPage = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.precision_manufacturing_outlined,
      title: 'Monitor in Real-Time',
      subtitle: 'Log inspections and breakdowns instantly from the shop floor.',
    ),
    _OnboardingPageData(
      icon: Icons.trending_up_rounded,
      title: 'Detect Issues Early',
      subtitle: 'Identify recurring faults and reduce unexpected downtime.',
    ),
    _OnboardingPageData(
      icon: Icons.fact_check_outlined,
      title: 'Keep Production Running',
      subtitle: 'Simple, fast and reliable for every shift.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      widget.onFinished();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 190,
                          height: 190,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0F8F7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 96,
                            color: AppTheme.navy,
                          ),
                        ),

                        const SizedBox(height: 34),

                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF627487),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentPage ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == _currentPage
                        ? AppTheme.navy
                        : const Color(0xFFD5E0E7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: _currentPage == _pages.length - 1
                        ? AppTheme.green
                        : AppTheme.navy,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
