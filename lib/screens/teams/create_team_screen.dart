// lib/screens/teams/create_team_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_service.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TeamService _teamService = TeamService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate()) return;

    // 🔒 Équipe = fonctionnalité premium : bloquée pour les utilisateurs
    // gratuits (le routeur redirige aussi /teams/create → /subscription).
    final sub = context.read<SubscriptionProvider>();
    if (!sub.hasTeamAccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La gestion d\'équipe est réservée aux abonnés premium',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      context.push('/subscription');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AppAuthProvider>();
      if (auth.user == null) {
        throw Exception('Utilisateur non connecté');
      }

      await _teamService.createTeam(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        ownerId: auth.user!.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Équipe créée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final primaryColor = theme.primaryColor;
    final bgColor = theme.backgroundColor;
    final hasTeamAccess = context.watch<SubscriptionProvider>().hasTeamAccess;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Créer une équipe'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: (_isLoading || !hasTeamAccess) ? null : _createTeam,
            child: const Text('Créer'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 🔒 Verrou premium : l'équipe n'est pas dispo en gratuit.
                    if (!hasTeamAccess) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9B949).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE9B949).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.lock_outline,
                                    color: Color(0xFFB8860B), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Fonctionnalité premium',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF7A5A00),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'La gestion d\'équipe est réservée aux abonnés premium. '
                              'Passez à un plan payant pour créer et gérer vos équipes.',
                              style: TextStyle(fontSize: 12.5, color: subTextColor),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/subscription'),
                                icon: const Icon(Icons.workspace_premium, size: 18),
                                label: const Text('Débloquer l\'équipe'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Icône
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.groups,
                        size: 40,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nom
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Nom de l\'équipe *',
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.group, color: primaryColor),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir un nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Description (optionnel)',
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.description, color: primaryColor),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vous serez le propriétaire de cette équipe et pourrez gérer les membres et les permissions.',
                              style: TextStyle(
                                fontSize: 13,
                                color: subTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}