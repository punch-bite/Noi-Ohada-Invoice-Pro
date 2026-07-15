// lib/screens/support/faq_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  List<bool> _expandedStates = [];

  final List<FaqItem> _faqItems = [
    FaqItem(
      question: 'Comment créer une facture ?',
      answer: 'Pour créer une facture, rendez-vous dans l\'onglet "Factures" et cliquez sur le bouton "+" en bas à droite. Remplissez les informations du client, ajoutez les produits ou services, puis validez.',
    ),
    FaqItem(
      question: 'Mes données sont-elles sécurisées ?',
      answer: 'Oui, vos données sont entièrement sécurisées. Nous utilisons un cryptage de bout en bout et respectons les normes RGPD. Vos informations sont stockées sur des serveurs sécurisés.',
    ),
    FaqItem(
      question: 'Comment imprimer une facture ?',
      answer: 'Depuis l\'écran de détail d\'une facture, cliquez sur l\'icône d\'impression ou téléchargez le PDF et imprimez-le depuis votre appareil.',
    ),
    FaqItem(
      question: 'Puis-je modifier une facture envoyée ?',
      answer: 'Oui, vous pouvez modifier une facture tant qu\'elle n\'a pas été payée. Pour les factures payées, il est recommandé de créer une note de crédit.',
    ),
    FaqItem(
      question: 'Comment gérer plusieurs entreprises ?',
      answer: 'Pour gérer plusieurs entreprises, vous pouvez créer des profils différents dans les paramètres. Chaque profil peut avoir ses propres paramètres et clients.',
    ),
    FaqItem(
      question: 'Que faire en cas de problème ?',
      answer: 'Contactez notre support via l\'onglet "Support" de l\'application. Nous vous répondrons dans les 24 heures.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _expandedStates = List.filled(_faqItems.length, false);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;
    final primaryColor = themeProvider.primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'FAQ',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqItems.length,
        itemBuilder: (context, index) {
          return _buildFaqItem(index, isDark, textColor, subTextColor, cardColor, primaryColor);
        },
      ),
    );
  }

  Widget _buildFaqItem(
    int index,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    Color primaryColor,
  ) {
    final item = _faqItems[index];
    final isExpanded = _expandedStates[index];

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              item.question,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: primaryColor,
            ),
            onTap: () {
              setState(() {
                _expandedStates[index] = !isExpanded;
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                item.answer,
                style: TextStyle(
                  color: subTextColor,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FaqItem {
  final String question;
  final String answer;

  FaqItem({required this.question, required this.answer});
}