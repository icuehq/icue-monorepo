#!/usr/bin/env node
// Checks the Inventory and Library code against docs/naming-map.md: banned abbreviations, module prefixes,
// uid prefixes and one/two-letter names. Run from the repo root: `melos run naming:check`.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const include = [
  'firebase/functions/src', 'firebase/functions/test', 'firebase/functions/scripts', 'firebase/firestore.rules', 'firebase/rules-tests/rules.test.js',
  'features/inventory/lib', 'features/inventory/test', 'features/library/lib', 'features/library/test',
  'features/inventory/lib/src/ui', 'features/library/lib/src/ui', 'packages/admin_ui/lib', 'packages/icue_firebase/lib/src/school_data.dart',
];
const generated = /\.(g|module)\.dart$|injection\.config\.dart$/;

function* files(path) {
  const full = join(root, path);
  if (!existsSync(full)) return;
  const info = statSync(full);
  if (info.isFile()) return yield full;
  for (const entry of readdirSync(full)) {
    if (entry === 'node_modules' || entry === 'build') continue;
    yield* files(join(path, entry));
  }
}

const bannedWords = ['qty', 'cmp', 'rol', 'ack', 'calc', 'cond', 'perm', 'perms', 'ctx', 'acc', 'grn', 'fy', 'ay', 'txn', 'eid', 'sid', 'pt'];
const banned = new RegExp(`\\b(${bannedWords.join('|')})\\b`);
const patterns = [
  [/\b(inv|lib)[A-Z]\w*/, 'module prefix must be spelled out (inventory…/library…)'],
  [/\b(Inv|Lib)[A-Z]\w*/, 'module prefix must be spelled out (Inventory…/Library…)'],
  [/['"`](inv|lib)[-.]/, 'callable and permission names use inventory/library'],
  [/['"``/](u|s|p)_[A-Za-z0-9]/, 'uids are used as they are, without a u_/s_/p_ prefix'],
];
const allowed = new Set(['_', 'id', 'i', 'j', 'db', 'to', 'ok']);
const one = '[a-z_][a-z0-9]?';
const declarations = [
  new RegExp(`\\b(?:final|var|const|let)\\s+(?:[A-Za-z_][A-Za-z0-9_<>?,\\s.\\[\\]]*?\\s+)?(${one})\\s*(?==|;|:)`, 'g'),
  new RegExp(`for\\s*\\(\\s*(?:final|var|const|let)\\s+(${one})\\s+(?:in|of)\\b`, 'g'),
  new RegExp(`[(,]\\s*(${one})\\s*\\)\\s*(?:async\\s*)?(?:=>|\\{)`, 'g'),
  new RegExp(`[(,]\\s*(?:${one})\\s*,\\s*(${one})\\s*\\)\\s*(?:async\\s*)?(?:=>|\\{)`, 'g'),
  new RegExp(`[(,]\\s*(${one})\\s*:\\s*[A-Za-z{\\[]`, 'g'),
  new RegExp(`catch\\s*\\(\\s*(${one})\\b`, 'g'),
];

const problems = [];
for (const path of include) {
  for (const file of files(path)) {
    if (!/\.(ts|dart|js|rules)$/.test(file) || generated.test(file)) continue;
    const isRules = file.endsWith('.rules');
    const lines = readFileSync(file, 'utf8').split('\n');
    lines.forEach((text, index) => {
      const code = text.replace(/\/\/.*$/, '').replace(/^\s*(\*|\/\*).*$/, '');
      if (!code.trim()) return;
      const where = `${relative(root, file)}:${index + 1}`;
      const withoutStrings = code.replace(/'[^'\n]*'|"[^"\n]*"|`[^`\n]*`/g, "''");
      const word = banned.exec(isRules ? withoutStrings.replace(/\.diff\(/g, '') : withoutStrings);
      if (word) problems.push(`${where}: banned abbreviation "${word[1]}"`);
      for (const [pattern, message] of patterns) if (pattern.test(code)) problems.push(`${where}: ${message}`);
      if (isRules) return;
      for (const pattern of declarations) {
        pattern.lastIndex = 0;
        for (const match of withoutStrings.matchAll(pattern)) {
          if (!allowed.has(match[1])) problems.push(`${where}: one/two-letter name "${match[1]}"`);
        }
      }
    });
  }
}
if (problems.length) {
  console.error(problems.join('\n'));
  console.error(`\n${problems.length} naming problem(s). See docs/naming-map.md.`);
  process.exit(1);
}
console.log('Naming check passed.');
