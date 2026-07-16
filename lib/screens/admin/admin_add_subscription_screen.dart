// lib/screens/admin/admin_add_subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_service.dart';
import '../../services/subscription_service.dart';
import '../../models/user.dart';
import '../../models/plan.dart';

class AdminAddSubscriptionScreen extends StatefulWidget {
  final String? userId; // optionnel, si on vient du détail d'un utilisateur
  const AdminAddSubscriptionScreen({super.key, this.userId});

  @override
  State<AdminAddSubscriptionScreen> createState() =>
      _AdminAddSubscriptionScreenState();
}

class _AdminAddSubscriptionScreenState
    extends State<AdminAddSubscriptionScreen> {
  final AdminService _adminService = AdminService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  List<AppUser> _users = [];
  List<Plan> _plans = [];
  AppUser? _selectedUser;
  Plan? _selectedPlan;
  String _paymentMethod = 'orange_money';
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final loadedUsers = await _adminService.getAllUsers();
      final loadedPlans = await _subscriptionService.getPlans();

      if (mounted) {
        setState(() {
          _users = loadedUsers;
          _plans = loadedPlans;

          if (widget.userId != null && _users.isNotEmpty) {
            // Recherche sécurisée de l'utilisateur concerné
            final index = _users.indexWhere((u) => u.id == widget.userId);
            _selectedUser = index != -1 ? _users[index] : _users.first;
          } else if (_users.isNotEmpty) {
            _selectedUser = _users.first;
          }

          if (_plans.isNotEmpty) {
            _selectedPlan = _plans.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des données: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedUser == null || _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un utilisateur et un plan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _adminService.createSubscriptionForUser(
        userId: _selectedUser!.id,
        planId: _selectedPlan!.id,
        paymentMethod: _paymentMethod,
        amount: _selectedPlan!.price,
        currency: _selectedPlan!.currency,
        interval: _selectedPlan!.interval,
        durationMonths: 1,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Abonnement créé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      
      if (mounted) {
        navigator.pop(true);
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur d\'enregistrement: $e'), 
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final bgColor = theme.backgroundColor;
    final cardColor = theme.cardColor;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Ajouter un abonnement',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Utilisateur Dropdown
                    _buildLabel('Utilisateur *', textColor),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<AppUser>(
                      initialValue: _selectedUser,
                      isExpanded: true,
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor, fontSize: 15),
                      decoration: _buildInputDecoration(cardColor, isDark),
                      items: _users.map((u) {
                        return DropdownMenuItem<AppUser>(
                          value: u,
                          child: Text(
                            u.displayName.isNotEmpty ? u.displayName : 'Sans nom (${u.email})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _isSubmitting ? null : (v) => setState(() => _selectedUser = v),
                    ),
                    const SizedBox(height: 20),

                    // Plan Dropdown
                    _buildLabel('Plan d\'abonnement *', textColor),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Plan>(
                      initialValue: _selectedPlan,
                      isExpanded: true,
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor, fontSize: 15),
                      decoration: _buildInputDecoration(cardColor, isDark),
                      items: _plans.map((p) {
                        return DropdownMenuItem<Plan>(
                          value: p,
                          child: Text('${p.name} - ${p.getFormattedPrice()}'),
                        );
                      }).toList(),
                      onChanged: _isSubmitting ? null : (v) => setState(() => _selectedPlan = v),
                    ),
                    const SizedBox(height: 20),

                    // Méthode de paiement Dropdown
                    _buildLabel('Mode de règlement', textColor),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      isExpanded: true,
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor, fontSize: 15),
                      decoration: _buildInputDecoration(cardColor, isDark),
                      items: const [
                        DropdownMenuItem(value: 'orange_money', child: Text('Orange Money')),
                        DropdownMenuItem(value: 'mtn_money', child: Text('MTN Mobile Money')),
                        DropdownMenuItem(value: 'wave', child: Text('Wave')),
                        DropdownMenuItem(value: 'stripe', child: Text('Carte bancaire (Stripe)')),
                        DropdownMenuItem(value: 'cash', child: Text('Espèces / Manuel')),
                      ],
                      onChanged: _isSubmitting ? null : (v) => setState(() => _paymentMethod = v!),
                    ),
                    const SizedBox(height: 28),

                    // Résumé Récapitulatif
                    _buildLabel('Récapitulatif de la transaction', textColor),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Bénéficiaire', _selectedUser?.displayName ?? 'Non sélectionné', textColor, subTextColor),
                          const Divider(height: 20, thickness: 0.5),
                          _buildSummaryRow('Formule d\'accès', _selectedPlan?.name ?? 'Non sélectionné', textColor, subTextColor),
                          const Divider(height: 20, thickness: 0.5),
                          _buildSummaryRow(
                            'Montant à facturer',
                            _selectedPlan?.getFormattedPrice() ?? '0 FCFA',
                            primaryColor,
                            subTextColor,
                            isPrice: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Bouton de validation
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Enregistrer l\'abonnement',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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

  Widget _buildLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(Color cardColor, bool isDark) {
    return InputDecoration(
      fillColor: cardColor,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor, Color labelColor, {bool isPrice = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: labelColor, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isPrice ? 15 : 14,
            fontWeight: isPrice ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}