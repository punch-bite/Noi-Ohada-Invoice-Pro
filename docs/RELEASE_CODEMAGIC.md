# Release Android via CODEMAGIC → GitHub Releases → bouton /download

> Cette note décrit la chaîne **automatique** mise en place
> (Codemagic en sync avec GitHub).

## 🔁 Chaîne complète

```
git tag v1.0.x && git push origin v1.0.x
        │
        ▼ (webhook GitHub → Codemagic)
CODEMAGIC  workflows.release  (codemagic.yaml)
  1. décode le keystore (KEYSTORE_BASE64)
  2. écrit android/local.properties (mots de passe signature)
  3. flutter build apk --release --obfuscate --split-debug-info=…
  4. flutter build appbundle --release …
        │
        ▼ publishing.github_releases (draft:false, prerelease:false)
GITHUB RELEASE « Noi OHADA Invoice Pro – v1.0.x »
  assets : *.apk, *.aab, build/symbols/**
        │
        ▼ (server/download.js → api.github.com/.../releases/latest, cache 5 min)
VERCEL /download  → bouton ANDROID « Télécharger » pointe sur l'APK
                    (lien direct stable : GET /app/latest.apk → 302 APK)
```

## ⚙️ Configuration Codemagic (une seule fois)

**UI Codemagic → Applications → *(cette app)* → Environment variables** :

| Groupe | Variables |
|---|---|
| `android_signing` | `KEYSTORE_BASE64` (`cat android/app/upload-keystore.jks \| base64`), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` |
| `github_credentials` | `GITHUB_USERNAME` = `punch-bite`, `GITHUB_TOKEN` = PAT GitHub scope `repo` |
| `app_secrets` (optionnel) | `API_SECRET_KEY` (même valeur que sur Vercel) |

Puis **Codemagic → App settings → Webhooks** : vérifier que le webhook
GitHub est actif (il l'est si l'app est connectée via l'intégration GitHub).

> ⚠️ Le publish est en `draft:false` / `prerelease:false` car l'API
> `releases/latest` ignore les drafts/prereleases — sinon le bouton
> Android resterait sur « Bientôt disponible ».

## 🌐 Web → Vercel (deux options)

**Option A — GitHub Actions (déjà branchée, opt-in)** : le job
`deploy_web_vercel` de `.github/workflows/ci.yml` déploie le build web
sur Vercel à chaque push `main` si :
- variable de dépôt `DEPLOY_WEB_VERCEL` = `true`,
- secrets `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`
  (projet Vercel **statique** de la web-app — PAS celui du serveur API).

**Option B — Codemagic** : ajouter un workflow `web-vercel`
(`flutter build web` + `vercel deploy build/web --prod`) avec le groupe
`vercel_credentials` (VERCEL_TOKEN/ORG_ID/PROJECT_ID).

## 🔗 Liens utiles

- Page de téléchargement : `https://server-xi-two-23.vercel.app/download`
- Lien direct stable APK (partage WhatsApp/QR) :
  `https://server-xi-two-23.vercel.app/app/latest.apk`
- API builds : `GET /api/builds` (Bearer Firebase requis)
