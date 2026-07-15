// lib/screens/landing/landing_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<LandingSlide> _slides = const [
    LandingSlide(
      title: 'Factures conformes OHADA',
      description: 'Créez des factures et devis conformes aux normes OHADA en quelques clics',
      icon: Icons.receipt_long,
      color: Color(0xFF1976D2),
    ),
    LandingSlide(
      title: 'Synchronisation cloud',
      description: 'Accédez à vos données partout, à tout moment',
      icon: Icons.cloud_sync,
      color: Color(0xFF2E7D32),
    ),
    LandingSlide(
      title: 'Sécurisé et fiable',
      description: 'Vos données sont protégées selon les standards les plus stricts',
      icon: Icons.security,
      color: Color(0xFFE65100),
    ),
    LandingSlide(
      title: 'Paiements Mobile Money',
      description: 'Acceptez Orange Money, MTN Mobile Money et Wave',
      icon: Icons.payment,
      color: Color(0xFF6A1B9A),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final bgColor = themeProvider.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // En-tête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NOI OHADA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                          Text('Invoice Pro', style: TextStyle(fontSize: 10, color: subTextColor)),
                        ],
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.push('/auth/login'),
                    child: Text('Se connecter', style: TextStyle(color: primaryColor)),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Carrousel
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) => setState(() => _currentPage = index),
                        itemCount: _slides.length,
                        itemBuilder: (context, index) {
                          final slide = _slides[index];
                          return _buildSlide(slide, textColor, subTextColor, primaryColor);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Indicateurs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? primaryColor : Colors.grey[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),

              // Boutons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => context.push('/auth/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Commencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => context.push('/auth/register'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Créer un compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Version 1.0.0', style: TextStyle(fontSize: 11, color: subTextColor.withOpacity(0.5))),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(LandingSlide slide, Color textColor, Color subTextColor, Color primaryColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: slide.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(60),
          ),
          child: Icon(slide.icon, size: 60, color: slide.color),
        ),
        const SizedBox(height: 32),
        Text(
          slide.title,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          slide.description,
          style: TextStyle(fontSize: 14, color: subTextColor, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class LandingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const LandingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}