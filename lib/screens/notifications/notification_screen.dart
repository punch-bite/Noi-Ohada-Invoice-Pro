// lib/screens/dashboard/notification_screen.dart
//
// 🔔 Écran des notifications — refonte moderne et animée.
//
// ✨ Améliorations :
//   • AppBar avec badge « non lues » dynamique
//   • TabBar avec indicateur animé
//   • Groupement des notifications par date (Aujourd'hui / Hier / …)
//   • Swipe-to-delete avec fond coloré et icône animée
//   • Carte spéciale pour invitations d'équipe (dégradé + boutons)
//   • Empty state créatif avec icône gradient
//   • Animations d'entrée en cascade (fadeIn + slideY)
//   • Pull to refresh
//
// ✅ Logique inchangée : TabController, Dismissible, markAsRead,
//    deleteNotification, _respondInvite, popup menu.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/notification.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_service.dart';
import '../../services/team_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: _buildAppBar(theme, primary),
      body: Consumer<NotificationService>(
        builder: (context, service, _) {
          final all = service.notifications;
          final unread = service.unreadNotifications;

          if (all.isEmpty) {
            return _buildEmptyState(theme, primary);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _NotificationList(
                notifications: all,
                onRefresh: service.refresh,
              ),
              _NotificationList(
                notifications: unread,
                onRefresh: service.refresh,
                emptyLabel: 'Aucune notification non lue 🎉',
              ),
            ],
          );
        },
      ),
    );
  }

  // ======================================================================
  //  APP BAR MODERNE
  // ======================================================================
  PreferredSizeWidget _buildAppBar(ThemeProvider theme, Color primary) {
    return AppBar(
      backgroundColor: theme.isDarkMode
          ? const Color(0xFF0F0F14)
          : theme.backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: theme.textColor,
        ),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/dashboard'),
      ),
      title: Row(
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 8),
          // Badge dynamique « non lues »
          Consumer<NotificationService>(
            builder: (context, service, _) {
              final count = service.unreadNotifications.length;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [_buildPopupMenu(context, theme)],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: theme.isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: theme.isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: primary,
              unselectedLabelColor: theme.subTextColor,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(height: 38, text: 'Toutes'),
                Tab(height: 38, text: 'Non lues'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, ThemeProvider theme) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: theme.textColor, size: 22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (value) {
        final service = context.read<NotificationService>();
        value == 'read'
            ? service.markAllAsRead()
            : _confirmDeleteAll(context);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'read',
          child: Row(
            children: [
              Icon(Icons.done_all_rounded,
                  size: 18, color: theme.primaryColor),
              const SizedBox(width: 10),
              const Text('Tout marquer lu'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'del',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Tout supprimer',
                  style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  // ======================================================================
  //  EMPTY STATE CRÉATIF
  // ======================================================================
  Widget _buildEmptyState(ThemeProvider theme, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withValues(alpha: 0.18),
                    primary.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 46,
                color: primary,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 24),
            Text(
              'Tout est calme',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: theme.textColor,
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 10),
            Text(
              'Vous serez prévenu ici dès que quelque chose\n'
              'de nouveau se produira.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: theme.subTextColor,
                fontWeight: FontWeight.w500,
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms)
                .slideY(begin: 0.15, end: 0),
          ],
        ),
      ),
    );
  }

  // ======================================================================
  //  CONFIRMATION SUPPRESSION
  // ======================================================================
  void _confirmDeleteAll(BuildContext context) {
    final theme = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tout supprimer ?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        content: Text(
          'Toutes vos notifications seront définitivement supprimées.',
          style: TextStyle(
            fontSize: 13.5,
            color: theme.subTextColor,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<NotificationService>().deleteAllNotifications();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  LISTE AVEC GROUPEMENT PAR DATE
// ============================================================================
class _NotificationList extends StatelessWidget {
  final List<AppNotification> notifications;
  final Future<void> Function() onRefresh;
  final String emptyLabel;

  const _NotificationList({
    required this.notifications,
    required this.onRefresh,
    this.emptyLabel = 'Aucun élément',
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: theme.primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 56,
                      color: theme.subTextColor.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      emptyLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Regroupement par jour
    final grouped = _groupByDate(notifications);
    final sections = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: theme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: sections.length,
        itemBuilder: (context, sectionIndex) {
          final section = sections[sectionIndex];
          final items = grouped[section]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de section (date)
              Padding(
                padding: EdgeInsets.only(
                  left: 4,
                  top: sectionIndex == 0 ? 4 : 20,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      section,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: theme.subTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
              // Notifications de la section
              for (var i = 0; i < items.length; i++)
                _NotificationTile(
                  notification: items[i],
                  animationIndex: i,
                ),
            ],
          );
        },
      ),
    );
  }

  /// Groupe les notifications par date lisible.
  Map<String, List<AppNotification>> _groupByDate(
      List<AppNotification> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final result = <String, List<AppNotification>>{};
    for (final n in list) {
      // Récupère la date de création si le modèle en a une
      final createdAt = _readDate(n);
      final d = createdAt == null
          ? null
          : DateTime(createdAt.year, createdAt.month, createdAt.day);

      String key;
      if (d == null) {
        key = 'PLUS TÔT';
      } else if (d == today) {
        key = "AUJOURD'HUI";
      } else if (d == yesterday) {
        key = 'HIER';
      } else if (now.difference(d).inDays < 7) {
        key = 'CETTE SEMAINE';
      } else {
        key = 'PLUS TÔT';
      }
      result.putIfAbsent(key, () => []).add(n);
    }

    // Réordonne selon l'ordre souhaité
    final orderedKeys = [
      "AUJOURD'HUI",
      'HIER',
      'CETTE SEMAINE',
      'PLUS TÔT',
    ];
    final ordered = <String, List<AppNotification>>{};
    for (final k in orderedKeys) {
      if (result.containsKey(k)) ordered[k] = result[k]!;
    }
    return ordered;
  }

  /// Essaie de lire une date de création sur la notification.
  /// Retourne null si le modèle n'expose pas `createdAt`.
  DateTime? _readDate(AppNotification n) {
    try {
      // Accès dynamique pour ne pas casser si le modèle change.
      // ignore: avoid_dynamic_calls
      final v = (n as dynamic).createdAt;
      if (v is DateTime) return v;
    } catch (_) {}
    return null;
  }
}

// ============================================================================
//  TUILE MODERNE AVEC SWIPE ANIMÉ
// ============================================================================
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final int animationIndex;

  const _NotificationTile({
    required this.notification,
    required this.animationIndex,
  });

  /// Traite une invitation d'équipe (Accepter / Refuser).
  Future<void> _respondInvite(BuildContext context, bool accept) async {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.user?.id ?? '';
    final invitationId = notification.referenceId;
    if (uid.isEmpty || invitationId == null || invitationId.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (accept) {
        await TeamService().acceptInvitation(
          invitationId: invitationId,
          requestedBy: uid,
        );
      } else {
        await TeamService().declineInvitation(
          invitationId: invitationId,
          requestedBy: uid,
        );
      }
      if (!context.mounted) return;
      final service = context.read<NotificationService>();
      await service.markAsRead(notification.id);
      await service.refresh();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                accept
                    ? Icons.celebration_rounded
                    : Icons.info_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  accept
                      ? 'Invitation acceptée ! Bienvenue dans l\'équipe 🎉'
                      : 'Invitation refusée',
                ),
              ),
            ],
          ),
          backgroundColor: accept ? Colors.green : Colors.grey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final isTeamInvite = notification.type == 'team_invite';
    final isUnread = !notification.isRead;
    final primary = theme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.redAccent.withValues(alpha: 0.9),
                Colors.redAccent,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.delete_rounded, color: Colors.white, size: 24),
              SizedBox(height: 4),
              Text(
                'Supprimer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (_) =>
            context.read<NotificationService>().deleteNotification(
                  notification.id,
                ),
        child: _buildCard(
          context,
          theme,
          isDark,
          isTeamInvite,
          isUnread,
          primary,
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 40 * animationIndex),
          duration: 320.ms,
        )
        .slideX(
          begin: 0.08,
          end: 0,
          delay: Duration(milliseconds: 40 * animationIndex),
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildCard(
    BuildContext context,
    ThemeProvider theme,
    bool isDark,
    bool isTeamInvite,
    bool isUnread,
    Color primary,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isTeamInvite
            ? (isDark
                ? primary.withValues(alpha: 0.12)
                : primary.withValues(alpha: 0.06))
            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTeamInvite
              ? primary.withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
          width: isTeamInvite ? 1.4 : 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne principale
          InkWell(
            onTap: () {
              context.read<NotificationService>().markAsRead(notification.id);
              // Redirection ici...
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône avec point « non lu »
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              notification.color,
                              notification.color.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: notification.color
                                  .withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          notification.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (isUnread)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF0F0F14)
                                    : Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Contenu
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: theme.textColor,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'NOUVEAU',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: theme.subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Boutons invitation d'équipe
          if (isTeamInvite)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _respondInvite(context, false),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary,
                            primary.withValues(alpha: 0.75),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _respondInvite(context, true),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Accepter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}