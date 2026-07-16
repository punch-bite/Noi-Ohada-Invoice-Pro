// lib/screens/customization/template_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../models/invoice_settings.dart';
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
  final InvoiceSettings _settings = InvoiceSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    // Chargez également vos paramètres enregistrés s'ils existent en base de données
    // final settings = await _db.getInvoiceSettings();
    
    if (mounted) {
      setState(() {
        _company = company;
        // _settings = settings ?? InvoiceSettings();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final bg = isDark ? Colors.grey[950] : Colors.grey[100];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Aperçu - ${widget.template.name}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check_circle_outline, color: widget.template.primaryColor, size: 26),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modèle configuré avec succès'),
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
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Container principal de la facture
                    Container(
                      width: 420,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: widget.template.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: _settings.showBorder
                            ? Border.all(
                                color: widget.template.primaryColor.withOpacity(0.35),
                                width: 1.5,
                              )
                            : Border.all(
                                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const Divider(height: 24, thickness: 1),
                          if (_settings.showClientInfo) ...[
                            _buildClientSection(),
                            const SizedBox(height: 16),
                          ],
                          _buildItemsTable(),
                          const SizedBox(height: 16),
                          _buildTotalsAndQR(),
                          const SizedBox(height: 16),
                          _buildFooter(),
                        ],
                      ),
                    ),
                    
                    // Filigrane (Watermark) optionnel
                    if (_settings.showWatermark)
                      IgnorePointer(
                        child: Transform.rotate(
                          angle: -0.35,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: widget.template.primaryColor.withOpacity(0.12),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _settings.watermarkText.toUpperCase(),
                              style: TextStyle(
                                color: widget.template.primaryColor.withOpacity(0.09),
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
        if (_settings.showLogo) ...[
          LogoImage(
            path: company?.logoPath,
            width: 52,
            height: 52,
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company?.name ?? 'OHADA Invoice Pro',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: template.primaryColor,
                ),
              ),
              if (_settings.showCompanyInfo) ...[
                const SizedBox(height: 4),
                if (company?.address.isNotEmpty == true)
                  Text(
                    company!.address,
                    style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7)),
                  ),
                if (company?.phone.isNotEmpty == true)
                  Text(
                    'Tél: ${company!.phone}',
                    style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                  ),
                if (company?.email.isNotEmpty == true)
                  Text(
                    'Email: ${company!.email}',
                    style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: template.primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'FACTURE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
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
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.04),
        border: Border.all(color: primaryColor.withOpacity(0.15)),
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
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Client SARL', 
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            'Douala, Cameroun',
            style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
          ),
          Text(
            'Tél: +237 6XX XX XX XX',
            style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
          ),
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
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Désignation',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Qté',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Prix',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          ..._sampleItems.map((item) => Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: primaryColor.withOpacity(0.1),
                      width: _sampleItems.last == item ? 0 : 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['name']!,
                        style: TextStyle(fontSize: 11, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['qty']!,
                        style: TextStyle(fontSize: 11, color: textColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['price']!,
                        style: TextStyle(fontSize: 11, color: textColor),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['total']!,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTotalsAndQR() {
    final template = widget.template;
    final textColor = template.textColor;
    final primaryColor = template.primaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intégration du code QR de paiement
        if (_settings.showPaymentQR)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: primaryColor.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded, 
              size: 64, 
              color: textColor.withOpacity(0.8),
            ),
          )
        else
          const Spacer(),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sous-total:', style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7))),
                    Text('100 000 FCFA', style: TextStyle(fontSize: 11, color: textColor)),
                  ],
                ),
                if (_settings.showTaxDetails) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TVA (18%):', style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7))),
                      Text('18 000 FCFA', style: TextStyle(fontSize: 11, color: textColor)),
                    ],
                  ),
                ],
                const Divider(height: 8, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL TTC:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    Text(
                      _settings.showTaxDetails ? '118 000 FCFA' : '100 000 FCFA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final template = widget.template;
    final textColor = template.textColor;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: template.primaryColor.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _company?.legalText ?? 'Conforme aux normes OHADA et SYSCOHADA',
            style: TextStyle(
              fontSize: 9,
              color: textColor.withOpacity(0.55),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (_settings.showPaymentTerms) ...[
          const SizedBox(height: 8),
          Text(
            'Conditions de règlement : Paiement à réception.',
            style: TextStyle(
              fontSize: 8.5, 
              color: textColor.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ]
      ],
    );
  }

  final List<Map<String, String>> _sampleItems = [
    {
      'name': 'Consultation & Audit',
      'qty': '2',
      'price': '25 000 FCFA',
      'total': '50 000 FCFA'
    },
    {
      'name': 'Développement Application',
      'qty': '1',
      'price': '30 000 FCFA',
      'total': '30 000 FCFA'
    },
    {
      'name': 'Maintenance mensuelle',
      'qty': '1',
      'price': '20 000 FCFA',
      'total': '20 000 FCFA'
    },
  ];
}