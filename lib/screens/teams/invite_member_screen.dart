// lib/screens/teams/invite_member_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_service.dart';

class InviteMemberScreen extends StatefulWidget {
  final String teamId;
  const InviteMemberScreen({super.key, required this.teamId});

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final TeamService _teamService = TeamService();
  bool _isLoading = false;
  String _role = 'member';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AppAuthProvider>();
      if (auth.user == null) throw Exception('Non connecté');

      await _teamService.inviteMember(
        teamId: widget.teamId,
        invitedBy: auth.user!.id,
        invitedEmail: _emailController.text.trim(),
        role: _role,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation envoyée !'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor ?? Colors.black;
    final subTextColor = theme.subTextColor ?? Colors.grey;
    final primaryColor = theme.primaryColor ?? Colors.blue;
    final bgColor = theme.backgroundColor ?? Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Inviter un membre'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _sendInvitation,
            child: const Text('Inviter'),
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
                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Email du membre *',
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.email, color: primaryColor),
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
                          return 'Veuillez saisir un email';
                        }
                        if (!value.contains('@')) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Rôle
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      style: TextStyle(color: textColor),
                      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                      decoration: InputDecoration(
                        labelText: 'Rôle',
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.admin_panel_settings, color: primaryColor),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'member', child: Text('Membre')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                      ],
                      onChanged: (value) => setState(() => _role = value!),
                    ),
                    const SizedBox(height: 24),

                    // Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Un email d\'invitation sera envoyé au membre. Il devra accepter pour rejoindre l\'équipe.',
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