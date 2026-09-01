# 🚀 Serveur de callback NotchPay (NOI OHADA Invoice Pro)

Ce serveur **confirme côté serveur** les paiements d'abonnement NotchPay et
active l'abonnement dans Firestore — conforme à la méthode officielle
« Create a Payment Session » (callback / webhook).

## Flux

```
Flutter app                          Serveur (/payment/callback)          NotchPay
    │  POST /payment (clé publique) ───────────────────────────────────→   │
    │  ← authorization_url (page Collect)                                 │
    │  Ouvre la page Collect ──────────────────────────────────────────→   │
    │  Client paie (Mobile Money / carte)                                 │
    │  ←────────────────── callback POST (transaction + x-notch-signature)│
    │       Vérifie la signature HMAC-SHA256                              │
    │       Active l'abonnement Firestore (idempotent)                    │
    │  ← statut confirmé via polling GET /verify/:reference               │
```

## Endpoints

| Méthode | Route                 | Description                                      |
|---------|-----------------------|--------------------------------------------------|
| POST    | `/payment/callback`   | Webhook NotchPay : vérifie + active l'abonnement |
| GET     | `/verify/:reference`  | Statut d'activation (polling client)             |
| GET     | `/health`             | Santé du service                                 |

## Prérequis

- Node 18+
- Un compte de service Firebase (la clé `serviceAccountKey.json` du projet,
  ou la variable `FIREBASE_SERVICE_ACCOUNT` en base64)
- Le secret du webhook NotchPay (`NOCHPAY_WEBHOOK_SECRET`)

## Installation & lancement

```bash
cd server
npm install
# Créer le .env depuis l'exemple
copy .env.example .env
# Renseigner NOCHPAY_WEBHOOK_SECRET (+ la clé Firebase si besoin)
npm start
```

> Le serveur lit par défaut `serviceAccountKey.json` à la racine du projet
> (au-dessus de `server/`). En production, privilégiez
> `FIREBASE_SERVICE_ACCOUNT` (base64) pour ne pas committer la clé.

## Déploiement (exemples)

- **Vercel (recommandé, gratuit)** — voir section dédiée ci-dessous.
- **Render / Railway / Fly.io** : serveur Node.js standard, port `PORT`.
- **Cloud Run (GCP)** : `gcloud run deploy` — définir les variables d'env
  `NOCHPAY_WEBHOOK_SECRET` et `FIREBASE_SERVICE_ACCOUNT`.

---

## 🚀 Déploiement sur Vercel

Le serveur est prêt pour Vercel : `index.js` exporte l'app Express
(`module.exports = app`) et le `vercel.json` route toutes les requêtes vers
elle. Aucun `app.listen` en mode serverless.

### 1. Préparer le projet

```bash
cd server
npm install
```

### 2. Créer le projet sur Vercel

- Importer le dépôt GitHub dans Vercel (ou `npx vercel`).
- **Root Directory** : `server`
- **Build Command** : (aucun — framework preset "Other")
- **Install Command** : `npm install`

### 3. Variables d'environnement (dashboard Vercel → Settings → Environment Variables)

| Variable                    | Valeur                                              |
|-----------------------------|-----------------------------------------------------|
| `NOCHPAY_WEBHOOK_SECRET`    | Le secret NotchPay (`hsk_test...`)                   |
| `FIREBASE_SERVICE_ACCOUNT`  | La clé `serviceAccountKey.json` **en base64**        |
| `SMTP_HOST`                 | Serveur SMTP (défaut `smtp.gmail.com`)              |
| `SMTP_PORT`                 | Port SMTP (587/TLS, ou 465/SSL)                     |
| `SMTP_USERNAME`             | Adresse SMTP (ex. un Gmail Application Password)     |
| `SMTP_PASSWORD`             | Mot de passe / Application Password SMTP            |
| `SMTP_FROM_EMAIL`           | Expéditeur des mails                                |
| `SMTP_FROM_NAME`            | Nom de l'expéditeur (défaut : Noi OHADA Invoice Pro) |

> ⚠️ Sans `SMTP_USERNAME`/`SMTP_PASSWORD`, les **invitations d'équipe** et
> l'envoi de mails (`/email/send`, `POST /team/manage-member` action
> `invite`) répondent en **HTTP 500**. C'est l'erreur « invitation » que
> voyaient les utilisateurs.

> ⚠️ Sur Vercel, le fichier `serviceAccountKey.json` n'est pas embarqué :
> il faut obligatoirement fournir `FIREBASE_SERVICE_ACCOUNT` (base64 du JSON).
> PowerShell : `[Convert]::ToBase64String([IO.File]::ReadAllBytes("serviceAccountKey.json"))`

### 4. Déployer

```bash
npx vercel --prod
```

URL obtenue, ex. `https://noi-ohada-callback.vercel.app`.

### 5. Tester

```bash
curl https://<votre-app>.vercel.app/health
# → {"ok":true,"service":"noi-ohada-payment-callback",...}
```

### 6. Brancher l'app Flutter

Dans le `.env` Flutter :

```
API_BASE_URL=https://<votre-app>.vercel.app
```

Le callback envoyé devient `https://<votre-app>.vercel.app/payment/callback`.

> ⚙️ Test local Vercel : `npm run vercel:dev` (nécessite `npx vercel dev`).

---

## ⚙️ Configurer le callback dans NotchPay

1. Déployer ce serveur sur une URL publique : `https://api.ohada-invoice-pro.com`
2. Dans l'app Flutter, renseigner `API_BASE_URL=https://api.ohada-invoice-pro.com`
   (le callback envoyé devient `https://api.ohada-invoice-pro.com/payment/callback`).
3. (Option) Déclarer l'URL de callback dans le tableau de bord NotchPay
   afin que NotchPay notifie aussi ce webhook.

## Test en local (sans déploiement)

```bash
# 1. Lancer le serveur
cd server && npm start

# 2. Simuler un callback valide (adapter la signature au vrai secret)
curl -X POST http://localhost:8080/payment/callback \
  -H "Content-Type: application/json" \
  -H "x-notch-signature: sha256:<CALCULER>" \
  -d '{"transaction":{"reference":"SUB-123","status":"complete","amount":9900,"currency":"XAF","customer_meta":{"user_id":"UID","plan_id":"pro","purpose":"subscription"}}}'
```

> La signature = `HMAC-SHA256(secret, corps brut)` en hexadécimal.
