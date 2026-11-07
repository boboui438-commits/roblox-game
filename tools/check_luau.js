#!/usr/bin/env node
/**
 * Vérificateur de syntaxe Luau pour ce projet.
 *
 * Installation (une seule fois) :
 *     npm install luau-parser
 *
 * Utilisation :
 *     node tools/check_luau.js            # vérifie src/
 *     node tools/check_luau.js src/UI     # vérifie un dossier précis
 *
 * Sortie : liste des fichiers en erreur + code de sortie 1 si au moins
 * un fichier ne parse pas (pratique pour une CI).
 */
const fs = require('fs');
const path = require('path');

let parse;
try {
  ({ parse } = require('luau-parser'));
} catch (error) {
  console.error("❌ module manquant : lance `npm install luau-parser` d'abord.");
  process.exit(2);
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, out);
    } else if (full.endsWith('.lua')) {
      out.push(full);
    }
  }
  return out;
}

const target = process.argv[2] || path.join(__dirname, '..', 'src');
const files = walk(target).sort();

let failed = 0;
for (const file of files) {
  const source = fs.readFileSync(file, 'utf8');
  try {
    parse(source);
  } catch (error) {
    failed += 1;
    const message = String(error.message || error).split('\n').slice(0, 4).join('\n   ');
    console.log(`❌ ${path.relative(process.cwd(), file)}\n   ${message}`);
  }
}

const ok = files.length - failed;
console.log(`\n${ok}/${files.length} fichiers Luau valides`);
process.exit(failed > 0 ? 1 : 0);
