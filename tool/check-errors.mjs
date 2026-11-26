#!/usr/bin/env node
// Crashlytics coverage check. Run from the repo root: `melos run errors:check`.
//  1. A file that calls ApiClient must convert bodies with `apiClient.parse(...)`, never read `response.data` itself.
//  2. A `catch` must log (`logError`/`recordError`), rethrow, or say why not with `// errors:ok <reason>` in its body.
//     `on ApiException catch` is exempt: ApiClient already reported and showed it.
//  3. The same holds for `.catchError(...)` and `onError:` handlers (the comment may sit on the line above).
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const scanned = ['apps', 'features', 'packages'];
const skip = /(^|\/)(build|\.dart_tool|node_modules|test|example|ios|android|web|packages\/api_client|integration_test)(\/|$)|\.(g|module)\.dart$|injection\.config\.dart$/;

function* dartFiles(dir) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const rel = relative(root, full);
    if (skip.test(rel)) continue;
    if (statSync(full).isDirectory()) yield* dartFiles(full);
    else if (full.endsWith('.dart')) yield rel;
  }
}

// Text of the `{ ... }` block starting at the first `{` at or after [from].
function block(source, from) {
  const open = source.indexOf('{', from);
  if (open < 0) return '';
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++;
    else if (source[i] === '}' && --depth === 0) return source.slice(open, i + 1);
  }
  return source.slice(open);
}

// Text of the argument that starts at [from]: up to the `,` or closing bracket that ends it.
function argument(source, from) {
  let depth = 0;
  for (let i = from; i < source.length; i++) {
    const char = source[i];
    if ('([{'.includes(char)) depth++;
    else if (')]}'.includes(char)) {
      if (depth === 0) return source.slice(from, i);
      depth--;
    } else if (char === ',' && depth === 0) return source.slice(from, i);
  }
  return source.slice(from);
}

const handled = /logError|reportError|callableErrorMessage|recordError|reportApiError|CrashlyticsService|rethrow|\bthrow\b|errors:ok/;
const found = {};
for (const top of scanned) {
  if (!existsSync(join(root, top))) continue;
  for (const file of dartFiles(join(root, top))) {
    const source = readFileSync(join(root, file), 'utf8');
    const lines = source.split('\n');
    const problems = [];
    if (/\b\w*[aA]piClient\.(post|get|put|patch|delete)\b/.test(source)) {
      lines.forEach((line, index) => {
        if (/\b(response|res|resp)\.data\b/.test(line)) problems.push(`${file}:${index + 1}: read the body through apiClient.parse(...), not response.data`);
      });
    }
    for (const match of source.matchAll(/(\bon\s+(\w+)\s+)?\bcatch\s*\(/g)) {
      if (match[2] === 'ApiException') continue;
      const body = block(source, match.index + match[0].length);
      if (handled.test(body)) continue;
      const line = source.slice(0, match.index).split('\n').length;
      problems.push(`${file}:${line}: catch neither logs (logError), rethrows, nor says why with "// errors:ok <reason>"`);
    }
    for (const match of source.matchAll(/\.catchError\(|\bonError:/g)) {
      const start = source.lastIndexOf('\n', source.lastIndexOf('\n', match.index) - 1);
      const text = source.slice(start, match.index) + argument(source, match.index + match[0].length);
      if (handled.test(text)) continue;
      const line = source.slice(0, match.index).split('\n').length;
      problems.push(`${file}:${line}: ${match[0].replace(/[.(:]/g, '')} handler neither reports (reportError/logError) nor says why with "// errors:ok <reason>"`);
    }
    if (problems.length) found[file] = problems;
  }
}

const problems = Object.values(found).flat();
problems.forEach((problem) => console.error(problem));
console.log(problems.length ? `\nerrors:check failed (${problems.length}).` : 'errors:check passed.');
process.exit(problems.length ? 1 : 0);
