import 'package:auth/auth.dart';
import 'package:flutter/material.dart';

class HomeWelcomeBanner extends StatelessWidget {
  const HomeWelcomeBanner({required this.user, super.key});

  final UserInfo? user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryContainer = scheme.primaryContainer;
    final deepShade =
        Color.lerp(primaryContainer, Colors.black, 0.28) ?? scheme.primary;

    final displayName = user?.name.isNotEmpty == true
        ? user!.name
        : 'Branch Administrator';
    final schoolName = user?.schoolName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, primaryContainer, deepShade],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 80,
            bottom: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 14,
                      color: scheme.onPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SCHOOL BRANCH DASHBOARD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome back, $displayName',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: scheme.onPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                schoolName != null && schoolName.isNotEmpty
                    ? '$schoolName · Select a module below to start your work.'
                    : 'Select a school module below to manage your branch tasks.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
