// lib/screens/dashboard/relance_screen.dart
//
// 📣 Écran de relance marketing (module payant) :
//  - Relance d'un client ou de plusieurs à la fois
//  - Canaux : notification toast, email, WhatsApp, SMS
//  - Messages prédéfinis (facture impayée, nouveau produit)
//
// 🎨 Refonte moderne : dashboard visuel, cartes stat gradient,
// graphique épuré, sélecteur canal en cards, client tiles avec avatars.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../../services/relance_service.dart';
import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/minimal_ui.dart';

class RelanceScreen extends StatefulWidget {
  final String? initialClientId;

  const RelanceScreen({super.key, this.initialClientId});

  @override
  State<RelanceScreen> createState() => _RelanceScreenState();
}

class _RelanceScreenState extends State<RelanceScreen> {
  final DatabaseService _db = DatabaseService();
  final RelanceService _relance = RelanceService();

  List<Client> _clients = [];
  List<Invoice> _invoices = [];
  bool _relanceAuto = true;
  final Set<String> _selected = {};
  bool _isLoading = true;
  RelanceChannel _channel = RelanceChannel.whatsapp;
  String _subject = 'Rappel de facture';
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final results = await Future.wait([_db.getClients(), _db.getInvoices()]);
      final clients = results[0] as List<Client>? ?? [];
      final invoices = results[1] as List<Invoice>? ?? [];
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _invoices = invoices;
        _isLoading = false;
      });
      if (widget.initialClientId != null) {
        setState(() => _selected.add(widget.initialClientId!));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final sub = context.watch<SubscriptionProvider>();

    return GlassScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Relance clients',
          style: TextStyle(
            color: theme.textColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: sub.canUseRelance
          ? _buildBody(theme, sub)
          : _buildLocked(sub),
    );
  }

  Widget _buildLocked(SubscriptionProvider sub) {
    return EmptyState(
      icon: Icons.lock_outline,
      message:
          'Le module de relance clients (email, WhatsApp, SMS) est réservé '
          'aux plans Pro et Business.',
      actionLabel: 'Voir les plans',
      onAction: () => Navigator.of(context).pushNamed('/subscription'),
    );
  }

  Widget _buildBody(ThemeProvider theme, SubscriptionProvider sub) {
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final isDark = theme.isDarkMode;
    final primary = theme.primaryColor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HERO : Titre + sous-titre ──
          _buildHeroHeader(theme, isDark),

          const SizedBox(height: 20),

          // ── Cartes stats ──
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Total envoyé',
                  value: _formatK(_invoices
                      .where((i) => i.status == 'sent' || i.status == 'paid')
                      .fold<double>(
                          0, (sum, i) => sum + i.totalAmount)),
                  sub: '+15% ce mois',
                  icon: Icons.send_rounded,
                  color: const Color(0xFF4338CA),
                  text: textColor,
                  subText: subTextColor,
                  trendPositive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'Impayés',
                  value: _formatK(_invoices
                      .where((i) => i.status == 'overdue')
                      .fold<double>(
                          0, (sum, i) => sum + i.totalAmount)),
                  sub:
                      '${_invoices.where((i) => i.status == 'overdue').length} factures',
                  icon: Icons.error_outline_rounded,
                  color: const Color(0xFFEF4444),
                  text: textColor,
                  subText: subTextColor,
                  trendPositive: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Carte Relances Auto ──
          _buildAutoSwitchCard(theme, isDark),

          const SizedBox(height: 20),

          // ── Graphique tendance ──
          _buildTrendChart(theme, isDark, primary),

          const SizedBox(height: 24),

          // ── Factures récentes ──
          _buildSectionHeader(
            'Factures récentes',
            actionLabel: 'Voir tout',
            onAction: () =>
                Navigator.of(context).pushNamed('/dashboard/invoices'),
            theme: theme,
          ),
          const SizedBox(height: 12),
          if (_invoices.isEmpty)
            _buildEmptyMini(
              theme,
              icon: Icons.receipt_long_outlined,
              label: 'Aucune facture pour le moment',
            )
          else
            ..._invoices
                .take(4)
                .map((inv) => _buildInvoiceTile(inv, theme, isDark)),

          const SizedBox(height: 28),

          // ── Canal de relance ──
          _buildSectionHeader('Canal de relance', theme: theme),
          const SizedBox(height: 12),
          _buildChannelSelector(theme, isDark),

          const SizedBox(height: 24),

          // ── Objet + Message ──
          _buildSectionHeader('Contenu du message', theme: theme),
          const SizedBox(height: 12),

          TextField(
            controller: TextEditingController(text: _subject),
            onChanged: (v) => _subject = v,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              theme,
              isDark,
              label: 'Objet',
              icon: Icons.subject_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: _message),
            onChanged: (v) => _message = v,
            maxLines: 4,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: _inputDecoration(
              theme,
              isDark,
              label: 'Message',
              hint: 'Bonjour {client}, ...',
              icon: Icons.message_outlined,
              alignLabelTop: true,
            ),
          ),
          const SizedBox(height: 12),

          // ── Presets ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _presetChip(
                'Rappel facture',
                Icons.receipt_outlined,
                theme,
                onTap: () => setState(() {
                  _subject = 'Rappel de facture';
                  _message = _relance.buildInvoiceReminder(
                    _placeholderInvoice(),
                    '{client}',
                  );
                }),
              ),
              _presetChip(
                'Nouveau produit',
                Icons.inventory_2_outlined,
                theme,
                onTap: () => setState(() {
                  _subject = 'Nouveau produit en stock';
                  _message =
                      'Bonjour {client},\n\n${_relance.buildNewProductMessage(_placeholderProduct())}';
                }),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Clients ──
          _buildSectionHeader(
            'Destinataires (${_selected.length})',
            theme: theme,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => setState(
                      () => _selected.addAll(_clients.map((c) => c.id))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    'Tout',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    'Aucun',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: subTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_clients.isEmpty)
            _buildEmptyMini(
              theme,
              icon: Icons.people_outline_rounded,
              label: 'Aucun client. Créez-en d\'abord.',
            )
          else
            ..._clients.map((c) => _clientTile(c, theme, isDark)),

          const SizedBox(height: 28),

          // ── Bouton d'envoi ──
          GradientButton(
            label: _selected.isEmpty
                ? 'Sélectionnez des clients'
                : 'Relancer ${_selected.length} client(s)',
            icon: Icons.send_rounded,
            height: 54,
            onPressed: _selected.isEmpty ? () {} : _sendRelance,
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  HERO header
  // ============================================================
  Widget _buildHeroHeader(ThemeProvider theme, bool isDark) {
    final primary = theme.primaryColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  primary.withValues(alpha: 0.20),
                  primary.withValues(alpha: 0.06),
                ]
              : [
                  primary.withValues(alpha: 0.12),
                  primary.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primary,
                  primary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Boostez vos encaissements',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Relancez vos clients en un tap',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  Section header (avec action optionnelle)
  // ============================================================
  Widget _buildSectionHeader(
    String title, {
    required ThemeProvider theme,
    String? actionLabel,
    VoidCallback? onAction,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing != null) trailing,
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  //  Empty state mini
  // ============================================================
  Widget _buildEmptyMini(
    ThemeProvider theme, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.isDarkMode
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: theme.subTextColor.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.subTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  Champ input moderne
  // ============================================================
  InputDecoration _inputDecoration(
    ThemeProvider theme,
    bool isDark, {
    required String label,
    required IconData icon,
    String? hint,
    bool alignLabelTop = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelTop,
      labelStyle: TextStyle(
        color: theme.subTextColor.withValues(alpha: 0.9),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: theme.subTextColor.withValues(alpha: 0.5),
        fontSize: 13,
      ),
      floatingLabelStyle: TextStyle(
        color: theme.primaryColor,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 4, right: 2),
        child: Icon(
          icon,
          size: 20,
          color: theme.primaryColor.withValues(alpha: 0.7),
        ),
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.85),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
    );
  }

  // ============================================================
  //  Preset chip
  // ============================================================
  Widget _presetChip(
    String label,
    IconData icon,
    ThemeProvider theme, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: theme.primaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  Carte Auto Switch
  // ============================================================
  Widget _buildAutoSwitchCard(ThemeProvider theme, bool isDark) {
    final primary = theme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                  primary.withValues(alpha: 0.18),
                  primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relances auto',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Actives sur ${_clients.length} client${_clients.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _relanceAuto,
            onChanged: (v) => setState(() => _relanceAuto = v),
            activeTrackColor: primary,
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  Carte de statistique
  // ============================================================
  Widget _buildStatCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required Color text,
    required Color subText,
    required bool trendPositive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (trendPositive
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  trendPositive
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 12,
                  color: trendPositive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: isDark ? Colors.white : const Color(0xFF1B1B23),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white70
                  : const Color(0xFF1B1B23).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  Graphique tendance
  // ============================================================
  Widget _buildTrendChart(
      ThemeProvider theme, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tendance des paiements',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Évolution sur 8 semaines',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ce mois',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(color: primary, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  Sélecteur canal moderne
  // ============================================================
  Widget _buildChannelSelector(ThemeProvider theme, bool isDark) {
    final channels = [
      (RelanceChannel.whatsapp, 'WhatsApp', Icons.chat_rounded,
          const Color(0xFF25D366)),
      (RelanceChannel.email, 'Email', Icons.mail_outline_rounded,
          const Color(0xFFEA4335)),
      (RelanceChannel.sms, 'SMS', Icons.sms_outlined, const Color(0xFF4285F4)),
      (RelanceChannel.toast, 'Notification', Icons.notifications_none_rounded,
          const Color(0xFFF59E0B)),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: channels.map((entry) {
        final (channel, label, icon, color) = entry;
        final isSel = _channel == channel;
        return GestureDetector(
          onTap: () => setState(() => _channel = channel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSel
                  ? color.withValues(alpha: isDark ? 0.20 : 0.12)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSel
                    ? color.withValues(alpha: 0.6)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06)),
                width: isSel ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSel ? color : theme.subTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? color : theme.textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  //  Tuile client moderne
  // ============================================================
  Widget _clientTile(Client c, ThemeProvider theme, bool isDark) {
    final isSel = _selected.contains(c.id);
    final primary = theme.primaryColor;
    final initial = c.name.trim().isNotEmpty
        ? c.name.trim()[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isSel) {
                _selected.remove(c.id);
              } else {
                _selected.add(c.id);
              }
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSel
                  ? primary.withValues(alpha: isDark ? 0.12 : 0.06)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSel
                    ? primary.withValues(alpha: 0.5)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06)),
                width: isSel ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSel
                          ? [
                              primary,
                              primary.withValues(alpha: 0.75),
                            ]
                          : [
                              primary.withValues(alpha: 0.15),
                              primary.withValues(alpha: 0.06),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.email.isNotEmpty
                            ? c.email
                            : (c.phone.isNotEmpty ? c.phone : 'Sans contact'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.subTextColor,
                          fontWeight: FontWeight.w500,
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
                    color: isSel ? primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel
                          ? primary
                          : theme.subTextColor.withValues(alpha: 0.4),
                      width: 1.8,
                    ),
                  ),
                  child: isSel
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  Tuile facture moderne
  // ============================================================
  Widget _buildInvoiceTile(Invoice inv, ThemeProvider theme, bool isDark) {
    final status = inv.status;
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;
    switch (status) {
      case 'paid':
        statusColor = const Color(0xFF0F766E);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Payée';
        break;
      case 'overdue':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.warning_amber_rounded;
        statusLabel = 'En retard';
        break;
      case 'sent':
        statusColor = theme.primaryColor;
        statusIcon = Icons.visibility_rounded;
        statusLabel = 'Vue';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.description_outlined;
        statusLabel = 'Brouillon';
    }

    final clientName = inv.clientId.length > 20
        ? 'Client #${inv.clientId.substring(0, 6)}'
        : inv.clientId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${inv.invoiceNumber} • ${_formatShortDate(inv.issueDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.subTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 3),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${inv.totalAmount.toStringAsFixed(0)} F',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                    letterSpacing: -0.4,
                  ),
                ),
                if (status != 'paid')
                  Row(
                    children: [
                      _buildInvoiceAction(
                          Icons.chat_rounded, 'WhatsApp', theme, () {}),
                      const SizedBox(width: 8),
                      _buildInvoiceAction(
                          Icons.payments_outlined, 'Encaisser', theme,
                          () => _markPaid(inv)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceAction(
      IconData icon, String label, ThemeProvider theme, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: theme.primaryColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  Helpers existants (inchangés)
  // ============================================================
  String _formatK(double value) {
    final k = (value / 1000).round();
    final s = k.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
    return '$s K';
  }

  String _formatShortDate(DateTime d) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _markPaid(Invoice inv) async {
    final updated = inv.copyWith(status: 'paid', isSynced: false);
    await _db.updateInvoice(updated);
    await _loadClients();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Facture marquée payée'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendRelance() async {
    final targetClients =
        _clients.where((c) => _selected.contains(c.id)).toList();
    final msg = _message.replaceAll('{client}', '{client}');
    final result = await _relance.relanceMany(
      clients: targetClients,
      channel: _channel,
      subject: _subject,
      message: msg,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Relance envoyée : ${result.success} succès, ${result.failed} échec(s).'),
        backgroundColor: result.failed == 0 ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (result.failed > 0) {
      setState(() => _selected.clear());
    }
  }

  Invoice _placeholderInvoice() => Invoice(
        companyId: '',
        clientId: '',
        invoiceNumber: 'FA-XXXX',
        issueDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        items: const [],
        subtotal: 0,
        taxRate: 0,
        taxAmount: 0,
        totalAmount: 0,
      );

  Product _placeholderProduct() => Product(
        userId: '',
        name: 'Nouveau produit',
        price: 0,
        category: '',
      );
}

// ============================================================
//  Courbe de tendance — version épurée moderne
// ============================================================
class _TrendPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  _TrendPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const pts = [
      Offset(0.0, 0.72),
      Offset(0.14, 0.82),
      Offset(0.28, 0.60),
      Offset(0.42, 0.34),
      Offset(0.56, 0.55),
      Offset(0.70, 0.20),
      Offset(0.84, 0.42),
      Offset(1.0, 0.10),
    ];
    final w = size.width;
    final h = size.height;
    final points = pts.map((p) => Offset(p.dx * w, p.dy * h)).toList();

    // Grille horizontale
    final gridPaint = Paint()
      ..color = (isDark ? Colors.grey[800]! : Colors.grey[200]!)
          .withValues(alpha: 0.5)
      ..strokeWidth = 0.6;
    for (var i = 1; i <= 3; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Aire
    final areaPath = Path()..moveTo(points.first.dx, h);
    for (final p in points) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(points.last.dx, h);
    areaPath.close();
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(areaPath, areaPaint);

    // Courbe lissée
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      linePath.quadraticBezierTo(mid.dx, mid.dy, cur.dx, cur.dy);
    }
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Points
    final dotPaint = Paint()..color = isDark ? const Color(0xFF1E2433) : Colors.white;
    final dotBorder = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final p in points) {
      canvas.drawCircle(p, 4.5, dotPaint);
      canvas.drawCircle(p, 4.5, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}