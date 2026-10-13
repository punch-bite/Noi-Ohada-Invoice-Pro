// lib/screens/customization/customization_ui.dart
//
// 🎨 KIT UI PARTAGÉ « Customization » — design system premium épuré.
//
// Toutes les surfaces du module Personnalisation (boutique, mes modèles,
// sélecteur, aperçu, checkout, atelier) puisent dans ce fichier pour
// garantir :
//   • la COHÉRENCE visuelle (une seule palette, un seul rythme 8 dp,
//     une seule échelle typographique Manrope / Work Sans) ;
//   • l'ERGONOMIE (cibles tactiles ≥ 44, feedback pressed uniforme,
//     états de chargement squelettes, états vides actionnables) ;
//   • l'ANIMATION de qualité (jetons [RoyalMotion] : 160/220/320/420 ms,
//     entrées en cascade, micro-interactions implicites).
//
// Aucune logique métier ici : uniquement présentation + interactions.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/invoice_template.dart';
import '../../theme/royal_ledger.dart';
import '../../widgets/template_thumbnail.dart';

// ═══════════════════════════════════════════════════════════════════════
//  PALETTE
// ═══════════════════════════════════════════════════════════════════════

/// Couleurs dérivées du thème « Royal Ledger » (clair / sombre automatique).
///
/// Remplace les lectures ad-hoc de `ThemeProvider` par des tokens M3
/// cohérents : `gold` est toujours l'or M3 `tertiaryFixed` (contraste
/// optimal texte foncé sur fond or), `card`/`border` suivent les rôles
/// surface, et `canvasStart/canvasEnd` teintent le fond GlassScaffold
/// dans la même famille améthyste que les cartes.
class CustomPalette {
  final bool isDark;
  final Color text;
  final Color subText;
  final Color primary;
  final Color onPrimary;
  final Color gold;
  final Color onGold;
  final Color card;
  final Color cardHigh;
  final Color border;
  final Color surface;
  final Color canvasStart;
  final Color canvasEnd;
  final Color error;
  final Color onError;

  const CustomPalette({
    required this.isDark,
    required this.text,
    required this.subText,
    required this.primary,
    required this.onPrimary,
    required this.gold,
    required this.onGold,
    required this.card,
    required this.cardHigh,
    required this.border,
    required this.surface,
    required this.canvasStart,
    required this.canvasEnd,
    required this.error,
    required this.onError,
  });

  factory CustomPalette.of(BuildContext context) {
    final c = RoyalScheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPalette(
      isDark: isDark,
      text: c.onSurface,
      subText: c.onSurfaceVariant,
      primary: c.primary,
      onPrimary: c.onPrimary,
      gold: c.tertiaryFixed,
      onGold: const Color(0xFF2A2000),
      card: c.surfaceContainer,
      cardHigh: c.surfaceContainerHigh,
      border: c.outlineVariant,
      surface: c.surface,
      canvasStart: c.surface,
      canvasEnd: isDark ? c.surfaceContainerLowest : c.surfaceContainer,
      error: c.error,
      onError: c.onError,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  SNACKBARS
// ═══════════════════════════════════════════════════════════════════════

enum CustomSnackType { success, info, error }

/// Snackbars unifiées : flottantes, coins 14, icône + message, haptique.
class CustomSnack {
  CustomSnack._();

  static void show(
    BuildContext context,
    String message, {
    CustomSnackType type = CustomSnackType.info,
    SnackBarAction? action,
  }) {
    final p = CustomPalette.of(context);
    final (Color bg, Color fg, IconData icon) = switch (type) {
      CustomSnackType.success => (
          p.primary,
          p.onPrimary,
          Icons.check_circle_rounded,
        ),
      CustomSnackType.error => (p.error, p.onError, Icons.error_outline_rounded),
      CustomSnackType.info => (p.cardHigh, p.text, Icons.info_outline_rounded),
    };

    if (type == CustomSnackType.success) HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(milliseconds: 2200),
          action: action,
        ),
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  CHAMP DE RECHERCHE
// ═══════════════════════════════════════════════════════════════════════

/// Champ de recherche épuré : hauteur 48, icône à gauche, bouton « effacer »
/// animé qui n'apparaît que si du texte est saisi.
///
/// Aucune bordure, pas même au focus : la forme **pill** et le fond tonal
/// suffisent à identifier le champ. L'état focalisé se signale par une
/// teinte légèrement plus haute, ce qui évite le contour 1px qui alourdit.
class CustomSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const CustomSearchField({
    super.key,
    required this.controller,
    this.hint = 'Rechercher un modèle…',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasText = controller.text.isNotEmpty;
        return Container(
          height: 48,
          decoration: BoxDecoration(
            // Fond tonal : le champ se lit comme un creux dans la surface.
            color: p.cardHigh,
            borderRadius: BorderRadius.circular(RoyalRadius.full),
            boxShadow: RoyalElevation.raised(p.isDark),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(color: p.text, fontSize: 14),
            cursorColor: p.primary,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: p.subText, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, color: p.subText, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              // Apparition du bouton « effacer » : transition implicite
              // (AnimatedSwitcher) plutôt qu'une animation explicite — même
              // rendu, et aucune minuterie à drainer.
              suffixIcon: AnimatedSwitcher(
                duration: RoyalMotion.fast,
                switchInCurve: RoyalMotion.emphasized,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: hasText
                    ? GestureDetector(
                        onTap: () {
                          controller.clear();
                          onChanged?.call('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: p.subText),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  RANGÉE DE FILTRES (chips)
// ═══════════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    final bg = selected ? p.primary : p.card;
    final fg = selected ? p.onPrimary : p.subText;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: RoyalMotion.base,
        curve: RoyalMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.transparent : p.border),
        ),
        child: Row(
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rangée horizontale de chips de filtre. `selected == null` marque un
/// libellé « tout sélectionner » (optionnel).
class CustomChipsRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsets padding;

  const CustomChipsRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final item in items) ...[
            _FilterChip(
              label: item,
              selected: item == selected,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(item);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  MICRO-INTERACTIONS
// ═══════════════════════════════════════════════════════════════════════

/// Enveloppe d'entrée : fondu + léger glissement vers le haut, avec un
/// `index` pour créer une cascade (stagger) naturelle dans les listes.
class EntranceFade extends StatelessWidget {
  final Widget child;
  final int index;
  final double slideOffset;

  const EntranceFade({
    super.key,
    required this.child,
    this.index = 0,
    this.slideOffset = 18,
  });

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: (index * 45).clamp(0, 400));
    return child
        .animate(delay: delay)
        .fadeIn(duration: RoyalMotion.base, curve: RoyalMotion.standard)
        .slideY(
          begin: slideOffset / 100,
          end: 0,
          duration: RoyalMotion.slow,
          curve: RoyalMotion.emphasized,
        );
  }
}

/// Carte/élément cliquable premium : scale vers le bas au press + léger
/// retour haptique, retour élastique au relâchement.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final BorderRadius? borderRadius;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.97,
    this.borderRadius,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = AnimatedScale(
      scale: _down ? widget.scaleDown : 1.0,
      duration: _down ? RoyalMotion.fast : RoyalMotion.slow,
      curve: _down ? RoyalMotion.standard : Curves.easeOutBack,
      child: widget.child,
    );
    if (widget.onTap == null && widget.onLongPress == null) return t;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        setState(() => _down = false);
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            },
      child: t,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  CHARGEMENT SQUELETTE
// ═══════════════════════════════════════════════════════════════════════

/// Bloc shimmer animé en boucle, utilisé par les écrans de chargement.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    final base = p.card;
    final highlight = p.cardHigh;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: base,
        gradient: LinearGradient(
          begin: Alignment(-1, 0),
          end: Alignment(1, 0),
          colors: [base, highlight, base],
          stops: const [0.35, 0.5, 0.65],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1100.ms, color: p.border.withValues(alpha: 0.55))
        .then()
        .fadeOut(duration: 1.ms);
  }
}

/// Squelette de grille de modèles (3 placeholders).
class TemplatesSkeleton extends StatelessWidget {
  const TemplatesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        padding: const EdgeInsets.all(8),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(height: 150, borderRadius: BorderRadius.all(Radius.circular(10))),
            Spacer(),
            ShimmerBox(width: 120, height: 13),
            SizedBox(height: 8),
            ShimmerBox(width: 70, height: 11),
          ],
        ),
      ),
    );
  }
}

/// Squelette « page A4 » : une feuille centrée aux blocs fantômes qui
/// palpitent — utilisé pendant le chargement de l'atelier / de l'aperçu.
class PaperSkeleton extends StatelessWidget {
  const PaperSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: 140, height: 20),
            const SizedBox(height: 8),
            const ShimmerBox(width: 90, height: 12),
            const SizedBox(height: 28),
            const ShimmerBox(height: 96, borderRadius: BorderRadius.all(Radius.circular(10))),
            const SizedBox(height: 28),
            const ShimmerBox(width: double.infinity, height: 12),
            const SizedBox(height: 10),
            const ShimmerBox(width: double.infinity, height: 12),
            const SizedBox(height: 10),
            const ShimmerBox(width: 180, height: 12),
            const SizedBox(height: 28),
            const ShimmerBox(width: 120, height: 44),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: RoyalMotion.base, curve: RoyalMotion.standard),
    );
  }
}

/// AppBar épurée du module : retour 48 dp, titre Manrope + sous-titre,
/// slot d'actions. Transparente pour laisser voir le fond Royal.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        tooltip: 'Retour',
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: p.text, size: 20),
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: p.text,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'WorkSans', fontSize: 11, color: p.subText),
            ),
        ],
      ),
      actions: actions,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  MINIATURE
// ═══════════════════════════════════════════════════════════════════════

/// Cadre épuré autour d'une [TemplateThumbnail] : coins arrondis et fond
/// neutre pour éviter les débordements du rendu.
///
/// Par défaut la bordure est supprimée : la séparation se fait par le fond
/// neutre (et l'ombre portée par le conteneur parent), ce qui évite le trait
/// 1px qui alourdit le rendu. Passer [border] pour en rétablir une.
///
/// [borderRadius] prend le pas sur [radius] et permet des coins asymétriques
/// (ex. [`BorderRadius.vertical(top: …)`] pour un visuel encastré, sans
/// arrondi en bas).
class TemplateThumbFrame extends StatelessWidget {
  final InvoiceTemplate template;
  final double radius;
  final Border? border;
  final BorderRadius? borderRadius;

  const TemplateThumbFrame({
    super.key,
    required this.template,
    this.radius = 12,
    this.border,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF0E0E12) : Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: TemplateThumbnail(template: template),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PASTILLES / ÉTIQUETTES
// ═══════════════════════════════════════════════════════════════════════

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  const _Pill(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de prix (or M3) pour la boutique.
class PricePill extends StatelessWidget {
  final String label;
  const PricePill(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return _Pill(
      icon: Icons.payments_rounded,
      label: label,
      bg: p.gold,
      fg: p.onGold,
    );
  }
}

/// Pastille « Déjà acquis ».
class OwnedPill extends StatelessWidget {
  final String label;
  const OwnedPill({super.key, this.label = 'Acquis'});

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return _Pill(
      icon: Icons.verified_rounded,
      label: label,
      bg: p.primary,
      fg: p.onPrimary,
    );
  }
}

/// Pastille « Modèle actif ».
class ActivePill extends StatelessWidget {
  const ActivePill({super.key});

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return _Pill(
      icon: Icons.check_circle_rounded,
      label: 'Actif',
      bg: p.primary,
      fg: p.onPrimary,
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════
//  ÉTAT VIDE
// ═══════════════════════════════════════════════════════════════════════

/// État vide actionnable : icône dans un disque teinté, titre, message et
/// bouton d'action optionnel. Remplace les écrans vides austères.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: p.isDark ? 0.22 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: p.primary),
          )
              .animate()
              .scale(
                  begin: const Offset(0.8, 0.8),
                  duration: RoyalMotion.slow,
                  curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'WorkSans',
              fontSize: 13,
              height: 1.4,
              color: p.subText,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pastille « Premium / Essentiel ».
class PremiumPill extends StatelessWidget {
  final String label;
  const PremiumPill(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = CustomPalette.of(context);
    return _Pill(
      icon: Icons.workspace_premium_rounded,
      label: label,
      bg: p.gold,
      fg: p.onGold,
    );
  }
}

