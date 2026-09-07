# TODO — Suite personnalisation / impression (session à reprendre)

> État au 2026-09-08 — tout l'existant est **commité** : `bc03574` (main).
> Fichiers concernés : `lib/screens/customization/template_workspace_screen.dart`,
> `lib/services/printing_service.dart`, test `test/printing_custom_layout_test.dart`.

## ✅ Fait & validé (0 erreur analyze + tests verts)
- Impression PDF personnalisée corrigée :
  - crash `borderRadius can only be given for a uniform Border` (mentions légales)
  - bandeau d'en-tête supprimé ; pied ancré en bas pleine largeur ; en-tête aligné sur la grille
  - doublons « FACTURE » et « Facturé à : » retirés ; mentions légales sans fond
- Atelier :
  - largeurs relatives de colonnes (`block_widths`) + curseur par bloc
  - couleurs par bloc fond + texte (`block_bg_colors` / `block_text_colors`), appliquées au PDF
  - TOTAL TTC transparent (plus de bandeau qui masque le texte)
  - corps transparent → image de fond visible ; aperçu rapide : contenu pleine hauteur A4
  - thème (surface claire/sombre) sur toutes les feuilles d'outils
  - colonnes d'en-tête : alignement + largeur (`header_widths` / `header_alignments` + feuille au tap)
- Test de régression : `printing_custom_layout_test.dart`

## ⏳ RESTE À FAIRE (gros refactor — à faire en SESSION DÉDIÉE avec rebuilds de validation)
### 1. Interrupteur sûr « En-tête en blocs » (`header_as_blocks`)
- Masquer le bandeau coloré (éditeur `_buildInvoiceHeader` + aperçu propre `_buildCleanInvoiceHeader`)
- Quand bandeau masqué → passer le TEXTE de l'en-tête en couleurs du thème :
  `_buildHeaderElementContent` utilise actuellement du BLANC (conçu pour le bandeau) →
  remplacer par `_onSurface` / `_onSurfaceVariant` / `_primary` selon le mode.
- Ne pas modifier le format sauvegardé tant que non validé visuellement.

### 2. Unification drag & drop en-tête = corps/pied (objectif final)
- `logo` / `company_info` / `invoice_title` deviennent des **blocs** (`_InvoiceBlock`) dans
  `_sectionsLayout`, gérés par `_initBlocks` / `_buildBlockCell` / `_buildSectionRow`.
- Éditeur : suppression du bandeau séparé (tout se glisse dans les mêmes sections/colonnes,
  même largeur/alignement/couleur par bloc).
- Aperçu propre + PDF : un seul moteur (`_workspaceBlockPdf` gère aussi logo/company_info/title ;
  plus besoin de `_workspaceHeaderRowPdf`).
- Migration des données existantes : `header_elements_order` → première section ;
  `header_widths`/`header_alignments` → `block_widths`/… ; ignorer l'ancien bandeau.
- ⚠️ Penser à exporter/sauvegarder un layout existant avant migration (test de non-régression).

## ⚠️ Notes pièges
- `flutter run -d edge` échoue sur la machine dev → validation visuelle par REBUILD côté user
  entre chaque étape.
- `get_errors` affiche des faux positifs `inline-size/block-size` (linter CSS tiers) sur
  `printing_service.dart` — utiliser `flutter analyze` comme référence.
- Chemins PDF : le refactor ne concerne QUE le chemin `blocks_sections` (atelier) ;
  layout par blocs / positionné / fixe restent inchangés.
