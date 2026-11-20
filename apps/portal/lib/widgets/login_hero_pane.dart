import 'package:flutter/material.dart';

class LoginHeroPane extends StatelessWidget {
  const LoginHeroPane({required this.scheme, super.key});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final onPrimary = scheme.onPrimary;
    final primaryContainer = scheme.primaryContainer;
    final deepShade =
        Color.lerp(primaryContainer, Colors.black, 0.28) ?? scheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, primaryContainer, deepShade],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondary.withValues(alpha: 0.14),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 15,
                            color: onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SCHOOL BRANCH PORTAL',
                            style: TextStyle(
                              color: onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.webp',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'iCue Portal',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: onPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'School Branch Management',
                              style: TextStyle(
                                fontSize: 13,
                                color: onPrimary.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Manage your school branch stationery, library books, and daily activities easily in one place.',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 32),
                    HeroFeatureTile(
                      icon: Icons.inventory_2_outlined,
                      title: 'Stationery & Supplies',
                      description: 'Check stock levels, approve item requests, and track school supplies.',
                      onPrimary: onPrimary,
                    ),
                    const SizedBox(height: 16),
                    HeroFeatureTile(
                      icon: Icons.local_library_outlined,
                      title: 'School Library',
                      description: 'Issue and return books, search the catalog, and view student reading history.',
                      onPrimary: onPrimary,
                    ),
                    const SizedBox(height: 16),
                    HeroFeatureTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Safe & Secure',
                      description: 'Keeps your school records safe and protected for your branch.',
                      onPrimary: onPrimary,
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF69F0AE),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'iCue School Management System',
                          style: TextStyle(
                            fontSize: 12,
                            color: onPrimary.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroFeatureTile extends StatelessWidget {
  const HeroFeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPrimary,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: onPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: onPrimary.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
