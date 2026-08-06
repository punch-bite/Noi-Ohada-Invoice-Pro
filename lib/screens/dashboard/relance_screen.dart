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
      final clients = await _db.getClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          '${c.email ?? ''}${c.phone.isNotEmpty ? ' • ${c.phone}' : ''}',
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
