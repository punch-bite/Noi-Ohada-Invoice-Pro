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
      title: 'Conformité OHADA',
      description: 'Générez vos factures et documents comptables en toute légalité et sérénité.',
      icon: Icons.account_balance_wallet_rounded,
      gradient: [Color(0xFF1976D2), Color(0xFF64B5F6)],
    ),
    LandingSlide(
      title: 'Cloud Synchro',
      description: 'Vos données financières sécurisées, accessibles depuis n\'importe quel appareil.',
      icon: Icons.cloud_done_rounded,
      gradient: [Color(0xFF2E7D32), Color(0xFF81C784)],
    ),
    LandingSlide(
      title: 'Paiements Mobiles',
      description: 'Intégrez facilement Orange, MTN et Wave pour accélérer vos encaissements.',
      icon: Icons.payments_rounded,
      gradient: [Color(0xFF6A1B9A), Color(0xFFBA68C8)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Header minimaliste
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: theme.primaryColor, size: 28),
                  const SizedBox(width: 8),
                  Text('NOI OHADA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: theme.textColor)),
                ],
              ),
            ),

            // Contenu du Carrousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (context, index) => _buildSlide(_slides[index], theme),
              ),
            ),

            // Indicateurs et Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) => _buildDot(index, theme)),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () => context.push('/auth/register'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Créer mon compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.push('/auth/login'),
                    child: Text('Déjà membre ? Se connecter', style: TextStyle(color: theme.subTextColor)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(LandingSlide slide, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: slide.gradient),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: slide.gradient[0].withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Icon(slide.icon, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 48),
          Text(slide.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textColor)),
          const SizedBox(height: 16),
          Text(slide.description, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: theme.subTextColor, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildDot(int index, ThemeProvider theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? theme.primaryColor : theme.subTextColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class LandingSlide {
  final String title, description;
  final IconData icon;
  final List<Color> gradient;
  const LandingSlide({required this.title, required this.description, required this.icon, required this.gradient});
}