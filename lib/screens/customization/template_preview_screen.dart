// lib/screens/customization/template_preview_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_template.dart';
import '../../models/invoice_settings.dart';
import '../../models/company.dart';
import '../../services/database_service.dart';
import '../../services/template_cart.dart';
import '../../services/template_custom_service.dart';
import '../../providers/auth_provider.dart';
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
  // 🖼️ Image téléversée du modèle : arrière-plan de l'aperçu.
  Uint8List? _backgroundBytes;
  // 🧩 Positions personnalisées (drag & drop) → l'aperçu reflète
  // les modifications faites dans l'espace de travail.
  Map<String, dynamic> _customPositions = {};

  /// Positions effectives à utiliser : les personnalisations locales si
  /// présentes, sinon les positions par défaut du modèle. Si les deux sont
  /// vides → layout fixe historique (non positionné).
  Map<String, dynamic> get _positions =>
      _customPositions.isNotEmpty
          ? _customPositions
          : Map<String, dynamic>.from(widget.template.positions);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final company = await _db.getCompany();
    // Charge les personnalisations (positions + mapping) du modèle pour
    // que l'aperçu affiche exactement ce qui a été configuré en drag & drop.
    final custom = await TemplateCustomService.loadCustom(widget.template.id);
    // Chargez également vos paramètres enregistrés s'ils existent en base de données
    // final settings = await _db.getInvoiceSettings();

    if (mounted) {
      setState(() {
        _company = company;
        _backgroundBytes = _decodeBackground();
        _customPositions = custom.positions;
        // _settings = settings ?? InvoiceSettings();
        _isLoading = false;
      });
    }
  }

  /// Décode l'image téléversée du modèle (base64) pour l'utiliser en arrière-plan.
  Uint8List? _decodeBackground() {
    if (widget.template.fileData.isEmpty ||
        widget.template.fileType == 'pdf') {
      return null;
    }
    try {
      return base64Decode(widget.template.fileData);
    } catch (_) {
      return null;
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Container principal de la facture
                        Container(
                          width: 420,
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                // 🖼️ Image téléversée du modèle en arrière-plan.
                                if (_backgroundBytes != null)
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: 0.35,
                                      child: Image.memory(
                                        _backgroundBytes!,
                                        fit: BoxFit.fill,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                // 🧩 Si l'utilisateur a personnalisé le modèle
                                // (drag & drop : positions + mapping), on rend le
                                // layout POSITIONNÉ pour refléter exactement ses
                                // modifications. Sinon → layout fixe historique.
                                if (_positions.isNotEmpty)
                                  _buildPositionedLayout()
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(24),
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
                              ],
                            ),
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
                    const SizedBox(height: 20),
                    // 🛒 Boutons d'achat / panier sous l'aperçu.
                    _buildActionButtons(theme),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  //  BOUTONS D'ACHAT / PANIER (sous l'aperçu)
  // ============================================================
  Widget _buildActionButtons(ThemeProvider theme) {
    final auth = context.watch<AppAuthProvider>();
    final currentUserId = auth.user?.id ?? '';
    final isAdmin = auth.isAdmin;
    final template = widget.template;
    final isOwned = isAdmin ||
        (currentUserId.isNotEmpty &&
            template.purchasedBy.contains(currentUserId)) ||
        template.price <= 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 💰 Prix / statut du modèle.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOwned ? Icons.check_circle : Icons.sell,
                color: isOwned ? Colors.green : template.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOwned
                      ? (template.price <= 0
                          ? 'Modèle gratuit'
                          : 'Modèle débloqué ✓')
                      : 'Prix : ${template.price.toStringAsFixed(0)} XAF',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        theme.isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isOwned)
          // Déjà possédé → accès à la personnalisation.
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openWorkspace,
              style: ElevatedButton.styleFrom(
                backgroundColor: template.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: const Text(
                'Personnaliser ce modèle',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addToCart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: template.primaryColor,
                    side: BorderSide(color: template.primaryColor),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text(
                    'Panier',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _buyNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: template.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: Text(
                    'Acheter ${template.price.toStringAsFixed(0)} XAF',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Ajoute le modèle au panier (avec retour visuel).
  void _addToCart() {
    final cart = TemplateCart.instance;
    if (cart.contains(widget.template.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Déjà dans le panier 🛒'),
          backgroundColor: Colors.orange,
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    cart.add(widget.template);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.template.name} ajouté au panier 🛒'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  /// Ajoute au panier puis redirige vers le checkout sécurisé.
  void _buyNow() {
    final cart = TemplateCart.instance;
    if (!cart.contains(widget.template.id)) {
      cart.add(widget.template);
    }
    context.push('/templates/checkout');
  }

  /// Ouvre l'espace de travail de personnalisation (drag & drop).
  void _openWorkspace() {
    context.push('/templates/workspace', extra: widget.template);
  }

  // ============================================================
  //  RENDU POSITIONNÉ (customisation drag & drop)
  //  Reflète les positions relatives (0..1), l'échelle et la visibilité
  //  choisies dans l'espace de travail, comme lors de l'impression PDF.
  // ============================================================
  Widget _buildPositionedLayout() {
    final pageW = 420.0; // largeur du conteneur d'aperçu
    final pageH = pageW * 297 / 210; // ratio A4 (~594)
    final children = <Widget>[
      // Base pleine page : donne une taille au Stack (sinon il collapserait
      // car tous ses enfants sont positionnés).
      SizedBox(width: pageW, height: pageH),
    ];

    _positions.forEach((id, raw) {
      if (raw is! Map) return;
      final visible = (raw['visible'] as bool?) ?? true;
      if (!visible) return;
      final x = ((raw['x'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
      final y = ((raw['y'] as num?) ?? 0.04).toDouble().clamp(0.0, 0.98);
      final scale = ((raw['scale'] as num?) ?? 1.0).toDouble().clamp(0.5, 2.5);

      final widget = _variableWidget(id, scale);
      if (widget == null) return;

      // Les blocs larges (tableau des lignes) ont besoin d'une largeur bornée.
      final width = id == 'items' ? (pageW - 48) * 0.92 : null;

      children.add(
        Positioned(
          left: x * pageW,
          top: y * pageH,
          child: width == null ? widget : SizedBox(width: width, child: widget),
        ),
      );
    });

    return Stack(children: children);
  }

  /// Widget Flutter d'une variable de facture (ou null si à masquer).
  /// Miroir de `printing_service._variableWidget` pour l'aperçu.
  Widget? _variableWidget(String id, double scale) {
    final template = widget.template;
    final company = _company;
    final primary = template.primaryColor;
    final text = template.textColor;
    final fs = (template.fontSize * scale).clamp(6.0, 40.0);
    final sub = text.withOpacity(0.6);

    switch (id) {
      case 'logo':
        if (!template.showLogo || company?.logoPath.isEmpty == true) return null;
        return LogoImage(
          path: company?.logoPath,
          width: 72 * scale,
          height: 72 * scale,
        );
      case 'company_name':
        return Text(
          company?.name ?? 'OHADA Invoice Pro',
          style: TextStyle(
            fontSize: 18 * scale,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        );
      case 'company_address':
        return Text(
          company?.address ?? '',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'company_phone':
        return Text(
          'Tél: ${company?.phone ?? ''}',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'company_email':
        return Text(
          'Email: ${company?.email ?? ''}',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'invoice_title':
        return Text(
          'FACTURE',
          style: TextStyle(
            fontSize: 26 * scale,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
          textAlign: TextAlign.right,
        );
      case 'client_name':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facturé à :',
              style: TextStyle(
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            Text(
              'Client SARL',
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
          ],
        );
      case 'client_address':
        return Text(
          'Douala, Cameroun',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'client_phone':
        return Text(
          'Tél: +237 6XX XX XX XX',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'client_email':
        return Text(
          'client@exemple.com',
          style: TextStyle(fontSize: fs, color: sub),
        );
      case 'items':
        return _buildItemsTable();
      case 'subtotal':
        return _totalRow('Sous-total', '100 000 FCFA', text, fs);
      case 'tax_amount':
        return _totalRow('TVA (18%)', '18 000 FCFA', text, fs);
      case 'discount':
        return _totalRow('Remise', '-0 FCFA', Colors.red, fs);
      case 'total_amount':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _totalRow(
            'TOTAL TTC',
            '118 000 FCFA',
            primary,
            16 * scale,
            bold: true,
          ),
        );
      case 'footer':
        return _buildFooter();
      case 'qr':
        if (!template.showPaymentQR) return null;
        return Text(
          '📱 Paiement Mobile Money accepté',
          style: TextStyle(fontSize: 10 * scale, color: primary),
        );
      case 'signature':
        return SizedBox(
          width: 160 * scale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 1, color: Colors.grey),
              const SizedBox(height: 4),
              Text(
                'Signature',
                style: TextStyle(fontSize: 9 * scale, color: sub),
              ),
            ],
          ),
        );
      default:
        return null;
    }
  }

  /// Ligne de total (label + valeur) pour le rendu positionné.
  Widget _totalRow(
    String label,
    String value,
    Color color,
    double fs, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fs,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fs,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
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