// lib/screens/support/legal_screen.dart
//
// ⚖️ Documents légaux de l'application : mentions légales, politique de
// confidentialité, licence d'utilisation et propriété du produit digital.
// Un seul écran réutilisable rendu selon le document demandé.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

/// Type de document légal affiché.
enum LegalPage {
  mentions,
  privacy,
  license,
  ownership,
}

class LegalScreen extends StatelessWidget {
  final LegalPage page;
  const LegalScreen({super.key, required this.page});

  String get _title {
    switch (page) {
      case LegalPage.mentions:
        return 'Mentions légales';
      case LegalPage.privacy:
        return 'Politique de confidentialité';
      case LegalPage.license:
        return 'Licence & Conditions d\'utilisation';
      case LegalPage.ownership:
        return 'Propriété du produit digital';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final bgColor = theme.backgroundColor;
    final sections = _sections(page);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          _title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lastUpdate(context),
            const SizedBox(height: 16),
            for (final s in sections) _buildSection(s, theme),
          ],
        ),
      ),
    );
  }

  Widget _lastUpdate(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Row(
      children: [
        Icon(Icons.update_rounded, size: 16, color: theme.primaryColor),
        const SizedBox(width: 6),
        Text(
          'Dernière mise à jour : 8 août 2026',
          style: TextStyle(fontSize: 12, color: theme.subTextColor),
        ),
      ],
    );
  }

  Widget _buildSection((String, String) section, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.$1,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.$2,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _sections(LegalPage p) {
    switch (p) {
      case LegalPage.mentions:
        return _mentionsSections;
      case LegalPage.privacy:
        return _privacySections;
      case LegalPage.license:
        return _licenseSections;
      case LegalPage.ownership:
        return _ownershipSections;
    }
  }

  // ============================================================
  //  MENTIONS LÉGALES
  // ============================================================
  static const List<(String, String)> _mentionsSections = [
    (
      '1. Éditeur de l\'application',
      'OHADA Invoice Pro est une application de facturation conforme aux '
          'normes OHADA / SYSCOHADA, éditée et exploitée par :\n\n'
          'NOI Digital — République du Cameroun.\n'
          'Contact : support@ohada-invoice-pro.com\n'
          'Site web : https://ohada-invoice-pro.com',
    ),
    (
      '2. Directeur de la publication',
      'Le directeur de la publication est le représentant légal de NOI '
          'Digital. Toute demande relative à l\'application ou à son contenu '
          'peut être adressée à support@ohada-invoice-pro.com.',
    ),
    (
      '3. Hébergement',
      'Les données applicatives sont hébergées sur les infrastructures de '
          'Google Cloud Platform (Firebase / Firestore), dont les serveurs '
          'peuvent être situés dans l\'Union Européenne ou aux États-Unis. '
          'Les services de paiement sont assurés par Maviance (e-nkap), '
          'opérateur de paiement agréé au Cameroun.',
    ),
    (
      '4. Objet',
      'La présente notice décrit les conditions générales d\'accès et '
          'd\'utilisation de l\'application OHADA Invoice Pro. L\'utilisation '
          'de l\'application implique l\'acceptation pleine et entière des '
          'présentes mentions légales.',
    ),
    (
      '5. Contact',
      'Pour toute question relative aux présentes mentions, veuillez nous '
          'écrire à support@ohada-invoice-pro.com ou via la rubrique '
          '« Contacter le support » de l\'application.',
    ),
  ];

  // ============================================================
  //  POLITIQUE DE CONFIDENTIALITÉ
  // ============================================================
  static const List<(String, String)> _privacySections = [
    (
      '1. Données collectées',
      'Nous collectons uniquement les données nécessaires au fonctionnement '
          'du service :\n'
          '• Données de compte : nom, adresse email, numéro de téléphone.\n'
          '• Données de facturation : clients, produits, fournisseurs, '
          'factures et devis que vous créez.\n'
          '• Données de paiement : référence de transaction (les numéros de '
          'carte ne sont jamais stockés, ils sont traités par e-nkap).\n'
          '• Données techniques : identifiants d\'appareil, version de '
          'l\'application, journaux d\'erreurs.',
    ),
    (
      '2. Utilisation des données',
      'Vos données servent exclusivement à :\n'
          '• Assurer le fonctionnement de l\'application (création, '
          'synchronisation et sauvegarde de vos factures) ;\n'
          '• Activer votre abonnement et traiter vos paiements ;\n'
          '• Vous adresser des notifications liées au service ;\n'
          '• Améliorer l\'expérience utilisateur.\n'
          'Nous ne vendons jamais vos données à des tiers.',
    ),
    (
      '3. Partage des données',
      'Vos données ne sont partagées qu\'avec :\n'
          '• Les membres de votre équipe, uniquement pour les données que '
          'vous choisissez de partager ;\n'
          '• Le prestataire de paiement e-nkap, pour le traitement des '
          'paiements ;\n'
          '• Les prestataires techniques (Google Cloud / Firebase) pour '
          'l\'hébergement et la sauvegarde.',
    ),
    (
      '4. Conservation',
      'Vos données sont conservées pendant la durée d\'utilisation du '
          'service. À la suppression de votre compte, vos données personnelles '
          'sont supprimées, sous réserve des obligations légales de '
          'conservation (notamment comptable et fiscale).',
    ),
    (
      '5. Sécurité',
      'Les données sont chiffrées en transit (HTTPS) et au repos. L\'accès '
          'aux comptes est protégé par mot de passe, et l\'authentification '
          'à deux facteurs est disponible dans les paramètres de sécurité.',
    ),
    (
      '6. Vos droits',
      'Conformément à la loi camerounaise sur la protection des données '
          'personnelles, vous disposez d\'un droit d\'accès, de '
          'rectification, d\'opposition et de suppression de vos données. '
          'Pour l\'exercer, contactez support@ohada-invoice-pro.com.',
    ),
  ];

  // ============================================================
  //  LICENCE & CONDITIONS D'UTILISATION
  // ============================================================
  static const List<(String, String)> _licenseSections = [
    (
      '1. Licence d\'utilisation',
      'L\'application OHADA Invoice Pro est fournie sous licence '
          'commerciale. Vous bénéficiez d\'un droit personnel, non exclusif '
          'et non transférable d\'utilisation, selon le plan souscrit '
          '(Gratuit, Pro ou Business).',
    ),
    (
      '2. Abonnements',
      'Le service est proposé en abonnement. Le paiement est effectué via '
          'le prestataire e-nkap (Orange Money, MTN Mobile Money ou carte '
          'bancaire). L\'activation est immédiate après confirmation du '
          'paiement. Aucun remboursement n\'est possible pour un mois déjà '
          'entamé.',
    ),
    (
      '3. Obligations de l\'utilisateur',
      'Vous vous engagez à :\n'
          '• Fournir des informations exactes lors de la création du compte ;\n'
          '• Ne pas utiliser l\'application à des fins frauduleuses ou '
          'illicites ;\n'
          '• Ne pas tenter d\'accéder aux données d\'autres utilisateurs ;\n'
          '• Respecter la législation fiscale et comptable en vigueur '
          '(normes OHADA / SYSCOHADA).',
    ),
    (
      '4. Garantie',
      'L\'application est fournie « en l\'état ». Nous nous efforçons d\'en '
          'assurer la disponibilité et la fiabilité, sans garantie '
          'd\'absence totale d\'erreur ou d\'interruption.',
    ),
    (
      '5. Résiliation',
      'En cas de non-respect des présentes conditions, votre accès au '
          'service peut être suspendu ou résilié. Vous pouvez à tout moment '
          'supprimer votre compte dans les paramètres de l\'application.',
    ),
  ];

  // ============================================================
  //  PROPRIÉTÉ DU PRODUIT DIGITAL
  // ============================================================
  static const List<(String, String)> _ownershipSections = [
    (
      '1. Propriété intellectuelle',
      'L\'application OHADA Invoice Pro, son code source, son design, ses '
          'logos, ses modèles de factures et l\'ensemble de son contenu sont '
          'la propriété exclusive de NOI Digital. Toute reproduction, '
          'modification ou distribution sans autorisation écrite est '
          'interdite.',
    ),
    (
      '2. Modèles de factures',
      'Les modèles de factures (y compris les modèles Premium) et les '
          'personnalisations sont concédés sous licence d\'utilisation. Vous '
          'pouvez les utiliser pour vos propres factures, mais vous ne '
          'pouvez pas les revendre ni les redistribuer.',
    ),
    (
      '3. Données utilisateur',
      'Les données que vous créez (clients, produits, factures) vous '
          'appartiennent. Nous n\'en revendiquons aucun droit de propriété. '
          'Vous conservez la pleine propriété de vos données et de vos '
          'exportations.',
    ),
    (
      '4. Marques',
      'Les noms « OHADA Invoice Pro », « NOI Digital » et les logos associés '
          'sont des marques protégées. Toute utilisation sans autorisation '
          'est interdite.',
    ),
    (
      '5. Licence du produit digital',
      'L\'achat d\'un abonnement ou d\'un modèle Premium vous accorde une '
          'licence d\'utilisation, et non un transfert de propriété du '
          'produit digital. Le produit reste la propriété de NOI Digital.',
    ),
    (
      '6. Contact',
      'Pour toute question relative à la propriété intellectuelle, '
          'contactez : support@ohada-invoice-pro.com.',
    ),
  ];
}
