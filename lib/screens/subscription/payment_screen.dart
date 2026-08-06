// lib/screens/subscription/payment_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/plan.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/nochpay_service.dart';
import '../../services/notification_service.dart';
import '../../models/notification.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../payment/mobile_money_webview.dart';

class PaymentScreen extends StatefulWidget {
  final Plan plan;
  final VoidCallback onPaymentComplete;

  const PaymentScreen({
    super.key,
    required this.plan,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final NochPayService _nochPayService = NochPayService();
  final NotificationService _notificationService = NotificationService();

    String _selectedMethod = 'orange_money';
  String _phoneNumber = '';
  String _confirmationCode = '';
  String _userConfirmationCode = '';
  String _transactionId = '';
  String _paymentUrl = ''; // Lien NotchPay Collect (carte / portefeuilles numériques)
  String _qrCodeUrl = ''; // URL du QR code (paiement QR)
  bool _isProcessing = false;
  bool _isConfirming = false;
  String _error = '';

  final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'orange_money',
      name: 'Orange Money',
      icon: Icons.phone_android,
      color: Colors.orange,
      category: PaymentMethodCategory.ussd,
    ),
    PaymentMethod(
      id: 'mtn_money',
      name: 'MTN Mobile Money',
      icon: Icons.phone_android,
      color: const Color(0xFFFFD700),
      category: PaymentMethodCategory.ussd,
    ),
    PaymentMethod(
      id: 'wave',
      name: 'Wave',
      icon: Icons.waves,
      color: Colors.blue,
      category: PaymentMethodCategory.ussd,
    ),
    PaymentMethod(
      id: 'card',
      name: 'Carte bancaire',
      icon: Icons.credit_card,
      color: Colors.purple,
      category: PaymentMethodCategory.collect,
    ),
    // ✅ Méthodes alternatives (docs Notch Pay "Other Payment Methods")
    PaymentMethod(
      id: 'asso',
      name: 'Assoh (Portefeuille)',
      icon: Icons.account_balance_wallet,
      color: Colors.teal,
      category: PaymentMethodCategory.collect,
    ),
    PaymentMethod(
      id: 'kudi',
      name: 'Kudi (Portefeuille)',
      icon: Icons.account_balance_wallet,
      color: Colors.indigo,
      category: PaymentMethodCategory.collect,
    ),
        PaymentMethod(
      id: 'qr_code',
      name: 'Paiement par QR Code',
      icon: Icons.qr_code_2,
      color: Colors.green,
      category: PaymentMethodCategory.qrCode,
    ),
  ];

  PaymentMethod? get _selectedPaymentMethod {
    for (final m in _paymentMethods) {
      if (m.id == _selectedMethod) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _notificationService.init();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor ?? Colors.black;
    final subTextColor = themeProvider.subTextColor ?? Colors.grey;
    final primaryColor = themeProvider.primaryColor ?? Colors.blue;
    final bgColor = themeProvider.backgroundColor ?? Colors.white;
    final cardColor = themeProvider.cardColor ?? Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Paiement',
          style: TextStyle(color: textColor),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé du plan
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Résumé de votre abonnement',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.plan.name,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.plan.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total à payer',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                      ),
                      Text(
                        widget.plan.getFormattedPrice(),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isConfirming)
              // 🔥 Paiement Collect (carte / portefeuilles) : WebView intégré
              // pour un retour fluide vers l'app + détection automatique.
              (_selectedPaymentMethod?.category ==
                          PaymentMethodCategory.collect &&
                      _paymentUrl.isNotEmpty)
                  ? _buildCollectWebView()
                  : _buildConfirmationView(
                      isDark,
                      textColor,
                      subTextColor,
                      primaryColor,
                      cardColor,
                    )
            else
              _buildPaymentForm(
                isDark,
                textColor,
                subTextColor,
                primaryColor,
                cardColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color cardColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                Text(
          'Méthode de paiement',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Choisissez le moyen le plus adapté (Mobile Money, portefeuille numérique, carte ou QR code).',
          style: TextStyle(fontSize: 12, color: subTextColor),
        ),
        const SizedBox(height: 12),
        ..._paymentMethods.map((method) => _buildPaymentMethodTile(method, isDark, textColor, primaryColor)),
        const SizedBox(height: 16),

        // Numéro de téléphone (requis pour Mobile Money / USSD uniquement)
        if (_selectedPaymentMethod?.category == PaymentMethodCategory.ussd)
          TextFormField(
            keyboardType: TextInputType.phone,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone',
              labelStyle: TextStyle(color: subTextColor),
              hintText: '6X XX XX XX XX',
              hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
              prefixIcon: Icon(Icons.phone, color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (value) => setState(() => _phoneNumber = value),
          ),
        if (_selectedPaymentMethod?.category == PaymentMethodCategory.ussd)
          const SizedBox(height: 16),

        if (_error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ),
        if (_error.isNotEmpty) const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Traitement en cours...'),
                    ],
                  )
                : Text(
                    'Payer ${widget.plan.getFormattedPrice()}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: subTextColor),
            const SizedBox(width: 6),
            Text(
              'Paiement sécurisé via NochPay • Données cryptées',
              style: TextStyle(fontSize: 12, color: subTextColor),
            ),
          ],
        ),
      ],
    );
  }

  /// Affiche la page de paiement sécurisée NochPay dans une WebView intégrée.
  /// Retour automatique vers l'app dès que le paiement est détecté (polling).
  Widget _buildCollectWebView() {
    return MobileMoneyWebView(
      paymentUrl: _paymentUrl,
      provider: _selectedPaymentMethod?.name ?? 'Collect',
      transactionReference: _transactionId,
      onSuccess: () {
        _completeSubscription();
      },
      onCancel: () {
        if (mounted) {
          setState(() {
            _isConfirming = false;
            _error = 'Paiement annulé. Vous pouvez réessayer.';
          });
        }
      },
    );
  }

  /// Identifiant de transaction tronqué sans crash (ID < 8 caractères).
  String _shortTxId() {
    if (_transactionId.isEmpty) return '...';
    return _transactionId.length <= 8
        ? _transactionId
        : _transactionId.substring(0, 8);
  }

    Widget _buildConfirmationView(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    Color cardColor,
  ) {
    final category = _selectedPaymentMethod?.category;
    final methodName = _selectedPaymentMethod?.name ?? 'Paiement';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== Résumé du montant =====
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Montant:', style: TextStyle(color: subTextColor)),
                  Text(
                    widget.plan.getFormattedPrice(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
              if (_phoneNumber.isNotEmpty &&
                  category == PaymentMethodCategory.ussd) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Téléphone:', style: TextStyle(color: subTextColor)),
                    Text(_phoneNumber,
                        style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Méthode:', style: TextStyle(color: subTextColor)),
                  Text(methodName,
                      style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transaction:', style: TextStyle(color: subTextColor)),
                  Text('#${_shortTxId()}',
                      style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ===== Contenu spécifique à la méthode =====
        if (category == PaymentMethodCategory.ussd)
          _buildUssdConfirmation(isDark, subTextColor)
        else if (category == PaymentMethodCategory.collect)
          _buildCollectConfirmation(isDark, subTextColor, primaryColor)
        else if (category == PaymentMethodCategory.qrCode)
          _buildQrCodeConfirmation(
              isDark, subTextColor, primaryColor, cardColor),

        // ===== Code SMS (Mobile Money uniquement) =====
        if (category == PaymentMethodCategory.ussd &&
            _confirmationCode.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Code de confirmation envoyé par SMS',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _userConfirmationCode = value),
                        decoration: InputDecoration(
                          hintText: 'Entrez le code reçu',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: isDark ? Colors.grey[800] : Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmWithCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirmer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _isConfirming = false;
              _transactionId = '';
              _confirmationCode = '';
              _userConfirmationCode = '';
              _paymentUrl = '';
              _qrCodeUrl = '';
            });
          },
          child: const Text('Annuler le paiement', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  // ---- Vue Mobile Money (USSD) ----
  Widget _buildUssdConfirmation(bool isDark, Color subTextColor) {
    return Column(
      children: [
        const Icon(Icons.smartphone, size: 48, color: Colors.orange),
        const SizedBox(height: 12),
        Text(
          'En attente de confirmation...',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Votre client va recevoir une invite USSD sur son téléphone.\n'
          'Demandez-lui de saisir son code PIN pour confirmer le paiement.',
          style: TextStyle(fontSize: 13, color: subTextColor, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(strokeWidth: 2),
      ],
    );
  }

  // ---- Vue Carte / Portefeuilles numériques (NotchPay Collect) ----
  Widget _buildCollectConfirmation(bool isDark, Color subTextColor, Color primaryColor) {
    final isWallet = _selectedPaymentMethod?.category == PaymentMethodCategory.collect &&
        _selectedMethod != 'card';
    return Column(
      children: [
        Icon(isWallet ? Icons.account_balance_wallet : Icons.credit_card,
            size: 48, color: Colors.purple.shade300),
        const SizedBox(height: 12),
        Text(
          isWallet ? 'Paiement par portefeuille numérique' : 'Paiement par carte bancaire',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Réglez via la page sécurisée NotchPay. '
          '${isWallet ? 'Les portefeuilles tels que Assoh, Kudi apparaissent dans les options.' : ''}',
          style: TextStyle(fontSize: 13, color: subTextColor, height: 1.4),
          textAlign: TextAlign.center,
        ),
                const SizedBox(height: 16),
        SelectableText(
          _paymentUrl,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 16),
        // Bouton principal : ouvrir la page de paiement sécurisée NotchPay.
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _openPaymentUrl,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ouvrir la page de paiement'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _sharePaymentLink(),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Envoyer le lien'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _paymentUrl));
                _showSnackBar('Lien de paiement copié ✅', Colors.green);
              },
              child: const Text('Copier'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const CircularProgressIndicator(strokeWidth: 2),
      ],
    );
  }

  // ---- Vue Paiement par QR code ----
  Widget _buildQrCodeConfirmation(
      bool isDark, Color subTextColor, Color primaryColor, Color cardColor) {
    return Column(
      children: [
        Text(
          'Scannez pour payer',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          'Affichez ce QR code sur votre écran ou transmettez-le au payeur. '
          'Le paiement est détecté automatiquement une fois scanné et validé.',
          style: TextStyle(fontSize: 13, color: subTextColor, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Affichage du QR code (généré localement via qr_flutter si l'URL
        // renvoyée par l'API n'est pas directement affichable).
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: _qrCodeUrl.isNotEmpty ? _qrCodeUrl : _transactionId,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                _paymentUrl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _sharePaymentLink(),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Partager'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const CircularProgressIndicator(strokeWidth: 2),
      ],
    );
  }

    /// Ouvre la page de paiement sécurisée NotchPay Collect dans le navigateur.
  /// C'est ici que le client choisit son moyen (Mobile Money, portefeuille
  /// numérique Assoh, carte bancaire…) et règle.
  Future<void> _openPaymentUrl() async {
    final url = _paymentUrl.isNotEmpty ? _paymentUrl : _qrCodeUrl;
    if (url.isEmpty) {
      _showSnackBar('Lien de paiement indisponible', Colors.orange);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Impossible d\'ouvrir le lien de paiement', Colors.red);
      return;
    }
  }

  /// Partage le lien de paiement sécurisé (SMS / WhatsApp / copie) pour les
  /// méthodes de type Collect (carte, portefeuilles numériques) et QR code.
  Future<void> _sharePaymentLink() async {
    final message = 'Règlement de votre abonnement ${widget.plan.name} '
        'd\'un montant de ${widget.plan.getFormattedPrice()} '
        'via ce lien sécurisé : ${_paymentUrl.isEmpty ? _qrCodeUrl : _paymentUrl}';
    await SharePlus.instance.share(ShareParams(text: message));
  }

  Widget _buildPaymentMethodTile(
    PaymentMethod method,
    bool isDark,
    Color textColor,
    Color primaryColor,
  ) {
    final isSelected = _selectedMethod == method.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? method.color.withOpacity(0.1) : (isDark ? Colors.grey[800] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? method.color : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(method.icon, color: method.color, size: 24),
            const SizedBox(width: 12),
            Text(
              method.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? method.color : textColor,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: method.color, size: 20),
          ],
        ),
      ),
    );
  }

    Future<void> _processPayment() async {
    final category = _selectedPaymentMethod?.category;
    if (category == null) return;

    // Le numéro de téléphone n'est requis que pour Mobile Money (USSD).
    if (category == PaymentMethodCategory.ussd &&
        (_phoneNumber.isEmpty || _phoneNumber.length < 9)) {
      _showSnackBar('Numéro de téléphone invalide', Colors.red);
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = '';
    });

    try {
      final reference = 'SUB-${DateTime.now().millisecondsSinceEpoch}';

      final result = await _nochPayService.initiatePayment(
        amount: widget.plan.price,
        currency: widget.plan.currency,
        phoneNumber: _phoneNumber,
        invoiceNumber: reference,
        description: 'Abonnement ${widget.plan.name}',
        paymentMethod: _selectedMethod,
        customerName: null,
        customerEmail: null,
      );

      if (result['success'] != true) {
        setState(() {
          _isProcessing = false;
          _error = result['error'] ?? 'Erreur d\'initialisation';
        });
        _showSnackBar(_error, Colors.red);
        return;
      }

      final txRef =
          (result['reference'] ?? result['transaction_id']) as String;
      final authorizationUrl = result['authorization_url'] as String? ?? '';

      setState(() {
        _transactionId = txRef;
        _paymentUrl = authorizationUrl.isNotEmpty
            ? authorizationUrl
            : 'https://pay.notchpay.co/payments/$txRef';
        _confirmationCode = result['confirmation_code'] ?? '';
        _isProcessing = false;
        _isConfirming = true;
      });

      // Sauvegarde de la transaction en attente.
      await _nochPayService.savePendingTransaction(
        transactionId: txRef,
        invoiceId: 'sub_${DateTime.now().millisecondsSinceEpoch}',
        invoiceNumber: reference,
        phoneNumber: _phoneNumber,
        amount: widget.plan.price,
        reference: txRef,
        authorizationUrl: _paymentUrl,
        paymentMethod: _selectedMethod,
      );

      switch (category) {
        // ---- Mobile Money → invite USSD sur le téléphone du client ----
        case PaymentMethodCategory.ussd:
          final ussd = await _nochPayService.processMobileMoneyUSSD(
            reference: txRef,
            method: _selectedMethod,
            phoneNumber: _phoneNumber,
          );
          if (ussd['success'] != true) {
            setState(() {
              _isProcessing = false;
              _error = ussd['error'] ?? 'Erreur lors de la demande USSD';
            });
            _showSnackBar(_error, Colors.red);
            return;
          }
          _startAutoCheck();
          _showSnackBar(
            'Paiement initié. Confirmez l\'invite USSD sur votre téléphone.',
            Colors.blue,
          );
          break;

        // ---- Carte & portefeuilles numériques → page NotchPay Collect ----
        case PaymentMethodCategory.collect:
          // La page Collect affiche les options disponibles (carte, Assoh, …).
          // Le statut est vérifié automatiquement une fois le règlement fait.
          _startAutoCheck();
          _showSnackBar(
            'Ouvrez le lien sécurisé pour finaliser le paiement.',
            Colors.blue,
          );
          break;

        // ---- Paiement par QR code → affichage du QR code à scanner ----
        case PaymentMethodCategory.qrCode:
          final qr = await _nochPayService.fetchQRCodeUrl(
            reference: txRef,
            fallbackUrl: _paymentUrl,
          );
          if (qr['success'] == true) {
            _qrCodeUrl = (qr['qr_code_url'] ?? _paymentUrl) as String;
          } else {
            // Repli : on génère un QR pointant vers la page Collect.
            _qrCodeUrl = _paymentUrl;
          }
          if (mounted) setState(() {});
          _startAutoCheck();
          _showSnackBar(
            'Scannez le QR code pour régler votre abonnement.',
            Colors.blue,
          );
          break;
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Erreur: $e';
      });
      _showSnackBar(_error, Colors.red);
    }
  }

  void _startAutoCheck() {
    int checks = 0;
    const maxChecks = 12;

    Future.delayed(const Duration(seconds: 5), () {
      _autoCheckStatus(checks, maxChecks);
    });
  }

    Future<void> _autoCheckStatus(int checks, int maxChecks) async {
    if (checks >= maxChecks || !_isConfirming) return;

    final result = await _nochPayService.checkPaymentStatus(_transactionId);
    final status = result['status']?.toString() ?? '';

    // Paiement réussi (status `complete` chez Notch Pay, ou `paid`).
    if (result['success'] == true && result['is_success'] == true) {
      await _completeSubscription();
      return;
    }

    final failedStatuses = ['failed', 'canceled', 'cancelled', 'rejected', 'expired', 'abandoned'];
    if (result['success'] == true && failedStatuses.contains(status)) {
      setState(() {
        _isConfirming = false;
        _error = 'Le paiement a échoué (${status == 'abandoned' ? 'abandonné' : status})';
      });
      await _notificationService.addNotification(
        AppNotification(
          title: '⚠️ Paiement échoué',
          body: 'Le paiement pour l\'abonnement ${widget.plan.name} a échoué. Veuillez réessayer.',
          type: NotificationType.system_update.toString(),
        ),
      );
      _showSnackBar(_error, Colors.red);
      return;
    }

    Future.delayed(const Duration(seconds: 5), () {
      _autoCheckStatus(checks + 1, maxChecks);
    });
  }

  Future<void> _confirmWithCode() async {
    if (_userConfirmationCode.isEmpty || _userConfirmationCode.length < 6) {
      _showSnackBar('Veuillez entrer le code de confirmation reçu par SMS', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    final result = await _nochPayService.confirmPaymentWithCode(
      transactionId: _transactionId,
      confirmationCode: _userConfirmationCode,
    );

    if (result['success'] == true) {
      await _completeSubscription();
    } else {
      setState(() {
        _isProcessing = false;
        _error = result['error'] ?? 'Code de confirmation invalide';
      });
      _showSnackBar(_error, Colors.red);
    }
  }

  Future<void> _completeSubscription() async {
    final authProvider = context.read<AppAuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (authProvider.user == null) {
      _showSnackBar('Utilisateur non connecté', Colors.red);
      return;
    }

    final success = await subscriptionProvider.createSubscription(
      userId: authProvider.user!.id,
      planId: widget.plan.id,
      paymentMethod: _selectedMethod,
      paymentId: _transactionId,
      amount: widget.plan.price,
      currency: widget.plan.currency,
      interval: widget.plan.interval,
    );

    await _nochPayService.removePendingTransaction(_transactionId);

    setState(() {
      _isConfirming = false;
      _isProcessing = false;
    });

    if (success) {
      await _notificationService.addNotification(
        AppNotification(
          title: '🎉 Abonnement activé',
          body: 'Votre abonnement ${widget.plan.name} a été activé avec succès.',
          type: NotificationType.system_update.toString(),
        ),
      );
      _showSnackBar('Abonnement ${widget.plan.name} activé avec succès ! ✅', Colors.green);
      widget.onPaymentComplete();
      Navigator.pop(context, true);
    } else {
      await _notificationService.addNotification(
        AppNotification(
          title: '⚠️ Erreur d\'activation',
          body: 'Le paiement a été effectué mais l\'activation de l\'abonnement a échoué. Contactez le support.',
          type: NotificationType.system_update.toString(),
        ),
      );
      _showSnackBar('Erreur lors de l\'activation de l\'abonnement', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Catégorie de flux de paiement selon la méthode.
///
/// - [ussd]   : Mobile Money → invite USSD sur le téléphone du client.
/// - [collect]: Carte bancaire & portefeuilles numériques → page NotchPay
///              Collect via `authorization_url`.
/// - [qrCode] : Paiement par QR code → affichage d'un QR code à scanner.
enum PaymentMethodCategory { ussd, collect, qrCode }

class PaymentMethod {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final PaymentMethodCategory category;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.category = PaymentMethodCategory.ussd,
  });
}