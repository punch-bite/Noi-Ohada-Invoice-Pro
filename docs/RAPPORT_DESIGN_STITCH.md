# 🎨 Rapport de Design — NOI OHADA Invoice Pro
### Pour recréation / refonte UI avec [Google Stitch](https://stitch.withgoogle.com)

> Application SaaS de **facturation conforme aux normes OHADA / SYSCOHADA** pour les PME d'Afrique francophone.
> Stack : Flutter (Material 3) · Firestore · Provider · go_router · Paiement E-nkap (Orange Money / MTN / Carte).

Ce rapport décrit **chaque écran** (structure, composants, contenu, couleurs) pour que vous puissiez générer de nouvelles maquettes avec Google Stitch — soit par **prompt textuel** (copiez les descriptions), soit par **image de référence** (captures de l'app actuelle).

---

## 1. Design System (à réutiliser partout)

### 1.1 Palette de couleurs

| Rôle | Clair | Sombre | Usage |
|---|---|---|---|
| **Primaire (indigo)** | `#4338CA` | `#7C6CF0` | CTA, sélections, icônes, liens |
| **Fin de dégradé (violet)** | `#7C3AED` | `#9A7BFF` | Dégradés `#4338CA → #7C3AED` |
| **Accent or / premium** | `#E9B949` | `#E9B949` | Badges PREMIUM, marketing, highlights |
| **Fond app** | `#F6F7FB` | `#0E1117` | Fond global |
| **Fond glass / surfaces** | blanc `0.75→0.4` | `#161B26` / `#1E2433` | Cartes translucides |
| **Texte principal** | `#14161C` | blanc | Titres et corps |
| **Texte secondaire** | `#5A5F6B` / gris | `grey[500]` | Sous-titres, labels |
| **Succès / payé** | vert `#16A34A` / `#4CAF50` | idem | Statuts, crédits |
| **Alerte / en retard** | rouge `#EF4444` / `#F44336` | idem | Dangers, impayés |
| **Attention / en attente** | orange `#FF9800` | idem | Statuts intermédiaires |
| **Cyan (équipe)** | `#06B6D4` | idem | Module Équipe |
| **Landing (fond)** | `#F6F7FB` | `#0B0D17` | Page marketing |

### 1.2 Typographie
- **Police : Roboto** (embarquée, hors-ligne).
- Titres : `w800`, `letterSpacing -0.5`, tailles 28–34.
- Titres d'écran : `w600–w700`, 18–22.
- Corps : 13–15, `w400–w500`.
- Labels/utilitaires : 9–12, parfois `w700` + MAJUSCULES + lettrage.

### 1.3 Composants transversaux (briques réutilisées)

- **`GlassScaffold`** — fond plein écran en dégradé diagonal (clair : `#EDE9FE → #FDF2F8` ; sombre : `#0B0D17 → #1E2433`) + **2 halos lumineux** (radial, haut-droite indigo + bas-gauche rose/violet), blur léger, barres système transparentes.
- **`GradientButton`** — bouton pleine largeur h~50-54, **dégradé `#4338CA → #7C3AED`** (clair) / `#7C6CF0→#9A7BFF` (sombre), rayon 14, ombre portée couleur dégradé, icône + texte blanc `w700`, spinner blanc si chargement.
- **`GlassCard`** — carte translucide (blanc 0.75→0.4), rayon 20, bordure blanche 0.6, **liseré lumineux en haut**, ombre douce.
- **`GlassBadge`** — pilule en dégradé de la couleur d'accent (défaut or), texte blanc 11 `w700`, icône optionnelle.
- **`GlassTextField`** — champ translucide, bordure quasi invisible, focus = bordure primaire.
- **Badge PREMIUM** — fond or `#E9B949` @0.18, bordure 0.5, étoile + texte `PREMIUM` brun `#B8860B`.
- **Badges de statut** — fond teinté (couleur @0.10–0.15) + texte de la couleur : Payée = vert, En attente = orange, En retard = rouge, Annulée = gris, Brouillon = gris.

### 1.4 Deux familles de style (à reproduire pour la fidélité)
1. **Écrans « glass premium »** (`GlassScaffold` + dégradés indigo/violet, halos, liserés) : *création facture, création produit, détail facture, paramètres, boutique de modèles, auth.*
2. **Écrans « classiques Material »** (AppBar blanche, `cardColor`, FAB) : *listes factures, clients, produits, fournisseurs, support, plans, sécurité.*

---

## 2. Écrans d'authentification

### 2.1 Connexion — `login_screen.dart`
- **Layout** : plein écran, centré verticalement, scroll simple, fond `bgColor`. Pas de carte.
- **Composants** : logo circulaire 76px (dégradé primaire→secondaire + halo) + icône `receipt_long` · titre « OHADA Invoice Pro » (22 bold) · sous-titre « Facturation conforme SYSCOHADA » (13 gris) · **champ Email** (icône `email_outlined` primaire, fond `cardColor`, rayon 12) · **champ Mot de passe** (toggle œil, hint `••••••••`) · checkbox « Se souvenir » + lien « Mot de passe oublié ? » · bannière d'erreur rouge · `GradientButton` « Se connecter » (h52) · séparateur « ou » · **bouton Google** (bordure grise, logo G bleu `#4285F4`) · lien « Pas encore de compte ? / S'inscrire ».
- **Animations** : logo `.scale` easeOutBack, boutons `.fadeIn`.

### 2.2 Inscription — `register_screen.dart`
- **Layout** : centré **dans une carte** (rayon 20, bordure 1px gris).
- **Composants** : badge circulaire 66px (`person_add_alt_1`) · titre « Créer un compte » · sous-titre « Rejoignez NOI OHADA Invoice Pro » · **4 champs** (Nom complet, Email, Mot de passe, Confirmer) avec icônes préfixées et remplissage `grey[50]`/`black26` · **checkbox CGU** · bannière erreur · `GradientButton` « Créer mon compte » · lien « Déjà un compte ? / Se connecter ».

### 2.3 Mot de passe oublié — `forgot_password_screen.dart`
- **Layout** : carte centrée (rayon 20), **2 vues** : formulaire / succès.
- **Formulaire** : icône `lock_reset` 64px dégradé + halo · titre « Mot de passe oublié ? » · **1 champ Email** · `GradientButton` « Envoyer le lien » · « Retour à la connexion ».
- **Succès** : cercle vert (`mark_email_read_outlined`), « Email envoyé ! », bouton retour.

### 2.4 Double authentification (2FA) — `verify_2fa_screen.dart`
- **Layout** : AppBar transparente + flèche retour, corps centré dans une carte.
- **Composants** : icône `security` 64px dégradé + halo · « Double authentification » · texte explicatif OTP · **grille de 6 champs OTP** (42×52, police 20 bold, fond `black26`/`grey[50]`, rayon 10, focus primaire, saisie `digitsOnly`, auto-submit à 6 chiffres, backspace navigue, collage) · `GradientButton` « Valider et se connecter ».

---

## 3. Dashboard & Accueil

### 3.1 Accueil — `dashboard_home.dart`
- **Layout** : Scaffold + drawer, colonne : **en-tête custom** (barre blanche / `#1E1E1E`, « Accueil » 18 w600, notification + hamburger) puis `RefreshIndicator` + scroll.
- **Sections (ordre)** :
  1. **Header** — avatar dégradé 48px arrondi 14 avec initiale + « 👋 Bonjour, » + nom bold + **badge plan** (vert « Pro/Business » / orange « Gratuit ») + email.
  2. **MarketingCarousel** — PageView vertical h96, slides colorées, dots animés.
  3. **CloudStorageInfoBanner** — compact, plan gratuit.
  4. **3 cartes stats** côte à côte — Revenus (primaire, `trending_up`), Moyenne (vert, `equalizer`), Taux paiement (orange, `percent`) — icône dans carré teinté, valeur bold, label 9px.
  5. **Balance card** — dégradé primaire→70%, « Total balance » blanc 70%, montant blanc 32 bold, 3 colonnes (Payé vert / En attente orange / En retard rouge) + **3 boutons d'action** translucides bordés (Facture `add`, Client `person_add`, Payer `payment`).
  6. **« Statut des factures »** — 4 mini-cartes (Payées / En attente / En retard / Annulées), icône + compte bold + label, bordure couleur 0.2.
  7. **PromoSection** — carrousel publicitaire auto (Timer 4s).
  8. **« Nouveaux clients »** — liste horizontale de **bulles avatar dégradées** (60px, couleur par hash `#1A237E`…`#9C27B0`, initiale + nom tronqué).
  9. **« Factures récentes »** — tuiles transaction (icône rectangulaire bleu/orange, numéro, client, montant FCFA rouge/vert, badge statut).
- **Données** : stats financières, 5 derniers clients, 4 dernières factures.

### 3.2 Liste factures — `invoices_screen.dart`
- **Layout** : AppBar transparente (retour, titre « Factures », **PopupMenu filtre** `tune` → Toutes/Payées/En attente/En retard/Annulées/Brouillons, **champ de recherche** en bas d'AppBar).
- **Composants** : **cartes facture** (rayon 16) — badge type **« FACT » bleu / « DEVIS » orange** (9 w700), numéro 15 w600, badge statut teinté, client 13 w500, date `dd MMM yyyy` 11 gris, **montant FCFA primaire 15 w700** · **FAB `+`** · **empty state** (icône `receipt_long`, « Créer une facture »).

### 3.3 Création facture — `create_invoice_screen.dart`
- **Layout** : `GlassScaffold`, AppBar transparente (✕ + titre dynamique « Nouvelle facture/devis » + action « Enregistrer »). Form scrollable.
- **Composants** : **ChoiceChips Facture/Devis** · **champ Client** readOnly (dialog liste clients) · **ligne produit** (Produit + Qté + Prix + `add_circle`) · bouton « Depuis le stock » (dialog sélection + quantité + contrôle stock) · **liste des lignes** (description + « qté x prix FCFA » + ✕ rouge) · **Frais de livraison** (`local_shipping`) · **TVA % + Remise** · **Notes** · **récap total** (Sous-total / Livraison / TVA 18% / Remise / **TOTAL TTC** primaire 17 bold) · `GradientButton` « Enregistrer ».
- **Données** : calculs auto (sous-total, TVA 18%, remise, livraison).

### 3.4 Détail facture — `invoice_detail_screen.dart`
- **Layout** : `GlassScaffold`, AppBar = numéro facture + actions (modèles `style`, partage, PDF `picture_as_pdf`, email, partage équipe).
- **Composants** : **bandeau template cliquable** (carré 40px couleur + « Modèle: X » + badge « Cliquez pour changer » / « 🔒 Premium ») · **carte facture** (logo société 80px + nom 18 bold + adresse/tél/email/RCCM, divider, numéro 20 bold + **badge statut plein**, infos Date/Échéance/Client, liste « Produits », divider, **Total** 18 bold + montant primaire 20 bold, **2 boutons** « Aperçu PDF » (Elevated) + « Imprimer » (Outlined)) · dialogs : « ⭐ Template Premium » (paywall), « Partager la facture » (équipe + permissions + @membres).

### 3.5 Liste clients — `clients_screen.dart`
- **Layout** : AppBar (retour, « Clients », action **recherche** → `SearchDelegate` plein écran).
- **Composants** : cartes client (rayon 16, ombre) — **avatar dégradé 50px** (couleur par hash, 8 couleurs `#1A237E`→`#F44336`, initiale blanche) + nom 16 w600 + téléphone & email (icônes 14) + **badge « N deals »** primaire teinté + chevron · **FAB `+`** · empty state.

---

## 4. Stock, Produits & Fournisseurs

### 4.1 Catalogue produits — `products_screen.dart`
- **Layout** : AppBar « Catalogue » (20 bold) ou **recherche intégrée** (toggle), **PopupMenu filtre** (Tous / Stock faible / Rupture).
- **Composants** : cartes produit **angles droits** (rayon 0, bordure 1px, pas d'ombre) — **avatar dégradé de statut 54px** (vert/orange/rouge selon stock, initiale w800) + nom 15 bold + **badge catégorie** (carré bordé, 7px w700 MAJUSCULES) + **quantité « X unité »** 15 w900 + **badge statut** (« EN STOCK » / « STOCK FAIBLE » / « RUPTURE ») · **FAB extended « Créer »**.

### 4.2 Création produit — `create_product_screen.dart`
- **Layout** : `GlassScaffold`, AppBar (retour + « Nouveau produit » + action).
- **Composants** : **sélecteur photo** (aperçu 96px arrondi 16, placeholder `add_a_photo`, pastille ✕) · **Nom du produit *** · **Description** (3 lignes) · **Quantité * + Prix de vente *** · **Prix d'achat + Stock minimal *** (2 colonnes) · **Catégorie** · **Fournisseur** (sélection + lien création) · **Unité** (dropdown : pièce/kg/litre/mètre/boîte/sac/carton) · **Code-barres** (`qr_code`) · `GradientButton` « Ajouter le produit ».

### 4.3 Fournisseurs — `suppliers_screen.dart`
- **Layout** : AppBar avec **recherche intégrée** + action refresh.
- **Composants** : cartes (rayon 12) — avatar 50px initiale primaire sur fond primaire 0.1 + nom 16 w600 + badge « Inactif » gris + lignes « Tél: » / « Email: » + boutons **edit / delete** (rouge) · **FAB `+`** · empty state (icône `business` 80 primaire).

---

## 5. Portefeuille, Abonnement & Paiement

### 5.1 Portefeuille — `wallet_screen.dart`
- **Layout** : AppBar transparente « 💰 Portefeuille », `RefreshIndicator` + scroll.
- **Composants** : **carte solde dégradé primaire** (rayon 16) — « Solde disponible » blanc 70% + montant formaté blanc 28 bold + texte explicatif · **bouton « Demander un retrait »** (h50, désactivé si solde ≤0) · sections « Historique des transactions » + « Demandes de retrait » · **tuiles transaction** (fond `grey[50]`/`grey[900]` rayon 12 — icône `savings` vert crédit / `outbox` rouge débit, description, date `dd/MM/yyyy • hh:mm`, réf, montant **+/- vert/rouge**) · **tuiles retrait** (icône couleur statut, montant, « → numéro », **badge statut** « Payé »/« Refusé »/« En attente »).

### 5.2 Choix du plan — `subscription_screen.dart`
- **Layout** : AppBar « Abonnement », scroll vertical.
- **Composants** : en-tête « Choisissez le plan qui vous convient » · **cartes plans empilées** (rayon 16, bordure 1px gris / **2px primaire si sélectionné** + ombre) — nom 20 bold, description 13, **badge « POPULAIRE »** plein primaire + coche blanche ronde, **prix 28 bold** + « / mois » ou « / an », features avec `check_circle` vert · **bouton CTA 56** « Souscrire à X » / « Activer le plan gratuit » · ligne « 🔒 Paiement sécurisé via E-nkap ».

### 5.3 Liste des offres — `plans_screen.dart`
- **Layout** : fond **`grey[50]` fixe**, AppBar « Nos offres », **bandeau en-tête** (admin « 👑 Administrateur - Accès illimité » / bleu sinon).
- **Composants** : cartes plan (rayon 16, **bordure ambre 2px si populaire**, élévation 4) — nom 18 bold (vert si actuel), badge « POPULAIRE » ambre, description, **prix 24 bold**, features, **bouton plein** (vert « ✅ Actif » / ambre « Choisir ce plan » / bleu sinon), **badge « ACTUEL »** haut-droite · bottom sheet « Détails de votre abonnement ».

### 5.4 Paiement — `payment_screen.dart`
- **Layout** : AppBar « Paiement », scroll vertical.
- **Composants** : **carte résumé plan dégradé primaire** (rayon 16) — « Résumé de votre abonnement », nom 22 bold, description, divider, « Total à payer » + prix 24 bold · section « Méthode de paiement » · **3 tuiles méthodes** (rayon 12, sélection = fond couleur @0.1 + bordure 2px + coche) : **Orange Money** (orange, `phone_android`), **MTN Mobile Money** (or `#FFD700`), **Carte bancaire** (violet, `credit_card`) · **champ téléphone** (si Mobile Money, hint « 6X XX XX XX XX ») · bannière erreur · **bouton « Payer X »** 56 primaire · ligne « Paiement sécurisé via E-nkap • Données cryptées ».

---

## 6. Équipes, Support, Notifications, Analytiques, Sécurité

### 6.1 Équipes — `teams_screen.dart`
- **Layout** : AppBar « Équipes » + action `+`, ListView.
- **Composants** : cartes (rayon 12) — `CircleAvatar` bleu 0.1 initiale + nom + « N membres » + chevron · **empty state** (« Aucune équipe », « Créer une équipe »).

### 6.2 Support — `support_screen.dart`
- **Layout** : AppBar « Support », scroll de cartes `ListTile` (rayon 12).
- **Composants** : icône dans carré teinté (couleur @0.1, rayon 10) + titre w600 + sous-titre gris + chevron. **Entrées** : FAQ (primaire), Support en ligne (vert `#4CAF50`), Contacter le support (`#3949AB`), Envoyer un retour (orange `#FF9800`), Guide d'utilisation (violet `#9C27B0`), Statut du service (vert) · section **« Documents légaux »** (icône `gavel`) : Mentions légales (`#546E7A`), Confidentialité (teal `#00897B`), Licence (`#6A1B9A`), Propriété du produit (`#C62828`).

### 6.3 Notifications — `notification_screen.dart`
- **Layout** : AppBar « Notifications » + PopupMenu (Tout marquer lu / Tout supprimer) + **TabBar 2 onglets** « Toutes » / « Non lues » (indicator et label primaires).
- **Composants** : listes de `Card`+`ListTile` **supprimables par swipe** (`Dismissible`) — icône + titre (gras si non lu) + corps ; tap = marquer lu.

### 6.4 Analytiques — `analytics_screen.dart`
- **Layout** : AppBar « Analyses » + refresh, `GridView.count` 2×2 (aspect 1.35, rayon 16).
- **Composants** : 4 cartes résumé (Chiffre d'affaires primaire, Commandes orange, Panier moyen vert, Meilleur mois ambre) · **graphique barres `fl_chart`** (« Évolution des ventes », h240, barres primaires dégradées, tooltip, grille pointillée) · **tableau DataTable** (« Détail mensuel » : Mois / CA / Commandes / Panier moyen) · empty state.

### 6.5 Sécurité — `security_screen.dart`
- **Layout** : AppBar « Sécurité », 2 sections (« AUTHENTIFICATION » / « SÉCURITÉ AVANCÉE », titres 12 bold primaire), cartes groupées (rayon 16).
- **Composants** : **Mot de passe** (`lock_outline`, chevron) · **switch Biométrie** (`fingerprint`, Face ID/Empreinte) · **switch Code PIN** (`pin`) · **switch 2FA** (`security`) · **Sessions** (`devices`) · **Journal** (`history`) · dialogs : définir/supprimer PIN (6 chiffres), activer 2FA (QR/clé secrète + copier + champ TOTP).

---

## 7. Personnalisation des modèles (Boutique + Workspace)

### 7.1 Boutique de modèles — `template_store_screen.dart`
- **Layout** : `GlassScaffold`, AppBar « Modèles de Facture » + actions « Mes modèles » + « Panier » (pastille rouge compteur).
- **Composants** : **bandeau glass** (« Boutique Premium — débloquez des designs exclusifs », `storefront` or / « Accès Premium activé » vert) · sections par catégorie (Classique, Moderne, Élégant, Premium, Minimaliste, Entreprise) · **carousel horizontal** de cartes modèles (190×250).
- **Carte modèle** (`GlassCard` rayon 20) : **aperçu** (image OU icône `description` dans cercle couleur) + **badges** (`GlassBadge` « Premium » ⭐ or / « PRIX XAF » vert) + **overlay verrou** (voile noir 0.45 + cercle dégradé indigo→violet avec cadenas blanc) · nom 13 w600 + description 10 · **bouton « Personnaliser »** dégradé indigo→violet · **barre panier fixe en bas** (« N modèle(s) • total XAF » + bouton « Commander »).

### 7.2 Workspace drag & drop — `template_workspace_screen.dart`
- **Layout** : AppBar « Personnaliser — {modèle} » + actions « Réinitialiser » + « Enregistrer » dégradé · **FAB extended « Éléments »**.
- **Composants** : **aperçu A4** (`AspectRatio` 210/297) sur fond `#EEEEF2`/`#111114` + **grille de repères 4×4** + **18 éléments positionnables** (logo, infos société, titre FACTURE, infos client, lignes, sous-total, TVA, remise, total, pied, QR, signature) à **x/y relatifs (0..1) + scale + visible**, déplaçables au doigt (`onPanUpdate`), sélection au tap · **bottom sheet « Éléments »** (h 62%, chips par section En-tête/Client/Corps/Pied) + **panneau propriétés** (visibilité/scale/mapping).

---

## 8. Landing page & Encadrement

### 8.1 Landing page — `landing_screen.dart`
- **Layout** : fond `#0B0D17` (sombre) / `#F6F7FB` (clair) + **`AnimatedBackground`** (halos + icônes flottantes) · colonne : barre logo + **PageView 6 slides** + dots + CTA.
- **Composants** :
  - **Barre top** : logo 40px arrondi 14 (fallback dégradé) + « Noi Ohada » 20 w800 + TextButton « Connexion ».
  - **Slide héros** : **art central « facture »** blanche bordée indigo 2px (barres squelettes + bouton dégradé « TOTAL 206 500 ») **orbité par 6 icônes modules** (anneau rotatif 14s) · titre 30 w800 « La facturation OHADA, simple & puissante. » · **`GlassBadge` « ✨ Essai gratuit • Sans carte bancaire »**.
  - **Slides features** (icône 120px dégradée couleur accent + titre 26 + texte) : Conformité OHADA `#4338CA`, Cloud Synchro `#7C3AED`, Paiements Multi `#E9B949`, Travail en Équipe `#06B6D4` (nuage + 5 avatars orbitants), Marketing `#F59E0B` (carte dégradé orange/rouge avec 3 stats « +38% Ventes / 2 400 Relances / 95% Paiements »).
  - **Dots** : actif = pilule dégradée indigo→violet 24px, inactif gris 8px.
  - **CTA fixe** : `GradientButton` « Créer mon compte gratuitement » (`rocket_launch`) + « 🔒 Données chiffrées & conformes SYSCOHADA ».

### 8.2 Bottom sheet encaissement — `payment_bottom_sheet.dart`
- **Layout** : bottom sheet (rayon haut 20), drag handle, padding 24, max h 85%, au-dessus du clavier.
- **Composants** : en-tête `verified_user_outlined` + « Validation manuelle du paiement » · **Dropdown factures** · **carte montant** primaire @0.08 · section « Moyen de paiement » + **4 tuiles** : Cash (vert `payments`), Orange Money (orange), MTN Mobile Money (or), Carte (violet) — sélection = fond @0.1 + bordure 2px + coche · **champ téléphone client** · **stepper cycle de validation** (ronds 28px remplis, labels 9px : Brouillon→Envoyée→Payée) · **bouton CTA 52** (bleu « Marquer comme envoyée » / vert « Confirmer le paiement (manuel) » / primaire « Initier le paiement en ligne ») · ligne sécurité.

### 8.3 Menu latéral (drawer) — `custom_drawer.dart`
- **Layout** : Drawer = **en-tête dégradé primaire** centré + `ListView` + footer version.
- **Composants** : **en-tête** (dégradé primaire→70%, `CircleAvatar` 32px blanc 0.3 initiale, nom 18 bold blanc, email 13 blanc 80%, badge plan blanc 0.2) · **menu** : Profil, Abonnement, Modèles de factures **PREMIUM**, Fournisseurs, Équipes **PREMIUM**, Invitations, Rappels, Relance clients **PREMIUM**, Administration (admin), —divider—, Paramètres, —divider—, Support, FAQ, Partager l'application, —divider—, **Déconnexion rouge** · footer « OHADA Invoice Pro v1.0.0 ».

---

## 9. Paramètres — `settings_screen.dart`
- **Layout** : `GlassScaffold`, AppBar « Paramètres », sections en **MAJUSCULES 11 bold gris** : Compte, Personnalisation, Support, À propos.
- **Composants** : **carte profil** (avatar dégradé 48px + nom + email + chevron) · **groupes de `ListTile`** dans cartes groupées :
  - **Compte** : Abonnement (`payment` → nom plan), Entreprise (`business`), Sécurité (`security`).
  - **Personnalisation** : Thème (`palette` → Clair/Sombre/Système), Modèles de factures (`receipt_long` **PREMIUM**), Portefeuille (`account_balance_wallet` **PREMIUM**), Sauvegarde Google Drive (`cloud_upload` **PREMIUM**), Notifications.
  - **Support** : Centre d'aide (`help`), Support en ligne (`chat`), Contacter le support (`email`).
  - **À propos** : OHADA Invoice Pro v1.0.0 (`info`), **Test paiement E-nkap (admin)**, **Déconnexion rouge** (`logout`).
- **Dialogs** : bottom sheet thème, À propos, Déconnexion.

---

## 10. Conseils d'utilisation avec Google Stitch

1. **Méthode prompt textuel** : collez la description d'un écran ci-dessus (section + layout + composants + couleurs) dans Stitch et demandez une maquette **mobile-first** (largeur 390px recommandée) ou **desktop** selon l'écran.
2. **Méthode image de référence** : capturez l'écran actuel de l'app (émulateur Android, `flutter run`, ou APK) et fournissez-la comme référence avec un prompt du type : « redesign this invoice app screen, keep layout but modernize with glassmorphism, indigo #4338CA → violet #7C3AED gradient, gold #E9B949 accents, Roboto font ».
3. **Fidélité à garder** : les **badges de statut** (vert/orange/rouge), les **badges PREMIUM or**, les **dégradés indigo→violet**, les **avatars colorés par hash**, les **montants FCFA en primaire**.
4. **Cohérence** : si vous refaites un écran « glass premium », appliquez la même famille à tous les écrans de cette famille ; idem pour les écrans « classiques Material ».
5. **Variantes** : générez chaque écran en **thème clair ET sombre** (fond `#0E1117`, surfaces `#161B26`/`#1E2433`).
6. **Chaîne à décrire** : les textes d'interface sont en **français** (conserver les libellés exacts comme « Factures », « Payer », « Solde disponible », « En attente de confirmation… »).

---

## 11. ✅ Refonte appliquée (2026-08-11)

À partir des maquettes Stitch fournies dans `design/stitch_export/` (design system « L'Éclat de l'OHADA »), la refonte suivante a été implémentée dans le code. `flutter analyze` : **0 erreur**.

| Écran | Fichier | Changements appliqués |
|---|---|---|
| **Accueil** | `dashboard_home.dart` | 🔴 **Bug corrigé** : la balance affichait la moyenne au lieu du total → « Solde Total (FCFA) » = revenu total, 3 items (Encaissé/En attente/En retard) avec pastilles colorées `#34D399`/`#FBBF24`/`#F87171`, montant 34 w800. Badge plan : icône `verified` + nom en MAJUSCULE, fond indigo (payant) / or `#E9B949` (gratuit), rayon pilule. Bouton notification rond 42px. Ordre : balance en premier, puis stats. |
| **Connexion** | `login_screen.dart` | Logo avec ring blanc 3px. Champs Email/Mot de passe en **floating labels** (Material 3), fond translucide, rayon 12, focus bordure 1.5px. |
| **Détail facture** | `invoice_detail_screen.dart` | Section Produits → **table OHADA** avec en-têtes (Désignation / Qté / PU / Total), en-tête teinté primaire, lignes séparées, total de ligne en primaire. |
| **Clients** | `clients_screen.dart` | Avatar **rond** + ombre. Badge « N factures » (au lieu de « deals »). |
| **Catalogue** | `stock/products_screen.dart` | **Cartes résumé** en tête : Total Produits, Alertes Stock, + carte « Valeur du Stock » en dégradé `#4338CA→#8A4CFC` pleine largeur. |
| **Fournisseurs** | `suppliers/suppliers_screen.dart` | **Chips de filtre** Tous / Actifs / Inactifs (sélection = fond violet `#8A4CFC`). Avatar rond. |
| **Choix du plan** | `subscription_screen.dart` | Plan **POPULAIRE** = ring primaire + glow même non sélectionné ; badge « POPULAIRE » teinté (fond primaire 10% + bordure) au lieu de plein. |
| **Analytiques** | `analytics_screen.dart` | **Refonte complète** : cartes résumé avec **badges de tendance** (↑ vert `#34D399` / ↓ rouge `#F87171`) + unités (FCFA, FCFA/CMD, PAYÉES) ; section **« Canaux de Paiement »** = **donut chart** (Orange 45%, MTN 30%, Cash 15%, Carte 10%) + légende ; tableau « Détail mensuel » avec bouton **EXPORTER** (copie CSV). |
| **Boutique Templates** | `template_store_screen.dart` | Barre de recherche ronde, **chips filtres** (Tous / Premium / Gratuit), section **« Tendances »** (carte vedette : badge, prix, note ★, bouton Aperçu dégradé), grille **« Tous les templates »** 2 colonnes (badge catégorie + prix + note ★). Carousels par catégorie conservés. |
| **Subscription** | `subscription_screen.dart` | Bouton « Souscrire à X → » en **dégradé indigo→violet** + flèche ; note « Paiement sécurisé via E-nkap » conservée. |
| **Profil Fournisseur** | `supplier_detail_screen.dart` *(nouveau)* | Carte profil (avatar rond, nom, adresse, badge Actif/Inactif, coordonnées), stats **VOLUME (YTD)** + **PRODUITS LIÉS**, liste « Produits fournis » avec badges de stock. Ouvert en cliquant une carte fournisseur. |
| **Inventaire** | `stock_screen.dart` | **Cartes résumé** (TOTAL PRODUITS / ALERTES STOCK / VALEUR DU STOCK en dégradé) + en-tête « Inventaire / Voir tout ». |
| **Détail Produit** | `product_detail_screen.dart` | **Hero image**, description, **RÉFÉRENCE (SKU)** + **FOURNISSEUR**, **État du Stock** avec jauge (quantité/seuil/max), Point de commande, Unité, section **Tarification** (achat HT / vente HT / marge + % / TVA 18%), historique conservé. |
| **Commercialisation Factures** | `relance_screen.dart` | **Tableau de bord** : cartes stats Total Envoyé / Impayés, carte **Relances Auto** + switch, graphique **Tendance des paiements** (courbe personnalisée), liste **Factures Récentes** (badges statut + actions WhatsApp/Encaisser). Formulaire de relance conservé dessous. |
| **Nouveau Client** | `create_client_screen.dart` | Segmented buttons **ENTREPRISE/PARTICULIER**, sections **IDENTITÉ / CONTACT / LOCALISATION / PRÉFÉRENCES**, NIF/IFU requis (B2B), **Conditions de Paiement** (sélecteur), bouton « Enregistrer le client ». |

**Écrans déjà conformes** (aucune modification nécessaire) : portefeuille, notifications, équipes, workspace drag & drop, auth (inscription/2FA/mot de passe oublié), paiement.

---

*Généré à partir du code source (`lib/screens/**`, `lib/widgets/**`) et des maquettes Stitch (`design/stitch_export/`).*
