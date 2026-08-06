# ☁️ Cloud Functions — Callback NotchPay (NOI OHADA Invoice Pro)

Confirme **côté serveur** les paiements d'abonnement NotchPay et active
l'abonnement dans Firestore. Intégré au projet Firebase (`facture-ohada`),
région `africa-south1` (même région que la base Firestore).

## Fonctions

| Fonction         | Méthode | Description                                      |
|------------------|---------|--------------------------------------------------|
| `paymentCallback` | POST   | Webhook NotchPay : vérifie la signature + active l'abonnement (idempotent) |
| `paymentVerify`   | GET    | `?reference=...` — statut d'activation (polling) |
| `paymentHealth`   | GET    | Santé du service                                 |

## Installation

```bash
cd functions
npm install
```

## Déployer

```bash
# 1. Définir le secret du webhook NotchPay (une seule fois)
firebase functions:secrets:set NOCHPAY_WEBHOOK_SECRET

# 2. Déployer
firebase deploy --only functions
```

Après déploiement :
- Callback : `https://africa-south1-facture-ohada.cloudfunctions.net/paymentCallback`
- Verify   : `https://africa-south1-facture-ohada.cloudfunctions.net/paymentVerify`

## 🎯 Brancher l'app Flutter

Dans le `.env` Flutter, pointer le callback vers la fonction :

```
API_BASE_URL=https://africa-south1-facture-ohada.cloudfunctions.net/paymentCallback
```

L'app enverra alors `callback = https://.../paymentCallback/payment/callback`
(le chemin `/payment/callback` route vers la fonction, qui ignore le suffixe).

> 💡 La confirmation fonctionne aussi via le **polling client** (l'app interroge
> NotchPay directement). La Cloud Function ajoute la confirmation serveur fiable
> et permet d'activer l'abonnement même si l'app se ferme après le paiement.

## Émulateur local

```bash
cd functions
copy .env.example .env.local   # renseigner NOCHPAY_WEBHOOK_SECRET
npm run serve                  # firebase emulators:start --only functions
```

URL locale : `http://localhost:5001/facture-ohada/africa-south1/paymentCallback`

## Test (signature valide)

La signature = `HMAC-SHA256(secret, corps brut)` en hexadécimal, header
`x-notch-signature: sha256=<hex>`.

```bash
# Exemple avec le CLI (adapter secret + corps)
curl -X POST "http://localhost:5001/facture-ohada/africa-south1/paymentCallback" \
  -H "Content-Type: application/json" \
  -H "x-notch-signature: sha256:<HMAC>" \
  -d '{"transaction":{"reference":"SUB-TEST","status":"complete","amount":9900,"currency":"XAF","customer_meta":{"user_id":"UID","plan_id":"pro","purpose":"subscription"}}}'
```

## ⚠️ Notes

- Le **secret** (`NOCHPAY_WEBHOOK_SECRET`) est géré via Firebase Secret Manager
  (`defineSecret`) — jamais committé.
- `firebase-admin` est initialisé automatiquement dans l'environnement Cloud
  Functions (aucune clé de compte de service à embarquer).
- L'activation est **idempotente** : recherche par `paymentId`, réactive si
  existant, sinon crée l'abonnement `active` + lie `user.subscriptionId`.
