# NOI OHADA Invoice Pro

Application SaaS de génération de factures conformes aux normes OHADA pour les PME d'Afrique francophone.

## 🚀 Fonctionnalités
~~~~
- ✅ Création de factures et devis
- ✅ Gestion des clients
- ✅ Génération PDF professionnel
- ✅ Conformité SYSCOHADA
- ✅ Calcul automatique des taxes
- ✅ Stockage local (hors-ligne)
- ✅ Synchronisation cloud
- ✅ Interface multidevice (Mobile, Desktop, Web)

## 📋 Prérequis

- Flutter 3.0+
- Dart 3.0+
- Compte Firebase (pour la synchronisation)

## 🛠 Installation

1. Cloner le projet
```bash
git clone https://github.com/votre-repo/ohada_invoice_pro.git
cd ohada_invoice_pro

## 📦 Publier une GitHub Release (APK/AAB)

En attendant la validation de l'accès **Google Play Console**, vous pouvez
distribuer l'application via une **GitHub Release** construite automatiquement
par le workflow [`.github/workflows/release-apk.yml`](.github/workflows/release-apk.yml).
Le build produit un **APK signé** (installation directe) et un **AAB** (à soumettre
plus tard au Play Store).

### 1. Configurer les secrets GitHub (une seule fois)

Rendez-vous sur **Settings → Secrets and variables → Actions** du dépôt et
ajoutez :

| Secret              | Valeur                                                                 |
|---------------------|------------------------------------------------------------------------|
| `KEYSTORE_BASE64`   | `cat android/app/upload-keystore.jks | base64 -w0` (contenu base64)     |
| `KEYSTORE_PASSWORD` | mot de passe du keystore                                                |
| `KEY_ALIAS`         | alias de la clé (ex. `upload`)                                          |
| `KEY_PASSWORD`      | mot de passe de la clé                                                  |
| `API_SECRET_KEY`    | (optionnel) clé secrète serveur si votre Vercel l'exige en 401          |

> ⚠️ Le keystore `upload-keystore.jks` est **déjà ignoré** dans `.gitignore`.
> Ne le commitez **jamais** : envoyez-le uniquement en base64 via le secret.

### 2. Créer un tag et pousser

```bash
git tag v1.0.0
git push origin v1.0.0
```

Le workflow se déclenche automatiquement, build l'APK + l'AAB, puis crée
une **release brouillon** avec les artefacts attachés. Vous pourrez ensuite
la publier (et télécharger l'APK) depuis l'onglet **Releases**.

### 3. Alternative : déclenchement manuel

Dans l'onglet **Actions → « Build & Publish Android Release » → Run workflow**,
renseignez un `tag_name` si vous voulez tag à la volée.

### Liens utiles
- Workflow : [release-apk.yml](.github/workflows/release-apk.yml)
- CI existante : [ci.yml](.github/workflows/ci.yml), [flutter_ci.yml](.github/workflows/flutter_ci.yml)