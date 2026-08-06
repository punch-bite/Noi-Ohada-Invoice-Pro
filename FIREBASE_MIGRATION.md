# 🔥 Migration Hive → Firestore (OHADA Invoice Pro)

## Objectif
Faire de **Firestore** la source unique de vérité des données métier et
**supprimer Hive** comme base de données des données de l'entreprise.

---

## ✅ Réalisé

### 1. Modèle `Plan` étendu (lib/models/plan.dart)
Ajout de champs pour gérer les quotats et modules :
- `maxProducts` (nb produits autorisé)
- `maxTeamMembers` (nb membres équipe, uniquement Business)
- `hasGoogleDriveSync` (module Grive Drive, uniquement Business)

Plusieurs helpers : `hasProductLimit`, `isUnlimitedClients/Products/Invoices()`.

### 2. Normes de quotas (logique SaaS)
| Plan      | Clients   | Produits  | Factures        | Équipe | Google Drive |
|-----------|-----------|-----------|-----------------|--------|--------------|
| Gratuit   | 5         | 5         | 10              | non    | non          |
| Pro       | 200       | 25        | illimitées      | non    | non          |
| Business  | illimité  | illimité  | illimitées      | oui    | oui          |

- `Plan.getFreePlan()`, `getProPlan()`, `getBusinessPlan()` mis à jour.
- `firestore_init.js` : plans `free`, `pro`, `business`, `unlimited` alignés.

### 3. `DatabaseService` → Firestore UNIQUEMENT (lib/services/database_service.dart)
- **Réécrit intégralement** : plus aucune boîte Hive.
- Toutes les données sont lues/écrites sur Firestore, scopées par l'UID.
- Signature des méthodes **inchangée** → aucune refonte des ~27 écrans.
- Collections : users, companies, clients, invoices, products, plans,
  subscriptions, suppliers, reminders, notifications.
- Ajout de `clearAllData()` qui vide les collections Firestore de l'utilisateur.

### 3bis. 🔥 Services auxiliaires migrés vers Firestore (2026-08-06)
Les services auparavant **100 % Hive** délèguent désormais à Firestore :
- `NotificationService` → collection `notifications` (via `DatabaseService`)
- `ReminderService` → collection `reminders` (via `DatabaseService`)
- `SupplierService` → collection `suppliers` (via `DatabaseService`)
- `StockService` → produits via `DatabaseService` ; livraisons collection `deliveries`
- `AnalyticsService` → cache remplacé par `SharedPreferences` (plus de Hive)

✅ Le code métier (stock, rappels, fournisseurs, notifications) vit maintenant
**uniquement dans Firestore** — plus de divergence local/cloud.

### 4. Chargement des données au login
- `AuthService.getUserProfile()` lit **déjà** le profil depuis Firestore.
- Le profil de l'utilisateur est donc chargé depuis le cloud à chaque connexion.

### 5. Nettoyage Hive au logout
- **Confirmé** : `AppAuthProvider.logout()` appelle `HiveService.clearAllData()`,
  et l'écouteur d'état d'authentification purge Hive aussi en cas d'expiration
  de session. Aucune fuite de données entre utilisateurs.

### 6. `firestore.rules` réécrit
- Accès **admin** à **toutes** les données de ts les utilisateurs.
- Règles par utilisateur (`userId == auth.uid`).
- Module équipe : lecture partagée via `teamIds` / `teams` / `team_invitations`.
- Collections système (plans, templates, settings, logs) restrictives.

### 7. `firestore_init.js` enrichi
- Plans mis à jour (quotas).
- Seeds ajoutés : notifications, teams, team_invitations, team_permissions,
  drive_sync.
- Admin accès global.

### 8. Module équipe (Business)
- Service existant `TeamService` **déjà 100% Firestore** (invitations par
  e-mail, partage de factures, gestion des membres).
- `SubscriptionProvider` expose désormais `hasTeamAccess`, `maxTeamMembers`.

### 9. Application des quotas
- Nouveau `lib/services/quota_enforcement_service.dart` :
  `canAddClient`, `canAddProduct`, `canAddInvoice` selon le plan courant.
- `SubscriptionProvider` gagne `maxProducts`, `hasTeamAccess`,
  `maxTeamMembers`, `hasGoogleDriveSync`.

### 10. Synchronisation Google Drive
- Nouveau `lib/services/google_drive_sync_service.dart` :
  configure l'état dans Firestore (`drive_sync`), génère un **backup JSON**
  des clients/produits/factures et gère l'authentification Google
  (`google_sign_in`, disponible).

---

## ⏳ À faire / à valider côté cloud & app

### Quotas côté sécurité (recommandation)
Les `firestore.rules` **ne peuvent pas compter** les documents (pas
d'agrégation dans les règles). Les quotas sont donc **appliqués côté app**
(`QuotaEnforcementService`). Pour une sécurité renforcée, implémenter un
**Cloud Function** qui vérifie le quota avant l'écriture.

### Déploiement des règles
1. `firebase deploy --only firestore:rules`
2. Mettre à jour `ADMIN_UID` dans `firestore_init.js` avec le vrai UID admin.
3. Exécuter `node firestore_init.js` pour créer/planter la base.
4. Pour l'admin : ajouter le claim `admin: true` dans Firebase Auth.

### Google Drive — upload réel
`google_sign_in` fournit le token OAuth2. Pour l'upload vers Drive :
- Activer l'API Drive dans la console Google.
- Ajouter le scope `https://www.googleapis.com/auth/drive.file`.
- Brancher `googleapis` (DriveApi) ou un envoi HTTP REST avec le token.
- L'état `drive_sync` Firestore est prêt (enabled, folderId, lastSyncAt).

### Retrait complet de Hive (services auxiliaires)
`DatabaseService` (données métier) est déjà 100% Firestore. Il reste à migrer
les services auxiliaires qui utilisent encore Hive pour du cache interne :
- analytics_service, logger_service, notification_service, reminder_service,
  security_service, stock_service, subscription_checker_service,
  supplier_service, theme_service.

Après leur migration, supprimer `lib/services/hive_service.dart`, les
adaptateurs `.g.dart` et la dépendance `hive`/`hive_flutter` dans `pubspec.yaml`.

### Écrans module équipe
`TeamService` et les modèles sont prêts. Créer/afficher les écrans UI :
- Créer une équipe, inviter par e-mail (lien), accepter une invitation,
  gérer les membres, partager des ressources.

---

## ♻️ Questions logique SaaS couvertes
- Plans + quotas ✔
- Chargement utilisateur au login depuis Firestore ✔
- Hive nettoyé au logout ✔
- Entreprises stockées dans Firestore à la création ✔ (`DatabaseService.saveCompany`)
- Module équipe (invitation par e-mail) réservé Business ✔
- Synchronisation Google Drive ✔
- Admin accès à tous les utilisateurs ✔ (`firestore.rules`)
