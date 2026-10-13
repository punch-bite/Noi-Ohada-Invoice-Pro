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

  // ═══════════════════════════════════════════════════════════════
  //  BOUTIQUE DE MODÈLES
  // ═══════════════════════════════════════════════════════════════
  String get storeTitle => isEnglish ? 'Store' : 'Boutique';
  String get storeSubtitle => isEnglish
      ? 'Official templates & creations'
      : 'Modèles officiels & créations';
  String get storeCart => isEnglish ? 'Cart' : 'Panier';
  String get storeCartEmptyMsg =>
      isEnglish ? 'Your cart is empty.' : 'Votre panier est vide.';
  String get storeMyTemplates => isEnglish ? 'My templates' : 'Mes modèles';
  String get storeSearchHint =>
      isEnglish ? 'Search a style…' : 'Rechercher un style…';
  String get storeEmptyTitle =>
      isEnglish ? 'No template found' : 'Aucun modèle trouvé';
  String get storeEmptyMsg => isEnglish
      ? 'Try another category or keyword.'
      : 'Essayez une autre catégorie ou un autre mot-clé.';
  String get storeReset => isEnglish ? 'Reset' : 'Réinitialiser';
  String storeAddedToCart(String name) =>
      isEnglish ? '$name added to cart' : '$name ajouté au panier';
  String get storeCustomize => isEnglish ? 'Customize' : 'Personnaliser';
  String get storeAdd => isEnglish ? 'Add' : 'Ajouter';

  // ═══════════════════════════════════════════════════════════════
  //  CHECKOUT / PANIER DE MODÈLES
  // ═══════════════════════════════════════════════════════════════
  String get checkoutTitle => isEnglish ? 'Confirmation & Payment' : 'Confirmation & Règlement';
  String get checkoutCartTitle => isEnglish ? 'Template cart' : 'Panier de modèles';
  String get checkoutEmptyTitle => isEnglish ? 'Your cart is empty' : 'Votre panier est vide';
  String get checkoutEmptyMsg => isEnglish
      ? 'Add a template from the store to continue.'
      : 'Ajoutez un modèle depuis la boutique pour continuer.';
  String get checkoutBrowseStore => isEnglish ? 'Browse the store' : 'Voir la boutique';
  String get checkoutSelectedItems => isEnglish ? 'Selected Items' : 'Articles Sélectionnés';
  String get checkoutPaymentMethod => isEnglish ? 'Payment Method' : 'Mode de Paiement';
  String get checkoutPhoneLabel => isEnglish
      ? 'Mobile Money phone number'
      : 'Numéro de Téléphone Mobile Money';
  String get checkoutTotalToPay => isEnglish ? 'Total to pay' : 'Total à régler';
  String get checkoutFree => isEnglish ? 'FREE' : 'GRATUIT';
  String get checkoutFreeItem => isEnglish ? 'Free' : 'Gratuit';
  String get checkoutUnlockButton => isEnglish ? 'Unlock Template' : 'Débloquer le Modèle';
  String checkoutConfirmButton(String amount) => isEnglish
      ? 'Confirm & Pay ($amount XAF)'
      : 'Confirmer & Payer ($amount FCFA)';
  String get checkoutLoginRequired => isEnglish
      ? 'Please sign in to acquire templates.'
      : 'Veuillez vous connecter pour acquérir des modèles.';
  String get checkoutInvalidPhone => isEnglish
      ? 'Please enter a valid phone number.'
      : 'Veuillez saisir un numéro de téléphone valide.';
  String checkoutPurchaseOne(String name) =>
      isEnglish ? 'Template purchase: $name' : 'Achat modèle : $name';
  String checkoutPurchaseMany(int count) => isEnglish
      ? 'Purchase of $count invoice templates'
      : 'Achat de $count modèles de facture';
  String get checkoutPaymentCancelled =>
      isEnglish ? 'Payment cancelled.' : 'Paiement annulé.';
  String get checkoutUnlockedTitle =>
      isEnglish ? 'Template unlocked!' : 'Modèle débloqué !';
  String get checkoutSuccessTitle => isEnglish ? 'Payment Successful!' : 'Paiement Réussi !';
  String get checkoutUnlockedMsg => isEnglish
      ? 'The template is now available in your templates.'
      : 'Le modèle est désormais disponible dans vos modèles.';
  String get checkoutSuccessMsg => isEnglish
      ? 'Congratulations! Your template is ready to be customized.'
      : 'Félicitations ! Votre modèle est prêt à être personnalisé.';
  String get checkoutViewMyTemplates =>
      isEnglish ? 'View My Templates' : 'Voir Mes Modèles';
  String get checkoutCustomizeNow =>
      isEnglish ? 'Customize Now' : 'Personnaliser Maintenant';
  String get checkoutPaymentFailed => isEnglish
      ? "The payment could not be validated. Please try again."
      : "Le paiement n'a pas pu être validé. Réessayez.";
  String checkoutTransactionError(String error) => isEnglish
      ? 'Transaction error: $error'
      : 'Erreur lors de la transaction : $error';
  String get checkoutOrangeMoney => isEnglish ? 'Orange Money' : 'Orange Money';
  String get checkoutMtnMoney => isEnglish ? 'MTN Mobile Money' : 'MTN Mobile Money';
  String get checkoutMoovMoney => isEnglish ? 'Moov Money' : 'Moov Money';
  String get checkoutCard => isEnglish ? 'Bank Card / Visa' : 'Carte Bancaire / Visa';

  // ═══════════════════════════════════════════════════════════════
  //  DÉTAIL FACTURE
  // ═══════════════════════════════════════════════════════════════
  String get invoiceDetailPreviewQuote =>
      isEnglish ? 'Quote Preview' : 'Aperçu Devis';
  String get invoiceDetailPreviewInvoice =>
      isEnglish ? 'Invoice Preview' : 'Aperçu Facture';
  String get invoiceDetailNotFound =>
      isEnglish ? 'Invoice not found' : 'Facture introuvable';
  String get invoiceDetailNotFoundMsg => isEnglish
      ? 'This invoice no longer exists.'
      : "Cette facture n'existe plus.";
  String get invoiceDetailThisInvoice => isEnglish ? 'This invoice' : 'Cette facture';
  String get invoiceDetailCustomize => isEnglish ? 'Customize' : 'Personnaliser';
  String get invoiceDetailCustomizeTooltip =>
      isEnglish ? 'Customize the template' : 'Personnaliser le modèle';
  String get invoiceDetailCustomizeRestricted => isEnglish
      ? 'Customization is reserved for this template.'
      : 'Personnalisation réservée à ce modèle.';
  String get invoiceDetailReadOnly => isEnglish
      ? 'Read-only mode — action disabled.'
      : 'Mode lecture seule — action désactivée.';
  String get invoiceDetailSharePdf => isEnglish ? 'Share the PDF' : 'Partager le PDF';
  String get invoiceDetailPrintPreview =>
      isEnglish ? 'Preview / Print PDF' : 'Aperçu / Imprimer PDF';
  String get invoiceDetailSendEmail => isEnglish ? 'Send by email' : 'Envoyer par email';
  String get invoiceDetailChangeTemplate =>
      isEnglish ? 'Change template' : 'Changer de modèle';
  String get invoiceDetailDelete => isEnglish ? 'Delete' : 'Supprimer';
  String get invoiceDetailChooseTemplate =>
      isEnglish ? 'Choose a template' : 'Choisir un modèle';
  String get invoiceDetailSeeAll => isEnglish ? 'See all' : 'Voir tout';
  String get invoiceDetailActive => isEnglish ? 'Active' : 'Actif';
  String get invoiceDetailDeleteTitle =>
      isEnglish ? 'Delete invoice?' : 'Supprimer la facture ?';
  String invoiceDetailDeleteMsg(String number) => isEnglish
      ? 'Invoice $number will be permanently deleted.'
      : 'La facture $number sera définitivement supprimée.';
  String get invoiceDetailCancel => isEnglish ? 'Cancel' : 'Annuler';
  String get invoiceDetailDeleted => isEnglish ? 'Invoice deleted' : 'Facture supprimée';
  String get invoiceDetailEmailSent =>
      isEnglish ? 'Email sent successfully' : 'Email envoyé avec succès';
  String get invoiceDetailEmailError =>
      isEnglish ? 'Error while sending' : "Erreur lors de l'envoi";
  String get invoiceDetailError => isEnglish ? 'Error' : 'Erreur';
  String get invoiceDetailShareError => isEnglish ? 'Sharing error' : 'Erreur de partage';
  String invoiceDetailEmailSubject(String number, String company) => isEnglish
      ? 'Your invoice $number — $company'
      : 'Votre facture $number — $company';


  // ═══════════════════════════════════════════════════════════════
  //  CLIENTS
  // ═══════════════════════════════════════════════════════════════
  String get clientsTitle => isEnglish ? 'Clients' : 'Clients';
  String get clientsResults => isEnglish ? 'Results' : 'Résultats';
  String get clientsAllClients => isEnglish ? 'All clients' : 'Tous les clients';
  String get clientsSearchHint =>
      isEnglish ? 'Search a client…' : 'Rechercher un client…';
  String get clientsFabLabel => isEnglish ? 'Client' : 'Client';
  String get clientsNoClient =>
      isEnglish ? 'No client' : 'Aucun client';
  String get clientsNoClientMsg => isEnglish
      ? 'Add your first client to get started.'
      : 'Ajoutez votre premier client pour commencer.';
  String get clientsAddFirstClient =>
      isEnglish ? 'Add a client' : 'Ajouter un client';
  String get clientsNoResult =>
      isEnglish ? 'No result' : 'Aucun résultat';
  String get clientsTryAnotherKeyword =>
      isEnglish ? 'Try another keyword' : 'Essayez un autre mot-clé';
  String get clientsSummaryInvoices =>
      isEnglish ? 'Invoices' : 'Factures';
  String get clientsSummaryCollected =>
      isEnglish ? 'Collected' : 'Encaissé';
  String clientsInvoiceCount(int count) => count > 1
      ? (isEnglish ? '$count invoices' : '$count factures')
      : (isEnglish ? '$count invoice' : '$count facture');



  // ═══════════════════════════════════════════════════════════════
  //  PROFIL (profile_update_screen)
  // ═══════════════════════════════════════════════════════════════
  String get profileTitle => isEnglish ? 'My profile' : 'Mon profil';
  String get profileSave => isEnglish ? 'Save' : 'Enregistrer';
  String get profileUpdated =>
      isEnglish ? 'Profile updated successfully' : 'Profil mis à jour avec succès';
  String get profileError => isEnglish ? 'Error: ' : 'Erreur : ';
  String get profileUserNotConnected =>
      isEnglish ? 'User not logged in' : 'Utilisateur non connecté';
  String get profilePersonalInfo =>
      isEnglish ? 'Personal information' : 'Informations personnelles';
  String get profilePersonalSubtitle =>
      isEnglish ? 'Your main contact details' : 'Vos coordonnées principales';
  String get profileFullName => isEnglish ? 'Full name' : 'Nom complet';
  String get profileFullNameHint =>
      isEnglish ? 'E.g. Jean Dupont' : 'Ex. Jean Dupont';
  String get profileNameRequired =>
      isEnglish ? 'Please enter your name' : 'Veuillez entrer votre nom';
  String get profilePhone => isEnglish ? 'Phone' : 'Téléphone';
  String get profilePhoneHint =>
      isEnglish ? 'E.g. +237 6 90 00 00 00' : 'Ex. +237 6 90 00 00 00';
  String get profileCompany => isEnglish ? 'Company' : 'Entreprise';
  String get profileCompanySubtitle =>
      isEnglish ? 'Professional information' : 'Informations professionnelles';
  String get profileCompanyName =>
      isEnglish ? 'Company name' : 'Nom de l\'entreprise';
  String get profileCompanyHint =>
      isEnglish ? 'E.g. NOI Concept Digital' : 'Ex. NOI Concept Digital';
  String get profileAddress => isEnglish ? 'Address' : 'Adresse';
  String get profileAddressHint =>
      isEnglish ? 'E.g. Douala, Cameroon' : 'Ex. Douala, Cameroun';
  String get profileSaveChanges =>
      isEnglish ? 'Save changes' : 'Enregistrer les modifications';
  String get profileSecureAccount =>
      isEnglish ? 'Secure account' : 'Compte sécurisé';
  String get profileMyAccount => isEnglish ? 'My account' : 'Mon compte';
  String get profileStatus => isEnglish ? 'Status' : 'Statut';
  String get profileStatusActive => isEnglish ? 'Active' : 'Actif';
  String get profileAccount => isEnglish ? 'Account' : 'Compte';
  String get profileAccountMember => isEnglish ? 'Member' : 'Membre';
  String get profileCompletion =>
      isEnglish ? 'Profile completion' : 'Complétion du profil';
  String get profileCompleteDone =>
      isEnglish ? 'Your profile is complete ✓' : 'Votre profil est complet ✓';
  String profileCompletionHint(int percent) =>
      isEnglish ? '$percent% — Complete your information'
          : '$percent% — Complétez vos informations';

  // ═══════════════════════════════════════════════════════════════
  //  FOURNISSEURS + TERMES COMMUNS
  // ═══════════════════════════════════════════════════════════════
  String get suppliersTitle => isEnglish ? 'Suppliers' : 'Fournisseurs';
  String suppliersCount(int count) => isEnglish
      ? '$count partner${count > 1 ? 's' : ''} registered'
      : '$count partenaire${count > 1 ? 's' : ''} enregistré${count > 1 ? 's' : ''}';
  String get suppliersSearchHint => isEnglish
      ? 'Search by name, email or phone…'
      : 'Rechercher par nom, email ou téléphone…';
  String get suppliersNoContact =>
      isEnglish ? 'No contact provided' : 'Aucun contact renseigné';
  String get suppliersCannotDeleteLinked => isEnglish
      ? 'Cannot delete: supplier linked to products'
      : 'Impossible de supprimer : fournisseur lié à des produits';
  String get suppliersDeleteTitle =>
      isEnglish ? 'Delete supplier' : 'Supprimer le fournisseur';
  String get suppliersDeleteConfirmPrefix => isEnglish
      ? 'Are you sure you want to delete '
      : 'Voulez-vous vraiment supprimer ';
  String get suppliersDeleted =>
      isEnglish ? 'Supplier deleted' : 'Fournisseur supprimé';
  String get suppliersEmptyTitle => isEnglish ? 'No supplier' : 'Aucun fournisseur';
  String get suppliersEmptySubtitle => isEnglish
      ? 'Add your first supplier\nto link it to your products.'
      : 'Ajoutez votre premier fournisseur\npour l\'associer à vos produits.';
  String get suppliersAdd =>
      isEnglish ? 'Add a supplier' : 'Ajouter un fournisseur';

  // Communs (partagés entre écrans)
  String get commonTotal => isEnglish ? 'Total' : 'Total';
  String get commonActive => isEnglish ? 'Active' : 'Actifs';
  String get commonInactive => isEnglish ? 'Inactive' : 'Inactifs';
  String get commonActiveSingular => isEnglish ? 'Active' : 'Actif';
  String get commonInactiveSingular => isEnglish ? 'Inactive' : 'Inactif';
  String get commonAll => isEnglish ? 'All' : 'Tous';
  String get commonEdit => isEnglish ? 'Edit' : 'Modifier';
  String get commonDelete => isEnglish ? 'Delete' : 'Supprimer';

  String get profileSecurityNote => isEnglish
      ? 'Your information is encrypted and synced securely.'
      : 'Vos informations sont chiffrées et synchronisées en toute sécurité.';

  // ═══════════════════════════════════════════════════════════════
  //  FOURNISSEUR — CRÉATION / ÉDITION
  // ═══════════════════════════════════════════════════════════════
  String get supplierFormTitleEdit =>
      isEnglish ? 'Edit supplier' : 'Modifier fournisseur';
  String get supplierFormTitleNew =>
      isEnglish ? 'New supplier' : 'Nouveau fournisseur';
  String get supplierFormSave => isEnglish ? 'Save' : 'Enregistrer';
  String get supplierFormAdd => isEnglish ? 'Add' : 'Ajouter';
  String get supplierFormSectionEdit =>
      isEnglish ? 'Edit information' : 'Modifier les informations';
  String get supplierFormSectionBasic =>
      isEnglish ? 'Basic information' : 'Informations de base';
  String get supplierFormSectionContact =>
      isEnglish ? 'Contact details' : 'Coordonnées';
  String get supplierFormSectionNotes =>
      isEnglish ? 'Additional notes' : 'Notes complémentaires';
  String get supplierFormName => isEnglish ? 'Supplier name' : 'Nom du fournisseur';
  String get supplierFormContactPerson =>
      isEnglish ? 'Contact person' : 'Personne de contact';
  String get supplierFormTaxId => isEnglish ? 'Tax ID / RCCM' : 'NUI / RCCM';
  String get supplierFormEmail => isEnglish ? 'Email' : 'Email';
  String get supplierFormPhone => isEnglish ? 'Phone' : 'Téléphone';
  String get supplierFormAddress => isEnglish ? 'Address' : 'Adresse';
  String get supplierFormNotes => isEnglish ? 'Notes' : 'Notes';
  String get supplierFormRequired => isEnglish ? 'Required' : 'Champ requis';
  String get supplierFormEmailInvalid =>
      isEnglish ? 'Invalid email' : 'Email invalide';
  String get supplierFormButtonSave =>
      isEnglish ? 'Save supplier' : 'Sauvegarder le fournisseur';
  String get supplierFormButtonAdd =>
      isEnglish ? 'Add supplier' : 'Ajouter le fournisseur';
  String get supplierFormEmptyTitleEdit =>
      isEnglish ? 'Update this supplier' : 'Mettez à jour ce fournisseur';
  String get supplierFormEmptyTitleNew =>
      isEnglish ? 'Add a new partner' : 'Ajoutez un nouveau partenaire';
  String get supplierFormStatusTitle =>
      isEnglish ? 'Supplier status' : 'Statut du fournisseur';
  String get supplierFormStatusActive =>
      isEnglish ? 'Active — can be linked to products'
          : 'Actif — associable aux produits';
  String get supplierFormStatusInactive =>
      isEnglish ? 'Inactive — hidden from selections'
          : 'Inactif — masqué des sélections';
  String get supplierFormLimitReached => isEnglish
      ? 'Supplier limit reached. Upgrade to a higher plan.'
      : 'Limite de fournisseurs atteinte. Passez au plan supérieur.';
  String get supplierFormAdded =>
      isEnglish ? 'Supplier added successfully' : 'Fournisseur ajouté avec succès';
  String get supplierFormUpdated => isEnglish
      ? 'Supplier updated successfully'
      : 'Fournisseur modifié avec succès';
  String get supplierFormError => isEnglish ? 'Error: ' : 'Erreur: ';

  // ═══════════════════════════════════════════════════════════════
  //  SUPPLIER DETAIL
  // ═══════════════════════════════════════════════════════════════
  String get edit => isEnglish ? 'Edit' : 'Modifier';
  String get productsProvided =>
      isEnglish ? 'Products supplied' : 'Produits fournis';
  String productsProvidedCount(int count) => isEnglish
      ? '$count item${count > 1 ? 's' : ''}'
      : '$count référence${count > 1 ? 's' : ''}';
  String get active => isEnglish ? 'Active' : 'Actif';
  String get inactive => isEnglish ? 'Inactive' : 'Inactif';
  String get phone => isEnglish ? 'Phone' : 'Téléphone';
  String get emailLabel => isEnglish ? 'Email' : 'Email';
  String get contact => isEnglish ? 'Contact' : 'Contact';
  String get address => isEnglish ? 'Address' : 'Adresse';
  String get volumeYtd => isEnglish ? 'VOLUME YTD' : 'VOLUME YTD';
  String get productsKpi => isEnglish ? 'PRODUCTS' : 'PRODUITS';
  String stockAlertsCount(int count) => isEnglish
      ? '$count alert${count > 1 ? 's' : ''}'
      : '$count alerte${count > 1 ? 's' : ''}';
  String get noProductLinked =>
      isEnglish ? 'No linked product' : 'Aucun produit lié';
  String get associateProductsHint => isEnglish
      ? 'Link products to this supplier\nfrom stock management.'
      : 'Associez des produits à ce fournisseur\ndepuis la gestion du stock.';
  String get outOfStock => isEnglish ? 'Out of stock' : 'Rupture';
  String get lowStock => isEnglish ? 'Low stock' : 'Stock faible';
  String inStockLabel(int quantity) =>
      isEnglish ? 'In stock ($quantity)' : 'En stock ($quantity)';
  String get noCategory => isEnglish ? 'No category' : 'Sans catégorie';

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
