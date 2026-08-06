// lib/screens/dashboard/drive_sync_screen.dart
// ============================================================
//  ☁️ Synchronisation Google Drive (module Business).
//  - Vérifie l'accès Business (hasGoogleDriveSync)
//  - Connecte le compte Google de l'utilisateur (liaison par email)
//  - Synchronise un backup JSON vers son Drive
// ============================================================
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/google_drive_sync_service.dart';
import '../../widgets/glass_widgets.dart';

class DriveSyncScreen extends StatefulWidget {
  const DriveSyncScreen({super.key});

  @override
  State<DriveSyncScreen> createState() => _DriveSyncScreenState();
}

class _DriveSyncScreenState extends State<DriveSyncScreen> {
  final GoogleDriveSyncService _service = GoogleDriveSyncService();
  bool _loading = true;
  bool _syncing = false;
  bool _connected = false;
  String? _googleEmail;
  String? _lastSyncLabel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = await _service.getSyncState();
    _googleEmail = _service.connectedGoogleEmail ?? state?['email'];
    _connected = _googleEmail?.isNotEmpty ?? false;
    final lastSync = state?['lastSyncAt'];
    if (lastSync != null) {
      _lastSyncLabel = _formatTimestamp(lastSync);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '—';
  }

  Future<void> _connect() async {
    try {
      final account = await _service.signInWithGoogle();
      if (account == null) return;
      final error = await _service.validateEmailBinding();
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.orange),
        );
        return;
      }
      setState(() {
        _connected = true;
        _googleEmail = account.email;
      });
      await _service.saveSyncState(enabled: true, email: account.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Compte Google connecté'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      if (!_connected) {
        final account = await _service.signInWithGoogle();
        if (account == null) {
          if (mounted) setState(() => _syncing = false);
          return;
        }
        final error = await _service.validateEmailBinding();
        if (error != null) {
          if (!mounted) return;
          setState(() => _syncing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.orange),
          );
          return;
        }
        setState(() {
          _connected = true;
          _googleEmail = account.email;
        });
      }
      await _service.uploadBackupToDrive();
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _lastSyncLabel = 'À l\'instant';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Données synchronisées vers Google Drive'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec de la synchronisation : $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _service.signOut();
    await _service.saveSyncState(enabled: false, email: '');
    if (!mounted) return;
    setState(() {
      _connected = false;
      _googleEmail = null;
      _lastSyncLabel = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compte Google déconnecté'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final hasAccess = sub.hasGoogleDriveSync;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          'Sauvegarde Google Drive',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: theme.textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.textColor, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: !hasAccess ? _buildLocked(theme) : _buildContent(theme),
              ),
      ),
    );
  }

  Widget _buildLocked(ThemeProvider theme) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_upload_rounded,
              color: Colors.white, size: 52),
        ),
        const SizedBox(height: 28),
        Text(
          'Fonctionnalité Business',
          style: TextStyle(
            color: theme.textColor,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Synchronisez automatiquement vos factures, clients et produits '
          'vers votre Google Drive personnel. Disponible avec le plan '
          'Business.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.subTextColor, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),
        GradientButton(
          label: 'Passer au plan Business',
          icon: Icons.workspace_premium_rounded,
          onPressed: () => context.push('/subscription'),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cloud_done_rounded,
                        color: Color(0xFF16A34A), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connected ? 'Compte connecté' : 'Non connecté',
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _googleEmail ?? 'Connectez votre compte Google',
                          style: TextStyle(
                            color: theme.subTextColor,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_connected)
                    IconButton(
                      tooltip: 'Déconnecter',
                      icon: Icon(Icons.logout_rounded,
                          color: theme.subTextColor),
                      onPressed: _disconnect,
                    ),
                ],
              ),
              const Divider(height: 24),
              _infoRow(theme, 'Dernière synchronisation',
                  _lastSyncLabel ?? 'Jamais'),
              const Divider(height: 16),
              _infoRow(theme, 'Dossier cible',
                  'OHADA Invoice Pro / back-ups'),
              const Divider(height: 16),
              _infoRow(theme, 'Email de liaison', _googleEmail ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: _connected ? 'Synchroniser maintenant' : 'Connecter mon Google Drive',
          icon: _connected ? Icons.sync_rounded : Icons.link_rounded,
          loading: _syncing,
          onPressed: _connected ? _syncNow : _connect,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: theme.subTextColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Vos données sont envoyées uniquement vers votre Drive.',
                style: TextStyle(color: theme.subTextColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(ThemeProvider theme, String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: theme.subTextColor, fontSize: 13),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
