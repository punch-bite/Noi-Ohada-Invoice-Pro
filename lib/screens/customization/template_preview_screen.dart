// lib/screens/customization/template_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../models/company.dart';
import '../../services/database_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/logo_image.dart';

class TemplatePreviewScreen extends StatefulWidget {
  final InvoiceTemplate template;
  const TemplatePreviewScreen({super.key, required this.template});

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  final DatabaseService _db = DatabaseService();
  Company? _company;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    final company = await _db.getCompany();
    setState(() {
      _company = company;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final bg = isDark ? Colors.grey[900] : Colors.grey[50];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Aperçu - ${widget.template.name}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: widget.template.primaryColor),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modèle sélectionné'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: widget.template.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const Divider(height: 24),
                      _buildClientSection(),
                      const SizedBox(height: 16),
                      _buildItemsTable(),
                      const SizedBox(height: 16),
                      _buildTotals(),
                      const SizedBox(height: 16),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final template = widget.template;
    final company = _company;
    final textColor = template.textColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LogoImage(
          path: company?.logoPath,
          width: 56,
          height: 56,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company?.name ?? 'OHADA Invoice Pro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: template.primaryColor,
                ),
              ),
              if (company?.address.isNotEmpty == true)
                Text(
                  company!.address,
                  style: TextStyle(
                      fontSize: 12, color: textColor.withOpacity(0.7)),
                ),
              if (company?.phone.isNotEmpty == true)
                Text(
                  'Tél: ${company!.phone}',
                  style: TextStyle(
                      fontSize: 11, color: textColor.withOpacity(0.6)),
                ),
              if (company?.email.isNotEmpty == true)
                Text(
                  'Email: ${company!.email}',
                  style: TextStyle(
                      fontSize: 11, color: textColor.withOpacity(0.6)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: template.primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'FACTURE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientSection() {
    final textColor = widget.template.textColor;
    final primaryColor = widget.template.primaryColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: primaryColor.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Facturé à :',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text('Client SARL', style: TextStyle(color: textColor)),
          Text('Douala, Cameroun',
              style:
                  TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
          Text('Tél: +237 6XX XX XX XX',
              style:
                  TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    final template = widget.template;
    final textColor = template.textColor;
    final primaryColor = template.primaryColor;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primaryColor.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Désignation',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12))),
                Expanded(
                    child: Text('Qté',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text('Prix',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        textAlign: TextAlign.right)),
                Expanded(
                    child: Text('Total',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          ..._sampleItems.map((item) => Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text(item['name']!,
                            style: TextStyle(fontSize: 12, color: textColor))),
                    Expanded(
                        child: Text(item['qty']!,
                            style: TextStyle(fontSize: 12, color: textColor),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text(item['price']!,
                            style: TextStyle(fontSize: 12, color: textColor),
                            textAlign: TextAlign.right)),
                    Expanded(
                        child: Text(item['total']!,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor),
                            textAlign: TextAlign.right)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    final template = widget.template;
    final textColor = template.textColor;
    final primaryColor = template.primaryColor;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Sous-total: 100 000 FCFA',
                style: TextStyle(fontSize: 12, color: textColor)),
            Text('TVA (18%): 18 000 FCFA',
                style: TextStyle(fontSize: 12, color: textColor)),
            const Divider(height: 6),
            Text(
              'TOTAL TTC: 118 000 FCFA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final template = widget.template;
    final textColor = template.textColor;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: template.primaryColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _company?.legalText ?? 'Conforme aux normes OHADA et SYSCOHADA',
        style: TextStyle(
          fontSize: 10,
          color: textColor.withOpacity(0.6),
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  final List<Map<String, String>> _sampleItems = [
    {
      'name': 'Service de consultation',
      'qty': '2',
      'price': '25 000 FCFA',
      'total': '50 000 FCFA'
    },
    {
      'name': 'Développement web',
      'qty': '1',
      'price': '30 000 FCFA',
      'total': '30 000 FCFA'
    },
    {
      'name': 'Hébergement annuel',
      'qty': '1',
      'price': '20 000 FCFA',
      'total': '20 000 FCFA'
    },
  ];
}
