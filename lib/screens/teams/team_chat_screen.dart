// lib/screens/teams/team_chat_screen.dart
//
// 💬 MESSAGERIE INSTANTANÉE DE L'ÉQUIPE.
//
//   • Temps réel via Firestore (streamMessages) ;
//   • HISTORIQUE LOCAL : les messages sont persistés dans Hive
//     (TeamChatService) → affichage instantané à l'ouverture, disponible
//     hors connexion, conservé entre les sessions ;
//   • Notifications in-app pour les autres membres à chaque message.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/team_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/team_chat_service.dart';
import '../../services/team_service.dart';

class TeamChatScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamChatScreen({
    super.key,
    required this.teamId,
    this.teamName = 'Équipe',
  });

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final TeamChatService _chatService = TeamChatService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  List<TeamMessage> _messages = [];
  StreamSubscription<List<TeamMessage>>? _streamSub;
  bool _loadingCache = true;
  bool _sending = false;
  bool _streamError = false;
  String _senderName = 'Moi';
  List<String> _memberIds = const [];

  String get _currentUserId =>
      context.read<AppAuthProvider>().user?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadContext();
    _loadCacheThenStream();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  /// Charge le nom de l'expéditeur + les membres de l'équipe (pour les
  /// notifications) — best-effort, ne bloque jamais le chat.
  Future<void> _loadContext() async {
    final uid = _currentUserId;
    if (uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? const {};
      if (!mounted) return;
      setState(() {
        _senderName = (data['displayName'] ??
                data['name'] ??
                data['email'] ??
                'Moi')
            .toString();
      });
    } catch (_) {
      // Fallback silencieux : « Moi ».
    }
    try {
      final team = await TeamService().getTeam(widget.teamId);
      if (!mounted || team == null) return;
      setState(() {
        _memberIds = <String>{
          team.ownerId,
          ...team.adminIds,
          ...team.memberIds,
        }.toList();
      });
    } catch (_) {
      // Ignoré : les notifications seront simplement limitées.
    }
  }

  /// 1) Affiche IMMÉDIATEMENT l'historique local (Hive) — même hors connexion.
  /// 2) Branche ensuite le flux temps réel Firestore (qui re-cache tout).
  Future<void> _loadCacheThenStream() async {
    final cached = await _chatService.getCachedMessages(widget.teamId);
    if (!mounted) return;
    setState(() {
      _messages = cached;
      _loadingCache = false;
    });
    _scrollToBottom();

    _streamSub?.cancel();
    _streamSub = _chatService.streamMessages(widget.teamId).listen(
      (messages) {
        if (!mounted) return;
        setState(() {
          _messages = messages;
          _streamError = false;
        });
        _scrollToBottom();
      },
      onError: _onStreamError,
    );
  }

  void _onStreamError(Object error) {
    debugPrint('⚠️ TeamChat stream: $error');
    if (!mounted) return;
    setState(() => _streamError = true);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending || _currentUserId.isEmpty) return;
    setState(() => _sending = true);
    _inputController.clear();
    try {
      await _chatService.sendMessage(
        teamId: widget.teamId,
        senderId: _currentUserId,
        senderName: _senderName,
        text: text,
        memberIds: _memberIds,
      );
      _scrollToBottom();
      _inputFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_pretty(e)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _pretty(Object error) {
    var message = error.toString();
    if (message.startsWith('Exception: ')) message = message.substring(11);
    return message;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _membersLabel() {
    final count = _memberIds.length;
    return count <= 1 ? 'Vous êtes seul' : '$count membres';
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final textColor = theme.textColor;
    final subTextColor = theme.subTextColor;
    final bgColor = theme.backgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            _teamAvatar(theme),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _streamError
                              ? Colors.orange
                              : const Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _streamError
                              ? 'Hors ligne · historique local'
                              : _membersLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: subTextColor, fontSize: 11),
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
      body: SafeArea(
        child: Column(
          children: [
            if (_streamError) _streamErrorBanner(theme),
            Expanded(
              child: _loadingCache
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _emptyState(theme)
                      : _buildMessagesList(theme, isDark),
            ),
            _buildInputBar(theme, isDark),
          ],
        ),
      ),
    );
  }

  /// Bandeau d'information quand le flux distant est indisponible
  /// (règles serveur / réseau) — l'historique local reste consultable.
  Widget _streamErrorBanner(ThemeProvider theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Messagerie distante indisponible — historique local affiché.',
              style: TextStyle(fontSize: 11.5, color: theme.textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined,
              size: 60, color: theme.primaryColor.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(
            'Aucun message',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Lancez la discussion avec votre équipe !',
            style: TextStyle(fontSize: 12.5, color: theme.subTextColor),
          ),
        ],
      ),
    );
  }

  /// Liste inversée : du plus récent (haut) au plus ancien — l'auto-scroll
  /// est donc gratuit via le ScrollController.
  Widget _buildMessagesList(ThemeProvider theme, bool isDark) {
    final reversed = _messages.reversed.toList();
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final message = reversed[i];
        final previous = i + 1 < reversed.length ? reversed[i + 1] : null;
        final showDayDivider = previous == null ||
            previous.createdAt.day != message.createdAt.day ||
            previous.createdAt.month != message.createdAt.month ||
            previous.createdAt.year != message.createdAt.year;
        return Column(
          children: [
            if (showDayDivider) _dayDivider(message.createdAt, theme),
            _bubble(message, theme, isDark),
          ],
        );
      },
    );
  }

  Widget _dayDivider(DateTime date, ThemeProvider theme) {
    const days = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
    ];
    final label =
        '${days[date.weekday - 1]} ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: theme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }

// ── Bulle de message ────────────────────────────────────────────────────
  Widget _bubble(TeamMessage message, ThemeProvider theme, bool isDark) {
    final mine = message.senderId == _currentUserId;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );
    final maxWidth = MediaQuery.of(context).size.width * 0.74;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          gradient: mine
              ? LinearGradient(
                  colors: [theme.primaryColor, theme.gradientEndColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: mine ? null : (isDark ? const Color(0xFF23263A) : const Color(0xFFF0F1F7)),
          borderRadius: radius,
          border: mine
              ? null
              : Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.12),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: mine ? Colors.white : theme.textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 9.5,
                color: mine
                    ? Colors.white.withValues(alpha: 0.75)
                    : theme.subTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _teamAvatar(ThemeProvider theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.gradientEndColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          widget.teamName.isNotEmpty ? widget.teamName[0].toUpperCase() : 'E',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ── Barre de saisie ─────────────────────────────────────────────────────
  Widget _buildInputBar(ThemeProvider theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF151722).withValues(alpha: 0.97)
            : Colors.white.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: theme.primaryColor.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: isDark ? 0.10 : 0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.18),
                ),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: TextStyle(fontSize: 13.5, color: theme.textColor),
                decoration: InputDecoration(
                  hintText: 'Écrivez un message…',
                  hintStyle:
                      TextStyle(fontSize: 13, color: theme.subTextColor),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.gradientEndColor],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _sending ? Icons.hourglass_top : Icons.send_rounded,
                size: 20,
                color: Colors.white,
              ),
              onPressed: _sending ? null : _sendMessage,
              tooltip: 'Envoyer',
            ),
          ),
        ],
      ),
    );
  }
}