// server/logger.js
// 📝 Journalisation des erreurs et événements côté serveur (Node/Express).
//
//  - Écrit dans un fichier : server/logs/server.log (meilleur effort,
//    persistant en exécution locale `node index.js` / `npm run dev`).
//  - Écrit aussi dans la console (stdout/stderr) : c'est ce que Vercel
//    capture en production (les logs restent accessibles dans le tableau de
//    bord Vercel — le filesystem serverless est éphémère).
//  - Ne lève JAMAIS d'exception (le journal ne doit pas casser le serveur).
//
const fs = require('fs');
const path = require('path');

const LOG_DIR = path.join(__dirname, 'logs');
const LOG_FILE = path.join(LOG_DIR, 'server.log');

function ensureDir() {
  try {
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
  } catch (_) {
    /* ignoré */
  }
}

function timestamp() {
  return new Date().toISOString();
}

function write(level, message, meta) {
  const metaStr =
    meta && typeof meta === 'object' ? ' ' + JSON.stringify(meta) : '';
  const line = `[${timestamp()}] [${level}] ${message}${metaStr}`;

  // Console (capturée par Vercel / utiles en local).
  try {
    if (level === 'ERROR' || level === 'WARN') {
      console.error(line);
    } else {
      console.log(line);
    }
  } catch (_) {
    /* ignoré */
  }

  // Fichier (meilleur effort).
  try {
    ensureDir();
    fs.appendFileSync(LOG_FILE, line + '\n', 'utf8');
  } catch (_) {
    /* ignoré */
  }
}

const logger = {
  info: (msg, meta) => write('INFO', msg, meta),
  warn: (msg, meta) => write('WARN', msg, meta),
  error: (msg, meta) => write('ERROR', msg, meta),
  logFilePath: LOG_FILE,
};

module.exports = logger;
