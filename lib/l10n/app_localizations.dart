// lib/l10n/app_localizations.dart
//
// Système de traduction autonome (aucune dépendance à flutter_localizations
// ni à gen-l10n) : un simple LocalizationsDelegate personnalisé qui expose
// les libellés de langue de l'interface. Cela permet à MaterialApp de prendre
// en charge plusieurs locales et de refléter la langue choisie dans l'écran
// de sélection.
import 'package:flutter/material.dart';

/// Conteneur des chaînes traduites de l'application.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('fr'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Langues réellement prises en charge.
  static const List<Locale> supportedLocales = [
    Locale('fr'),
    Locale('en'),
  ];

  bool get isEnglish => locale.languageCode == 'en';

  // ===== Libellés de l'écran de sélection de langue =====
  String get languageSetting =>
      isEnglish ? 'Language' : 'Langue';

  String get languageSettingSubtitle => isEnglish
      ? 'Change the app language'
      : "Changer la langue de l'application";

  String get chooseLanguage => isEnglish ? 'Choose a language' : 'Choisir une langue';

  String get systemLanguage => isEnglish ? 'System' : 'Système';

  /// Nom affiché d'une langue dans la langue courante de l'interface.
  String languageName(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return isEnglish ? 'French' : 'Français';
      case 'en':
        return 'English';
      default:
        return languageCode;
    }
  }

  // ===================================================================
  //  ÉCRAN PARAMÈTRES
  // ===================================================================

  // ----- Titre & sections -----
  String get settingsTitle => isEnglish ? 'Settings' : 'Paramètres';
  String get sectionAccount => isEnglish ? 'Account' : 'Compte';
  String get sectionPersonalization =>
      isEnglish ? 'Personalization' : 'Personnalisation';
  String get sectionSupport => isEnglish ? 'Support' : 'Support';
  String get sectionAbout => isEnglish ? 'About' : 'À propos';

  // ----- Compte -----
  String get subscription => isEnglish ? 'Subscription' : 'Abonnement';
  String get free => isEnglish ? 'Free' : 'Gratuit';
  String get company => isEnglish ? 'Company' : 'Entreprise';
  String get companySubtitle =>
      isEnglish ? 'Configure your company' : 'Configurer votre entreprise';
  String get security => isEnglish ? 'Security' : 'Sécurité';
  String get securitySubtitle => isEnglish
      ? 'Password, 2FA, biometrics'
      : 'Mot de passe, 2FA, biométrie';

  // ----- Personnalisation -----
  String get theme => isEnglish ? 'Theme' : 'Thème';
  String get chooseTheme => isEnglish ? 'Choose a theme' : 'Choisir un thème';
  String get themeLight => isEnglish ? 'Light' : 'Clair';
  String get themeDark => isEnglish ? 'Dark' : 'Sombre';
  String get themeSystem => isEnglish ? 'System' : 'Système';

  String get invoiceTemplates =>
      isEnglish ? 'Invoice templates' : 'Modèles de factures';
  String get invoiceTemplatesSubtitle =>
      isEnglish ? 'Customize your invoices' : 'Personnaliser vos factures';
  String get wallet => isEnglish ? 'Wallet' : 'Portefeuille';
  String get walletSubtitle => isEnglish
      ? 'Client collections and withdrawals'
      : 'Encaissements clients et retraits';
  String get invoiceSettings =>
      isEnglish ? 'Invoice settings' : 'Paramètres de facture';
  String get invoiceSettingsSubtitle => isEnglish
      ? 'Watermark, colors, font, margins'
      : 'Filigrane, couleurs, police, marges';
  String get exportData => isEnglish ? 'Export my data' : 'Exporter mes données';
  String get exportDataSubtitle => isEnglish
      ? 'Clients, stock, invoices, statistics (JSON/CSV)'
      : 'Clients, stock, factures, statistiques (JSON/CSV)';
  String get driveBackup =>
      isEnglish ? 'Google Drive backup' : 'Sauvegarde Google Drive';
  String get driveBackupSubtitle => isEnglish
      ? 'Free — back up your data to your Drive'
      : 'Gratuit — sauvegardez vos données dans votre Drive';
  String get notifications => isEnglish ? 'Notifications' : 'Notifications';
  String get notificationsSubtitle =>
      isEnglish ? 'Manage your alerts' : 'Gérer vos alertes';

  // ----- Support -----
  String get helpCenter => isEnglish ? 'Help center' : 'Centre d\'aide';
  String get helpCenterSubtitle =>
      isEnglish ? 'FAQ and documentation' : 'FAQ et documentation';
  String get onlineSupport => isEnglish ? 'Online support' : 'Support en ligne';
  String get onlineSupportSubtitle => isEnglish
      ? 'Chat with our team'
      : 'Discuter avec notre équipe';
  String get contactSupport =>
      isEnglish ? 'Contact support' : 'Contacter le support';
  String get contactSupportSubtitle =>
      isEnglish ? 'Send us an email' : 'Envoyez-nous un email';

  // ----- À propos -----
  String get appName => 'OHADA Invoice Pro';
  String get versionLabel => 'Version 1.0.0';
  String get appDescription => isEnglish
      ? 'OHADA-compliant invoice management'
      : 'Gestion de factures conforme OHADA';
  String get close => isEnglish ? 'Close' : 'Fermer';
  String get checkUpdates =>
      isEnglish ? 'Check for updates' : 'Vérifier les mises à jour';
  String get checkUpdatesSubtitle => isEnglish
      ? 'Compares with the latest published version'
      : 'Compare avec la dernière version publiée';
  String get enkapTest => isEnglish ? 'E-nkap payment test' : 'Test paiement E-nkap';
  String get enkapTestSubtitle => isEnglish
      ? 'Developer test screen (admin only)'
      : 'Écran de test développeur (admin uniquement)';
  String get logout => isEnglish ? 'Logout' : 'Déconnexion';
  String get logoutSubtitle =>
      isEnglish ? 'Sign out of the app' : 'Se déconnecter de l\'application';

  // ----- Dialogues -----
  String get logoutDialogTitle => isEnglish ? 'Logout' : 'Déconnexion';
  String get logoutDialogMessage => isEnglish
      ? 'Do you really want to log out?'
      : 'Voulez-vous vraiment vous déconnecter ?';
  String get cancel => isEnglish ? 'Cancel' : 'Annuler';
  String get confirmLogout => isEnglish ? 'Log out' : 'Se déconnecter';

  // ===================================================================
  //  DASHBOARD (navigation + accueil)
  // ===================================================================

  // ----- Navigation -----
  String get navHome => isEnglish ? 'Home' : 'Accueil';
  String get navClients => 'Clients';
  String get navInvoices => isEnglish ? 'Invoices' : 'Factures';
  String get navAnalytics => isEnglish ? 'Analytics' : 'Analyses';
  String get navStock => 'Stock';
  String get menuTooltip => 'Menu';

  // ----- En-tête -----
  String get greeting => isEnglish ? 'Hello' : 'Bonjour';
  String get defaultUserName => isEnglish ? 'User' : 'Utilisateur';

  // ----- Carte solde -----
  String get totalBalance => isEnglish ? 'TOTAL BALANCE' : 'SOLDE TOTAL';
  String get collected => isEnglish ? 'Collected' : 'Encaissé';
  String get pending => isEnglish ? 'Pending' : 'En attente';
  String get overdue => isEnglish ? 'Overdue' : 'En retard';

  // ----- Actions rapides -----
  String get quickInvoice => isEnglish ? 'Invoice' : 'Facture';
  String get quickClient => 'Client';
  String get quickPay => isEnglish ? 'Pay' : 'Payer';

  // ----- Statistiques -----
  String get statRevenue => isEnglish ? 'Revenue' : 'Revenus';
  String get statAverage => isEnglish ? 'Average' : 'Moyenne';
  String get statPaymentRate => isEnglish ? 'Payment rate' : 'Taux paiement';

  // ----- Statistiques (cartes dashboard_stats.dart) -----
  // Alias au pluriel utilisés par le widget `DashboardStats`.
  String get statsRevenue => isEnglish ? 'Revenue' : 'Revenus';
  String get statsOrders => isEnglish ? 'Orders' : 'Commandes';
  String get statsGoal => isEnglish ? 'Goal' : 'Objectif';

  // ----- Statut des factures -----
  String get invoiceStatusTitle =>
      isEnglish ? 'Invoice status' : 'Statut des factures';
  String invoicesCount(int count) =>
      isEnglish ? '$count invoices' : '$count factures';
  String get statusPaidPlural => isEnglish ? 'Paid' : 'Payées';
  String get statusPending => isEnglish ? 'Pending' : 'En attente';
  String get statusOverdue => isEnglish ? 'Overdue' : 'En retard';
  String get statusCancelledPlural => isEnglish ? 'Cancelled' : 'Annulées';

  // ----- Sections récentes -----
  String get newClients => isEnglish ? 'New clients' : 'Nouveaux clients';
  String get recentInvoices =>
      isEnglish ? 'Recent invoices' : 'Factures récentes';
  String get seeAll => isEnglish ? 'See all' : 'Voir tout';
  String get noClientsYet =>
      isEnglish ? 'No clients yet' : 'Aucun client pour le moment';
  String get noInvoicesYet =>
      isEnglish ? 'No invoices yet' : 'Aucune facture pour le moment';

  /// Libellé de statut d'une facture (singulier, pour les badges).
  String invoiceStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return isEnglish ? 'Paid' : 'Payée';
      case 'sent':
        return isEnglish ? 'Pending' : 'En attente';
      case 'overdue':
        return isEnglish ? 'Overdue' : 'En retard';
      case 'cancelled':
        return isEnglish ? 'Cancelled' : 'Annulée';
      default:
        return isEnglish ? 'Draft' : 'Brouillon';
    }
  }

  /// Référence client courte affichée sous le numéro de facture.
  String clientRef(String clientId) {
    final short =
        clientId.length > 6 ? clientId.substring(0, 6) : clientId;
    return 'Client #$short';
  }

  // ===================================================================
  //  DRAWER (menu latéral)
  // ===================================================================

  String get drawerPlanFree => isEnglish ? 'Free plan' : 'Plan gratuit';

  String get drawerSuppliers => isEnglish ? 'Suppliers' : 'Fournisseurs';

  String get drawerReminders => isEnglish ? 'Reminders' : 'Relances';

  String get drawerCompanySubtitle =>
      isEnglish ? 'Manage your company' : 'Gérer votre entreprise';

  String get drawerHelpSupport =>
      isEnglish ? 'Help & Support' : 'Aide & Support';

  String get drawerAboutApp =>
      isEnglish ? 'About the app' : "À propos de l'app";

  String get drawerShareApp =>
      isEnglish ? 'Share the app' : "Partager l'app";

  String get drawerRateApp => isEnglish ? 'Rate the app' : "Noter l'app";

  String get shareSubject =>
      isEnglish ? 'Share OHADA Invoice Pro' : 'Partager OHADA Invoice Pro';

  String get shareMessage => isEnglish
      ? 'Discover OHADA Invoice Pro, the app to easily manage your invoices!'
      : "Découvrez OHADA Invoice Pro, l'application pour gérer vos factures facilement !";

  String get rateAppTitle =>
      isEnglish ? 'Rate the app' : "Noter l'application";

  String get rateAppMessage => isEnglish
      ? 'If you enjoy OHADA Invoice Pro, please leave us a rating on the store!'
      : 'Si vous aimez OHADA Invoice Pro, laissez-nous une note sur le store !';

  String get later => isEnglish ? 'Later' : 'Plus tard';

  String get rate => isEnglish ? 'Rate' : 'Noter';

  String get drawerProfile => isEnglish ? 'Profile' : 'Profil';

  String get drawerTeams => isEnglish ? 'Teams' : 'Équipes';

  String get drawerRemindersTile => isEnglish ? 'Reminders' : 'Rappels';

  String get drawerClientReminders =>
      isEnglish ? 'Client reminders' : 'Relance clients';

  String get drawerAdmin => isEnglish ? 'Administration' : 'Administration';

  String get drawerFaq => 'FAQ';

  // ===================================================================
  //  PAIEMENT (bottom sheet « Payer » du dashboard)
  // ===================================================================

  String get paymentManualValidation =>
      isEnglish ? 'Manual payment validation' : 'Validation manuelle du paiement';

  String get paymentManualValidationSubtitle => isEnglish
      ? 'Select an invoice then manually validate the payment received'
      : 'Sélectionnez une facture puis validez manuellement le paiement reçu';

  String get paymentNoInvoiceToValidate =>
      isEnglish ? 'No invoice to validate' : 'Aucune facture à valider';

  String get paymentSelectInvoice =>
      isEnglish ? 'Select an invoice' : 'Sélectionner une facture';

  String get paymentPleaseSelectInvoice =>
      isEnglish ? 'Please select an invoice' : 'Veuillez sélectionner une facture';

  String get paymentOnlineReservedForPaidPlans => isEnglish
      ? 'Online collection is reserved for paid plans. '
          'Upgrade to a subscription to collect payments from your clients online.'
      : 'L\'encaissement en ligne est réservé aux plans payants. '
          'Passez à un abonnement pour encaisser vos clients en ligne.';

  String get paymentEnterValidPhone =>
      isEnglish ? 'Please enter a valid phone number (9 digits)' : 'Veuillez saisir un numéro de téléphone valide (9 chiffres)';

  String get paymentMarkAsSent =>
      isEnglish ? 'Mark as sent' : 'Marquer comme envoyée';

  String get paymentConfirmManual =>
      isEnglish ? 'Confirm payment (manual)' : 'Confirmer le paiement (manuel)';

  String get paymentStartOnline =>
      isEnglish ? 'Start online payment' : 'Initier le paiement en ligne';

  String get paymentCashMethodName =>
      isEnglish ? 'Cash (manual validation)' : 'Cash (validation manuelle)';

  String get paymentCardMethodName => isEnglish
      ? 'Bank card (Visa / MasterCard)'
      : 'Carte bancaire (Visa / MasterCard)';

  String get paymentConfirmTitle =>
      isEnglish ? 'Confirm payment' : 'Confirmer le paiement';

  String get paymentConfirmIntro => isEnglish
      ? 'You are about to mark this invoice as paid.'
      : 'Vous êtes sur le point de marquer cette facture comme payée.';

  String paymentInvoiceLabel(String invoiceNumber) =>
      isEnglish ? 'Invoice: $invoiceNumber' : 'Facture : $invoiceNumber';

  String paymentAmountLabel(String amountFcfa) =>
      isEnglish ? 'Amount: $amountFcfa' : 'Montant : $amountFcfa';

  String get paymentConfirmReceived => isEnglish
      ? 'Do you confirm you have received the payment?'
      : 'Confirmez-vous avoir bien reçu le paiement ?';

  String get paymentMarkedAsSent =>
      isEnglish ? 'Invoice marked as sent ✅' : 'Facture marquée comme envoyée ✅';

  String get paymentConfirmedManual =>
      isEnglish ? 'Payment confirmed manually ✅' : 'Paiement confirmé manuellement ✅';

  String get paymentAmountToValidate =>
      isEnglish ? 'Amount to validate' : 'Montant à valider';

  String get paymentMethod => isEnglish ? 'Payment method' : 'Moyen de paiement';

  String get paymentClientPhoneLabel =>
      isEnglish ? 'Client phone number' : 'Numéro de téléphone du client';

  String get paymentValidationCycle =>
      isEnglish ? 'Validation cycle' : 'Cycle de validation';

  String get paymentProcessing =>
      isEnglish ? 'Processing...' : 'Traitement...';

  String get paymentManualHintCash =>
      isEnglish ? 'Manual validation — cash received' : 'Validation manuelle — cash reçu';

  String get paymentSecureViaEnkap =>
      isEnglish ? 'Secure payment via E-nkap' : 'Paiement sécurisé via E-nkap';

  // ===================================================================
  //  AUTHENTIFICATION (login / register / mot de passe oublié / 2FA)
  // ===================================================================

  String get authAppSubtitle => isEnglish
      ? 'SYSCOHADA-compliant invoicing'
      : 'Facturation conforme SYSCOHADA';
  String get authEmailLabel =>
      isEnglish ? 'Email address' : 'Adresse e-mail';
  String get authEmailHint => 'exemple@email.com';
  String get authEmailRequired =>
      isEnglish ? 'Please enter your email' : 'Veuillez saisir votre email';
  String get authEmailInvalid =>
      isEnglish ? 'Invalid email address' : 'Adresse email non valide';
  String get authPasswordLabel =>
      isEnglish ? 'Password' : 'Mot de passe';
  String get authPasswordRequired => isEnglish
      ? 'Please enter your password'
      : 'Veuillez renseigner votre mot de passe';
  String get authPasswordTooShort => isEnglish
      ? 'Password must be at least 6 characters'
      : 'Le mot de passe doit faire 6 caractères minimum';
  String get authRememberMe => isEnglish ? 'Remember me' : 'Se souvenir';
  String get authForgotPassword =>
      isEnglish ? 'Forgot password?' : 'Mot de passe oublié ?';
  String get authLoginButton => isEnglish ? 'Log in' : 'Se connecter';
  String get authLoginFailed =>
      isEnglish ? 'Login failed' : 'Échec de connexion';
  String get authGoogleFailed =>
      isEnglish ? 'Google sign-in failed' : 'Connexion Google échouée';
  String get authLoginWithGoogle =>
      isEnglish ? 'Sign in with Google' : 'Se connecter avec Google';
  String get authOr => isEnglish ? 'or' : 'ou';
  String get authNoAccount =>
      isEnglish ? 'No account yet?' : 'Pas encore de compte ?';
  String get authSignUpLink => isEnglish ? 'Sign up' : "S'inscrire";

  String get authRegisterTitle =>
      isEnglish ? 'Create an account' : 'Créer un compte';
  String get authRegisterSubtitle => isEnglish
      ? 'Join NOI OHADA Invoice Pro'
      : 'Rejoignez NOI OHADA Invoice Pro';
  String get authNameLabel => isEnglish ? 'Full name' : 'Nom complet';
  String get authNameHint =>
      isEnglish ? 'Your name' : 'Votre nom';
  String get authNameRequired =>
      isEnglish ? 'Please enter your name' : 'Veuillez saisir votre nom';
  String get authNameTooShort => isEnglish
      ? 'Name must be at least 2 characters'
      : 'Le nom doit faire 2 caractères minimum';
  String get authConfirmPasswordLabel =>
      isEnglish ? 'Confirm password' : 'Confirmer le mot de passe';
  String get authConfirmPasswordRequired => isEnglish
      ? 'Please confirm your password'
      : 'Veuillez confirmer votre mot de passe';
  String get authPasswordsDoNotMatch =>
      isEnglish ? 'Passwords do not match' : 'Les mots de passe ne correspondent pas';
  String get authAcceptTermsPrefix => isEnglish ? 'I accept the ' : "J'accepte les ";
  String get authTermsOfUse =>
      isEnglish ? 'terms of use' : "conditions d'utilisation";
  String get authAndThe => isEnglish ? ' and the ' : ' et la ';
  String get authPrivacyPolicy =>
      isEnglish ? 'privacy policy' : 'politique de confidentialité';
  String get authMustAcceptTerms => isEnglish
      ? 'You must accept the terms of use.'
      : "Vous devez accepter les conditions d'utilisation.";
  String get authCreateAccountButton =>
      isEnglish ? 'Create my account' : 'Créer mon compte';
  String get authRegisterFailed => isEnglish
      ? 'An error occurred during registration.'
      : "Une erreur est survenue lors de l'inscription.";
  String get authAlreadyHaveAccount =>
      isEnglish ? 'Already have an account?' : 'Déjà un compte ?';
  String get authLoginLink => isEnglish ? 'Log in' : 'Se connecter';
  String get authPasswordStrengthWeak =>
      isEnglish ? 'Weak' : 'Faible';
  String get authPasswordStrengthMedium =>
      isEnglish ? 'Medium' : 'Moyen';
  String get authPasswordStrengthStrong =>
      isEnglish ? 'Strong' : 'Fort';

  String get authForgotTitle =>
      isEnglish ? 'Forgot password?' : 'Mot de passe oublié ?';
  String get authForgotSubtitle => isEnglish
      ? 'Enter your email address to receive a reset link'
      : 'Entrez votre adresse email pour recevoir un lien de réinitialisation';
  String get authResetEmailSent => isEnglish
      ? 'Reset email sent successfully'
      : 'Email de réinitialisation envoyé avec succès';
  String get authResetEmailFailed => isEnglish
      ? "Unable to send the reset email."
      : "Impossible d'envoyer l'email de réinitialisation.";
  String get authSendLinkButton =>
      isEnglish ? 'Send the link' : 'Envoyer le lien';
  String get authRememberedPassword =>
      isEnglish ? 'Remembered your password?' : 'Mot de passe retrouvé ?';

  String get auth2faTitle =>
      isEnglish ? 'Two-factor authentication' : 'Double authentification';
  String auth2faSubtitle(int codeLength) => isEnglish
      ? 'Enter the $codeLength-digit security code generated by your authenticator app (OTP).'
      : 'Saisissez le code de sécurité à $codeLength chiffres généré par votre application d\'authentification (OTP).';
  String get auth2faIncomplete =>
      isEnglish ? 'Please enter the full code' : 'Veuillez saisir le code complet';
  String get auth2faInvalid =>
      isEnglish ? 'Invalid security code' : 'Code de sécurité invalide';
  String get auth2faValidateButton =>
      isEnglish ? 'Verify and log in' : 'Valider et se connecter';
  String get auth2faBackToLogin =>
      isEnglish ? 'Back to the login screen' : "Retour à l'écran de connexion";
  String get auth2faCancelLogin =>
      isEnglish ? 'Cancel login' : 'Annuler la connexion';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
