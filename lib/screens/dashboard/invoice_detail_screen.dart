// lib/screens/dashboard/invoice_detail_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/database_service.dart';
import '../../services/printing_service.dart';
import '../../models/invoice.dart';
import '../../models/client.dart';
import '../../models/company.dart';
import '../../models/invoice_template.dart';
import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/logo_image.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final DatabaseService _db = DatabaseService();
  Invoice? _invoice;
  Client? _client;
  Company? _company;
  bool _isLoading = true;
  InvoiceTemplate? _selectedTemplate;
  List<InvoiceTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadTemplates();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _invoice = await _db.getInvoice(widget.invoiceId);
    if (_invoice != null) {
      _client = await _db.getClient(_invoice!.clientId);
      _company = await _db.getCompany();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadTemplates() async {
    _templates = InvoiceTemplate.getDefaultTemplates();
    _selectedTemplate = _templates.firstWhere(
      (t) => t.isDefault,
      orElse: () => _templates.first,
    );
    setState(() {});
  }

  // ===== LOGO WIDGET =====
  Widget _buildCompanyLogo() {
    if (_company == null) return const SizedBox.shrink();
    return LogoImage(
      path: _company!.logoPath,
      width: 80,
      height: 80,
    );
  }

  Widget _buildPlaceholderLogo() {
    return const LogoImage(path: null, width: 80, height: 80);
  }

  // ===== EN-TÊTE AVEC LOGO =====
  Widget _buildCompanyHeader() {
    if (_company == null) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompanyLogo(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _company!.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_company!.address.isNotEmpty)
                Text(
                  _company!.address,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              if (_company!.phone.isNotEmpty)
                Text(
                  'Tél: ${_company!.phone}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              if (_company!.email.isNotEmpty)
                Text(
                  'Email: ${_company!.email}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              if (_company!.rccm.isNotEmpty)
                Text(
                  'RCCM: ${_company!.rccm}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== IMPRESSION & PARTAGE =====
  Future<void> _previewAndPrint() async {
    if (_invoice == null || _client == null || _company == null) return;
    if (_selectedTemplate == null) return;

    try {
      await PrintingService.printInvoice(
        invoice: _invoice!,
        client: _client!,
        company: _company!,
        template: _selectedTemplate!,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'impression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareInvoice() async {
    if (_invoice == null || _client == null || _company == null) return;
    if (_selectedTemplate == null) return;

    try {
      final pdfData = await PrintingService.generateInvoicePdf(
        invoice: _invoice!,
        client: _client!,
        company: _company!,
        template: _selectedTemplate!,
      );

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/facture_${_invoice!.invoiceNumber}.pdf');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Facture ${_invoice!.invoiceNumber} - OHADA Invoice Pro',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de partage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

Future<void> _sendInvoiceByEmail() async {
  if (_invoice == null || _client == null || _company == null) return;
  if (_selectedTemplate == null) return;

  try {
    // Générer le PDF
    final pdfData = await PrintingService.generateInvoicePdf(
      invoice: _invoice!,
      client: _client!,
      company: _company!,
      template: _selectedTemplate!,
    );

    // TODO: Uploader le PDF quelque part (Firebase Storage, etc.) pour obtenir un lien
    final pdfLink = '#'; // Remplacer par le vrai lien

    final htmlBody = MailService.getInvoiceTemplate(
      _client!.name,
      _invoice!.invoiceNumber,
      pdfLink,
    );

    final sent = await MailService.sendHtmlEmail(
      to: _client!.email,
      subject: 'Facture ${_invoice!.invoiceNumber}',
      htmlBody: htmlBody,
    );

    if (sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Facture envoyée par email avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'envoi de l\'email'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
    );
  }
}

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('⭐ Template Premium'),
        content: const Text(
          'Ce template est réservé aux abonnés Pro et Business.\n\n'
          'Passez à un plan supérieur pour débloquer :\n'
          '• Tous les templates premium\n'
          '• Factures illimitées\n'
          '• Synchronisation cloud\n'
          '• Support prioritaire',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Voir les offres'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final isDark = themeProvider.isDarkMode;
    final primaryColor = themeProvider.primaryColor;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;
    final cardColor = themeProvider.cardColor;
    final bgColor = themeProvider.backgroundColor;
    final canAccessPremium = subscriptionProvider.canAccessPremiumTemplates;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: isDark ? Colors.grey[400] : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Facture non trouvée',
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          _invoice!.invoiceNumber,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          // Sélection du modèle
          PopupMenuButton<InvoiceTemplate>(
            icon: Icon(Icons.style, color: textColor),
            onSelected: (template) {
              if (template.isPremium && !canAccessPremium) {
                _showUpgradeDialog(context);
                return;
              }
              setState(() => _selectedTemplate = template);
            },
            itemBuilder: (context) {
              return _templates.map((template) {
                final isLocked = template.isPremium && !canAccessPremium;
                final isSelected = _selectedTemplate?.id == template.id;

                return PopupMenuItem<InvoiceTemplate>(
                  value: isLocked ? null : template,
                  enabled: !isLocked,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: template.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          template.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isLocked ? Colors.grey : textColor,
                          ),
                        ),
                      ),
                      if (isLocked)
                        const Icon(Icons.lock, size: 16, color: Colors.grey),
                      if (isSelected && !isLocked)
                        Icon(Icons.check, color: primaryColor, size: 16),
                      if (template.isPremium && !isLocked)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child:
                              Icon(Icons.star, color: Colors.amber, size: 14),
                        ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: Icon(Icons.share, color: textColor),
            onPressed: _shareInvoice,
            tooltip: 'Partager la facture',
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: textColor),
            onPressed: _previewAndPrint,
            tooltip: 'Aperçu PDF / Impression',
          ),
          IconButton(
            icon: Icon(Icons.email_outlined, color: textColor),
            onPressed: _sendInvoiceByEmail,
            tooltip: 'Envoyer par email',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTemplatePreview(
              isDark,
              textColor,
              subTextColor,
              primaryColor,
              canAccessPremium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== EN-TÊTE AVEC LOGO =====
                  _buildCompanyHeader(),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _invoice!.invoiceNumber,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_invoice!.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusLabel(_invoice!.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Date',
                    DateFormat('dd/MM/yyyy').format(_invoice!.issueDate),
                    isDark,
                    textColor,
                    subTextColor,
                  ),
                  _buildInfoRow(
                    'Échéance',
                    DateFormat('dd/MM/yyyy').format(_invoice!.dueDate),
                    isDark,
                    textColor,
                    subTextColor,
                  ),
                  _buildInfoRow(
                    'Client',
                    _client?.name ?? 'Client inconnu',
                    isDark,
                    textColor,
                    subTextColor,
                  ),
                  const Divider(height: 24),
                  Text(
                    'Produits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._invoice!.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.description,
                                style: TextStyle(color: textColor),
                              ),
                            ),
                            Text(
                              '${item.quantity} x ',
                              style: TextStyle(color: textColor),
                            ),
                            Text(
                              '${item.unitPrice.toStringAsFixed(0)} FCFA',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${_invoice!.totalAmount.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _previewAndPrint,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Aperçu PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previewAndPrint,
                          icon: Icon(Icons.print, color: primaryColor),
                          label: Text(
                            'Imprimer',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatePreview(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primaryColor,
    bool canAccessPremium,
  ) {
    if (_selectedTemplate == null) return const SizedBox.shrink();

    final isLocked = _selectedTemplate!.isPremium && !canAccessPremium;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _selectedTemplate!.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedTemplate!.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _selectedTemplate!.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.receipt_long, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Modèle: ${_selectedTemplate!.name}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (_selectedTemplate!.isPremium) ...[
                      const SizedBox(width: 6),
                      Icon(
                        isLocked ? Icons.lock : Icons.star,
                        size: 14,
                        color: isLocked ? Colors.grey : Colors.amber,
                      ),
                    ],
                  ],
                ),
                Text(
                  _selectedTemplate!.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _selectedTemplate!.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isLocked ? '🔒 Premium' : 'Cliquez pour changer',
              style: TextStyle(
                fontSize: 10,
                color: isLocked ? Colors.grey : _selectedTemplate!.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: subTextColor)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'sent':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Payée';
      case 'sent':
        return 'En attente';
      case 'overdue':
        return 'En retard';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Brouillon';
    }
  }
}
