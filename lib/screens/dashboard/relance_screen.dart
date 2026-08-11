// lib/screens/dashboard/relance_screen.dart
//
// 📣 Écran de relance marketing (module payant) :
//  - Relance d'un client ou de plusieurs à la fois
//  - Canaux : notification toast, email, WhatsApp, SMS
//  - Messages prédéfinis (facture impayée, nouveau produit)
//
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Relance clients'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          // ===== Tableau de bord commercialisation (maquette) =====
          Text(
            'Tableau de bord',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Cartes stats : Total Envoyé / Impayés
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Total Envoyé',
                  value: _formatK(_invoices
                      .where((i) => i.status == 'sent' || i.status == 'paid')
                      .fold<double>(
                          0, (sum, i) => sum + i.totalAmount)),
                  sub: '+15% ce mois',
                  icon: Icons.send_rounded,
                  color: const Color(0xFF4338CA),
                  onDark: const Color(0xFF1B2A6B),
                  text: textColor,
                  subText: subTextColor,
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
                  onDark: const Color(0xFF7F1D1D),
                  text: textColor,
                  subText: subTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Carte Relances Auto + switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2433) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.notifications_active_rounded,
                      color: theme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relances Auto',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Actives sur ${_clients.length} clients',
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _relanceAuto,
                  onChanged: (v) => setState(() => _relanceAuto = v),
                  activeTrackColor: theme.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Graphique : Tendance des paiements
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2433) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tendance des paiements',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Ce mois',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TrendPainter(
                        color: theme.primaryColor, isDark: isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Factures récentes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Factures Récentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/dashboard/invoices'),
                child: Text(
                  'Voir tout',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_invoices.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Aucune facture pour le moment',
                  style: TextStyle(color: subTextColor),
                ),
              ),
            )
          else
            ..._invoices.take(4).map((inv) => _buildInvoiceTile(
                inv, theme, textColor, subTextColor, isDark)),
          const SizedBox(height: 24),
          // ===== Canal =====
          Text('Canal de relance', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _channelChip('WhatsApp', RelanceChannel.whatsapp, Icons.chat),
              _channelChip('Email', RelanceChannel.email, Icons.email_outlined),
              _channelChip('SMS', RelanceChannel.sms, Icons.sms_outlined),
              _channelChip('Notification', RelanceChannel.toast, Icons.notifications_none),
            ],
          ),
          const SizedBox(height: 16),

          // ===== Objet =====
          GlassTextField(
            label: 'Objet',
            controller: TextEditingController(text: _subject),
            onChanged: (v) => _subject = v,
          ),
          const SizedBox(height: 12),

          // ===== Message =====
          GlassTextField(
            label: 'Message',
            maxLines: 3,
            hint: 'Bonjour {client}, ...',
            onChanged: (v) => _message = v,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Rappel facture'),
                onPressed: () => setState(() {
                  _subject = 'Rappel de facture';
                  _message = _relance.buildInvoiceReminder(
                    // Message générique si pas de facture précise
                    _placeholderInvoice(),
                    '{client}',
                  );
                }),
              ),
              ActionChip(
                label: const Text('Nouveau produit'),
                onPressed: () => setState(() {
                  _subject = 'Nouveau produit en stock';
                  _message = 'Bonjour {client},\n\n${_relance.buildNewProductMessage(_placeholderProduct())}';
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ===== Sélection des clients =====
          Text('Clients à relancer (${_selected.length})',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _selected
                    .addAll(_clients.map((c) => c.id))),
                child: const Text('Tout sélectionner'),
              ),
              TextButton(
                onPressed: () => setState(() => _selected.clear()),
                child: const Text('Tout désélectionner'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_clients.isEmpty)
            const EmptyState(
              icon: Icons.people_outline,
              message: 'Aucun client. Créez-en d\'abord.',
            )
          else
            ..._clients.map((c) => _clientTile(c, textColor, subTextColor)),

          const SizedBox(height: 24),
          GradientButton(
            label: _selected.isEmpty
                ? 'Sélectionnez des clients'
                : 'Relancer ${_selected.length} client(s)',
            icon: Icons.send_rounded,
            onPressed: _selected.isEmpty ? () {} : _sendRelance,
          ),
        ],
      ),
    );
  }

  /// Formate un montant en « K » (ex : 12450000 → « 12 450 K »).
  String _formatK(double value) {
    final k = (value / 1000).round();
    final s = k.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');
    return '$s K';
  }

  /// Carte de statistique (fond teinté + valeur + sous-texte).
  Widget _buildStatCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required Color onDark,
    required Color text,
    required Color subText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? onDark : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white : color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : const Color(0xFF1B1B23),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF1B1B23).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  /// Tuile facture récente (badge statut + montant + actions).
  Widget _buildInvoiceTile(Invoice inv, ThemeProvider theme, Color textColor,
      Color subTextColor, bool isDark) {
    final status = inv.status;
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;
    switch (status) {
      case 'paid':
        statusColor = const Color(0xFF0F766E);
        statusIcon = Icons.check_circle;
        statusLabel = 'Payée';
        break;
      case 'overdue':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.warning_amber_rounded;
        statusLabel = 'En retard';
        break;
      case 'sent':
        statusColor = theme.primaryColor;
        statusIcon = Icons.visibility;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inv.invoiceNumber} • ${_formatShortDate(inv.issueDate)}',
                      style: TextStyle(fontSize: 11, color: subTextColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${inv.totalAmount.toStringAsFixed(0)} F',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
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
    );
  }

  Widget _buildInvoiceAction(
      IconData icon, String label, ThemeProvider theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.primaryColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
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
      ),
    );
  }

  Widget _channelChip(String label, RelanceChannel channel, IconData icon) {
    final isSel = _channel == channel;
    return FilterChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: isSel,
      onSelected: (_) => setState(() => _channel = channel),
    );
  }

  Widget _clientTile(Client c, Color text, Color sub) {
    final isSel = _selected.contains(c.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: CheckboxListTile(
        value: isSel,
        onChanged: (v) => setState(() {
          if (v == true) {
            _selected.add(c.id);
          } else {
            _selected.remove(c.id);
          }
        }),
        title: Text(c.name, style: TextStyle(color: text)),
        subtitle: Text(
          '${c.email}${c.phone.isNotEmpty ? ' • ${c.phone}' : ''}',
          style: TextStyle(color: sub, fontSize: 12),
        ),
        controlAffinity: ListTileControlAffinity.leading,
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

/// 🧮 Courbe de tendance des paiements (maquette commercialisation).
class _TrendPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  _TrendPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Points de la courbe (x, y) en coordonnées relatives 0..1
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

    // Grille horizontale pointillée
    final gridPaint = Paint()
      ..color = (isDark ? Colors.grey[700]! : Colors.grey[300]!)
          .withValues(alpha: 0.6)
      ..strokeWidth = 0.5;
    for (var i = 1; i <= 3; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Aire sous la courbe (dégradé)
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
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(areaPath, areaPaint);

    // Courbe
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
    final dotPaint = Paint()..color = Colors.white;
    final dotBorder = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 4, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}
