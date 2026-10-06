// lib/screens/subscription/payment_screen.dart
//
// 💳 Paiement d'abonnement via ENKAP (Orange Money / MTN / Carte).
// 🎨 Refonte moderne : plan hero gradient, méthodes en cards animées,
// spinner de traitement élégant, feedback d'erreur repensé.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/notification.dart';
import '../../models/plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/enkap_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/enkap_checkout_dialog.dart';

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
  final EnkapService _enkapService = EnkapService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedMethod = EnkapService.methodOrangeMoney;
  String _phoneNumber = '';
  String _transactionId = '';
  bool _isProcessing = false;
  String _error = '';

  bool get _isCard => _selectedMethod == EnkapService.methodCard;

  final List<({String id, String name, IconData icon, Color color})> _methods =
      [
    (
      id: EnkapService.methodOrangeMoney,
      name: 'Orange Money',
      icon: Icons.phone_android_rounded,
      color: const Color(0xFFFF7900),
    ),
    (
      id: EnkapService.methodMtnMoney,
      name: 'MTN Mobile Money',
      icon: Icons.phone_android_rounded,
      color: const Color(0xFFFFCC00),
    ),
    (
      id: EnkapService.methodCard,
      name: 'Carte bancaire',
      icon: Icons.credit_card_rounded,
      color: const Color(0xFF7C3AED),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _notificationService.init();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final accent = Color(widget.plan.accentColorValue);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F0F14)
          : const Color(0xFFF7F4F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar minimal ──
          SliverAppBar(
            backgroundColor: isDark
                ? const Color(0xFF0F0F14)
                : const Color(0xFFF7F4F9),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: textColor,
              ),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Paiement',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.4,
              ),
            ),
            centerTitle: true,
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildPlanSummary(accent, isDark),
                const SizedBox(height: 24),
                _buildSectionLabel('Méthode de paiement', textColor),
                const SizedBox(height: 4),
                Text(
                  'Choisissez votre moyen de paiement sécurisé',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ..._methods.asMap().entries.map(
                      (e) => _buildMethodTile(
                        e.value,
                        e.key,
                        isDark,
                        textColor,
                        subTextColor,
                      ),
                    ),
                const SizedBox(height: 20),
                if (!_isCard) ...[
                  _buildSectionLabel('Numéro Mobile Money', textColor),
                  const SizedBox(height: 12),
                  _buildPhoneField(isDark, textColor, subTextColor, accent),
                  const SizedBox(height: 20),
                ],
                if (_error.isNotEmpty) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 16),
                ],
                _buildPayButton(accent, isDark),
                const SizedBox(height: 16),
                _buildSecurityRow(subTextColor),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  RÉSUMÉ DU PLAN (HERO)
  // ═══════════════════════════════════════════════════════════
  Widget _buildPlanSummary(Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            accent.withValues(alpha: 0.75),
            const Color(0xFF7C3AED),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Motif décoratif
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'VOTRE ABONNEMENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.plan.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              if (widget.plan.tagline.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.plan.tagline,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total à payer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.plan.getPriceNumber(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          widget.plan.currency,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildSectionLabel(String label, Color textColor) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: textColor.withValues(alpha: 0.55),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MÉTHODE DE PAIEMENT (CARTES ANIMÉES)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMethodTile(
    ({String id, String name, IconData icon, Color color}) method,
    int index,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final isSelected = _selectedMethod == method.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = method.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? method.color.withValues(alpha: isDark ? 0.14 : 0.08)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? method.color
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: method.color.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      method.color,
                      method.color.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: method.color.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(method.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: textColor,
                      ),
                    ),
                    Text(
                      _methodSubtitle(method.id),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? method.color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? method.color
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.15)),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 60 * index),
          duration: 350.ms,
        )
        .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  String _methodSubtitle(String id) {
    switch (id) {
      case EnkapService.methodOrangeMoney:
        return 'Paiement instantané via votre compte Orange';
      case EnkapService.methodMtnMoney:
        return 'Paiement instantané via votre compte MTN';
      case EnkapService.methodCard:
        return 'Visa, MasterCard — Paiement sécurisé 3D Secure';
      default:
        return '';
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  CHAMP TÉLÉPHONE
  // ═══════════════════════════════════════════════════════════
  Widget _buildPhoneField(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color accent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        cursorColor: accent,
        onChanged: (value) => setState(() => _phoneNumber = value),
        decoration: InputDecoration(
          hintText: '6X XX XX XX XX',
          hintStyle: TextStyle(
            color: subTextColor.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Icon(
              Icons.phone_rounded,
              color: accent,
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15, end: 0);
  }

  // ═══════════════════════════════════════════════════════════
  //  BANNIÈRE D'ERREUR
  // ═══════════════════════════════════════════════════════════
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).shakeX(amount: 4, duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════════
  //  BOUTON PAYER
  // ═══════════════════════════════════════════════════════════
  Widget _buildPayButton(Color accent, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [accent, accent.withValues(alpha: 0.75)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isProcessing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Traitement en cours…',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Payer ${widget.plan.getFormattedPrice()}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSecurityRow(Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 13, color: subTextColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Paiement sécurisé via E-nkap • Données cryptées',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: subTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  // ═══════════════════════════════════════════════════════════
  //  TRAITEMENT DU PAIEMENT (logique inchangée)
  // ═══════════════════════════════════════════════════════════
  Future<void> _processPayment() async {
    if (!_isCard && (_phoneNumber.isEmpty || _phoneNumber.length < 9)) {
      setState(() => _error = 'Numéro de téléphone invalide');
      _showSnackBar('Numéro de téléphone invalide', Colors.red);
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = '';
    });

    final authProvider = context.read<AppAuthProvider>();
    final method = _methods.firstWhere((m) => m.id == _selectedMethod);
    final reference = 'SUB-${DateTime.now().millisecondsSinceEpoch}';
    _transactionId = reference;

    final uid = authProvider.user?.id ?? '';
    if (uid.isNotEmpty) {
      await _enkapService.registerSubscriptionIntent(
        reference: reference,
        userId: uid,
        planId: widget.plan.id,
        amount: widget.plan.price,
        currency: widget.plan.currency,
        paymentMethod: _selectedMethod,
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EnkapCheckoutDialog(
        amount: widget.plan.price,
        currency: widget.plan.currency,
        description: 'Abonnement ${widget.plan.name}',
        merchantReference: reference,
        providerName: method.name,
        phoneNumber: _isCard ? null : _phoneNumber,
        customerName: authProvider.user?.displayName,
        customerEmail: authProvider.user?.email,
        onSuccess: () {
          _completeSubscription();
        },
        onCancel: () {
          if (mounted) {
            setState(() => _isProcessing = false);
            _showSnackBar('Paiement annulé', Colors.orange);
          }
        },
      ),
    );
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

    setState(() => _isProcessing = false);

    if (success) {
      await _notificationService.addNotification(
        AppNotification(
          title: '🎉 Abonnement activé',
          body:
              'Votre abonnement ${widget.plan.name} a été activé avec succès.',
          type: NotificationType.system_update.toString(),
        ),
      );
      _showSnackBar(
        'Abonnement ${widget.plan.name} activé avec succès ! ✅',
        Colors.green,
      );
      widget.onPaymentComplete();
      Navigator.pop(context, true);
    } else {
      await _notificationService.addNotification(
        AppNotification(
          title: '⚠️ Erreur d\'activation',
          body:
              'Le paiement a été effectué mais l\'activation de l\'abonnement '
              'a échoué. Contactez le support.',
          type: NotificationType.system_update.toString(),
        ),
      );
      setState(
          () => _error = 'Erreur lors de l\'activation de l\'abonnement');
      _showSnackBar(
          'Erreur lors de l\'activation de l\'abonnement', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}