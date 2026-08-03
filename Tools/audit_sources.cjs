const fs = require('fs');
const path = require('path');
const parser = require('node-weakauras-parser');
const { chromium } = require('playwright');

const ROOT = path.join('Research', 'Audit20260803');
fs.mkdirSync(ROOT, { recursive: true });

const WAGO_TARGETS = [
  { slug: 'g1d1f6fiC', className: 'Pyromancer', label: 'Healer Pyromancer' },
  { slug: 'w-XCZHABg', className: 'Tinker', label: 'Healer Tinker' },
  { slug: '25AZFWqQH', className: 'Bloodmage', label: 'Bloodmage Pack' },
];

const SIDEKICK_TARGETS = [
  { id: 'w_173c2281', className: 'Templar', label: 'Templar', url: 'https://ascensionsidekick.com/weakauras/w_173c2281' },
  { id: 'w_cb1725f1', className: 'Chronomancer', label: 'Chronomancer', url: 'https://ascensionsidekick.com/weakauras/w_cb1725f1' },
];

function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[’`]/g, "'")
    .replace(/\|c[0-9a-f]{8}|\|r/gi, '')
    .replace(/\b(buff|aura|spell|main|icon|tracker|display|bar)\b/g, ' ')
    .replace(/\b[0-9]+\b/g, ' ')
    .replace(/[^a-z0-9']+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function compact(value, max = 600) {
  if (value === undefined || value === null) return '';
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  return text.replace(/[\r\n\t]+/g, ' ').slice(0, max);
}

async function request(url, options = {}) {
  const response = await fetch(url, {
    redirect: 'follow',
    ...options,
    headers: {
      'user-agent': 'RetreatUI-Class-Audit/1.0',
      'accept': 'application/json,text/plain,text/html,*/*',
      ...(options.headers || {}),
    },
  });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${url}`);
  return response;
}

function listLuaFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? listLuaFiles(full) : (entry.name.endsWith('.lua') ? [full] : []);
  });
}

function currentClassNames(className) {
  const dir = path.join('RetreatUI_Classes', className);
  const names = new Map();
  for (const file of listLuaFiles(dir)) {
    const text = fs.readFileSync(file, 'utf8');
    for (const match of text.matchAll(/\bname\s*=\s*["']([^"']+)["']/g)) {
      const key = normalize(match[1]);
      if (key && !names.has(key)) names.set(key, { name: match[1], file });
    }
    for (const match of text.matchAll(/\baliases\s*=\s*\{([^}]*)\}/g)) {
      for (const alias of match[1].matchAll(/["']([^"']+)["']/g)) {
        const key = normalize(alias[1]);
        if (key && !names.has(key)) names.set(key, { name: alias[1], file });
      }
    }
  }
  return names;
}

function triggerEntries(triggers) {
  if (Array.isArray(triggers)) return triggers;
  if (triggers && typeof triggers === 'object') {
    return Object.keys(triggers).filter(key => /^\d+$/.test(key)).sort((a, b) => Number(a) - Number(b)).map(key => triggers[key]);
  }
  return [];
}

function walkDisplays(root) {
  const displays = [];
  const seen = new Set();
  function visit(node, parent = '') {
    if (!node || typeof node !== 'object' || seen.has(node)) return;
    seen.add(node);
    const id = typeof node.id === 'string' ? node.id : '';
    const triggers = triggerEntries(node.triggers);
    if (id || node.regionType || node.controlledChildren || triggers.length) {
      const spellRefs = new Set();
      const auraRefs = new Set();
      const customCode = [];
      for (const entry of triggers) {
        const trigger = entry && entry.trigger ? entry.trigger : (entry || {});
        for (const [key, value] of Object.entries(trigger)) {
          if (/spell.*(id|name)/i.test(key)) {
            for (const item of Array.isArray(value) ? value : [value]) if (item !== '' && item !== undefined) spellRefs.add(String(item));
          }
          if (/aura(names?|spellids?)/i.test(key)) {
            for (const item of Array.isArray(value) ? value : [value]) if (item !== '' && item !== undefined) auraRefs.add(String(item));
          }
          if (typeof value === 'string' && (/custom/i.test(key) || value.includes('GetSpell'))) customCode.push(value);
        }
      }
      for (const key of ['init', 'customText']) if (typeof node[key] === 'string') customCode.push(node[key]);
      displays.push({
        id,
        parent,
        regionType: node.regionType || '',
        load: node.load || {},
        controlledChildren: node.controlledChildren || [],
        spellRefs: [...spellRefs],
        auraRefs: [...auraRefs],
        customCode,
        raw: node,
      });
    }
    if (Array.isArray(node.d)) for (const child of node.d) visit(child, id || parent);
    if (Array.isArray(node.children)) for (const child of node.children) visit(child, id || parent);
  }
  visit(root, '');
  return displays;
}

function selectedFields(display) {
  const rows = [];
  function flatten(value, prefix, depth = 0) {
    if (depth > 7 || value === undefined || value === null) return;
    if (typeof value !== 'object') {
      if (/^(id|parent|regionType|displayIcon|icon|texture|url|semver|version|load|triggers|conditions|customText|init|actions)/.test(prefix)) {
        rows.push(`${prefix}=${compact(value, 1600)}`);
      }
      return;
    }
    if (Array.isArray(value)) {
      value.forEach((item, index) => flatten(item, `${prefix}[${index}]`, depth + 1));
      return;
    }
    for (const [key, child] of Object.entries(value)) {
      const next = prefix ? `${prefix}.${key}` : key;
      if (depth === 0 || /^(id|parent|regionType|displayIcon|icon|texture|url|semver|version|load|triggers|conditions|customText|init|actions|controlledChildren|information)/.test(next)) {
        flatten(child, next, depth + 1);
      }
    }
  }
  flatten(display.raw, '');
  return rows;
}

function auditDecoded(target, decoded, outDir, sourceMeta = {}) {
  fs.mkdirSync(outDir, { recursive: true });
  const displays = walkDisplays(decoded);
  const current = currentClassNames(target.className);
  const candidates = [];
  for (const display of displays) {
    const key = normalize(display.id);
    if (!key || display.regionType === 'group' || display.regionType === 'dynamicgroup') continue;
    const present = current.has(key);
    candidates.push({
      status: present ? 'present' : 'review',
      display: display.id,
      normalized: key,
      currentMatch: present ? current.get(key).name : '',
      regionType: display.regionType,
      parent: display.parent,
      spellRefs: display.spellRefs.join(','),
      auraRefs: display.auraRefs.join(','),
    });
  }
  candidates.sort((a, b) => a.status.localeCompare(b.status) || a.display.localeCompare(b.display));

  const displayLines = ['display\tparent\tregionType\tload\tspellRefs\tauraRefs\tchildren'];
  for (const display of displays) {
    displayLines.push([
      compact(display.id), compact(display.parent), compact(display.regionType), compact(display.load),
      display.spellRefs.join(','), display.auraRefs.join(','), compact(display.controlledChildren),
    ].join('\t'));
  }
  const candidateLines = ['status\tdisplay\tcurrentMatch\tparent\tregionType\tspellRefs\tauraRefs'];
  for (const row of candidates) candidateLines.push([row.status, row.display, row.currentMatch, row.parent, row.regionType, row.spellRefs, row.auraRefs].map(compact).join('\t'));

  const fieldText = displays.map(display => `===== ${display.id || '(unnamed)'} =====\n${selectedFields(display).join('\n')}`).join('\n\n') + '\n';
  const customCode = displays.flatMap(display => display.customCode.map((code, index) => ({ display: display.id, index, code })));
  const summary = [
    `source=${target.label}`,
    `class=${target.className}`,
    `root_id=${decoded && decoded.id ? decoded.id : ''}`,
    `display_count=${displays.length}`,
    `review_candidates=${candidates.filter(row => row.status === 'review').length}`,
    `current_names=${current.size}`,
    `custom_code_blocks=${customCode.length}`,
    ...Object.entries(sourceMeta).map(([key, value]) => `${key}=${compact(value, 2000)}`),
  ].join('\n') + '\n';

  fs.writeFileSync(path.join(outDir, 'summary.txt'), summary);
  fs.writeFileSync(path.join(outDir, 'displays.tsv'), displayLines.join('\n') + '\n');
  fs.writeFileSync(path.join(outDir, 'candidates.tsv'), candidateLines.join('\n') + '\n');
  fs.writeFileSync(path.join(outDir, 'selected-fields.txt'), fieldText);
  fs.writeFileSync(path.join(outDir, 'custom-code.json'), JSON.stringify(customCode, null, 2));
  fs.writeFileSync(path.join(outDir, 'selected-raw.json'), JSON.stringify(Object.fromEntries(displays.map(d => [d.id || `unnamed-${Math.random()}`, d.raw])), null, 2));
}

async function auditWago(target) {
  const outDir = path.join(ROOT, 'Wago', target.slug);
  fs.mkdirSync(outDir, { recursive: true });
  const metadataResponse = await request('https://data.wago.io/api/check/weakauras', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ids: [target.slug] }),
  });
  const metadataText = await metadataResponse.text();
  fs.writeFileSync(path.join(outDir, 'metadata.json'), metadataText);
  const encoded = (await (await request(`https://data.wago.io/api/raw/encoded?id=${target.slug}`)).text()).trim();
  const decoded = parser.decodeSync(encoded, 512 * 1024 * 1024);
  auditDecoded(target, decoded, outDir, { encoded_length: encoded.length, metadata: metadataText });
}

function findImportStrings(text) {
  const candidates = new Set();
  if (!text) return [];
  for (const source of [text, text.replace(/\\u0021/g, '!').replace(/\\n/g, '').replace(/\\"/g, '"')]) {
    for (const match of source.matchAll(/!WA:[^\s"'`<>]{100,}/g)) candidates.add(match[0]);
  }
  return [...candidates].sort((a, b) => b.length - a.length);
}

async function auditSidekick(target, browser) {
  const outDir = path.join(ROOT, 'Sidekick', target.id);
  fs.mkdirSync(outDir, { recursive: true });
  const context = await browser.newContext({ permissions: ['clipboard-read', 'clipboard-write'] });
  const page = await context.newPage();
  const responses = [];
  page.on('response', async response => {
    try {
      const type = response.headers()['content-type'] || '';
      if (!/(json|text|javascript|html)/i.test(type)) return;
      const body = await response.text();
      if (body.length <= 8 * 1024 * 1024) responses.push({ url: response.url(), status: response.status(), type, body });
    } catch (_) {}
  });
  await page.goto(target.url, { waitUntil: 'networkidle', timeout: 90000 });
  await page.waitForTimeout(2500);

  const buttons = await page.locator('button').allTextContents().catch(() => []);
  let clipboard = '';
  for (const pattern of [/copy/i, /import/i, /weakaura/i]) {
    const locator = page.getByRole('button', { name: pattern }).first();
    if (await locator.count().catch(() => 0)) {
      await locator.click().catch(() => {});
      await page.waitForTimeout(300);
      clipboard = await page.evaluate(() => navigator.clipboard && navigator.clipboard.readText ? navigator.clipboard.readText().catch(() => '') : '').catch(() => '');
      if (clipboard) break;
    }
  }

  const html = await page.content();
  const bodyText = await page.locator('body').innerText().catch(() => '');
  const nextData = await page.evaluate(() => window.__NEXT_DATA__ || null).catch(() => null);
  const scripts = await page.locator('script').allTextContents().catch(() => []);
  const pools = [clipboard, html, bodyText, JSON.stringify(nextData), ...scripts, ...responses.map(r => r.body)];
  const imports = [...new Set(pools.flatMap(findImportStrings))].sort((a, b) => b.length - a.length);

  fs.writeFileSync(path.join(outDir, 'diagnostics.json'), JSON.stringify({
    url: target.url,
    title: await page.title(),
    buttons,
    clipboardLength: clipboard.length,
    responseUrls: responses.map(r => ({ url: r.url, status: r.status, type: r.type, length: r.body.length })),
    importCandidates: imports.map(value => ({ length: value.length, prefix: value.slice(0, 80) })),
  }, null, 2));
  fs.writeFileSync(path.join(outDir, 'page-text.txt'), bodyText);
  fs.writeFileSync(path.join(outDir, 'page.html'), html);

  if (!imports.length) {
    fs.writeFileSync(path.join(outDir, 'summary.txt'), `source=${target.label}\nclass=${target.className}\nimport_found=false\nresponses=${responses.length}\n`);
    await context.close();
    return;
  }

  let decoded = null;
  let selected = '';
  const errors = [];
  for (const candidate of imports) {
    try {
      decoded = parser.decodeSync(candidate, 512 * 1024 * 1024);
      selected = candidate;
      break;
    } catch (error) { errors.push(String(error)); }
  }
  if (decoded) {
    auditDecoded(target, decoded, outDir, { import_found: true, encoded_length: selected.length, response_count: responses.length });
  } else {
    fs.writeFileSync(path.join(outDir, 'summary.txt'), `source=${target.label}\nclass=${target.className}\nimport_found=true\ndecode_success=false\nerrors=${compact(errors)}\n`);
  }
  await context.close();
}

function auditAllClasses() {
  const root = 'RetreatUI_Classes';
  const expected = [
    'Barbarian','Bloodmage','Chronomancer','Cultist','Felsworn','Guardian','KnightOfXoroth','Necromancer','Primalist','Pyromancer','Ranger','Reaper','Runemaster','Starcaller','Stormbringer','SunCleric','Templar','Tinker','Venomancer','WitchDoctor','WitchHunter',
  ];
  const summary = ['class\tbaseRecords\toverlayNames\tcore\tutility\tproc\tduplicateNames\tduplicateIDs\tmissingIDs\teternalRecords'];
  const issues = [];
  for (const className of expected) {
    const dir = path.join(root, className);
    const dataFile = path.join(dir, 'Data.lua');
    if (!fs.existsSync(dataFile)) {
      summary.push(`${className}\t0\t0\t0\t0\t0\t0\t0\t0\t0`);
      issues.push(`${className}: missing Data.lua`);
      continue;
    }
    const data = fs.readFileSync(dataFile, 'utf8');
    const recordLines = data.split(/\r?\n/).filter(line => /\{\s*name\s*=/.test(line));
    const names = new Map();
    const ids = new Map();
    let core = 0, utility = 0, proc = 0, missingIDs = 0, eternal = 0;
    for (const line of recordLines) {
      const name = (line.match(/name\s*=\s*["']([^"']+)["']/) || [])[1] || '';
      const id = Number((line.match(/\bid\s*=\s*(\d+)/) || [])[1] || 0);
      const key = normalize(name);
      if (key) names.set(key, (names.get(key) || 0) + 1);
      if (id) ids.set(id, (ids.get(id) || 0) + 1); else missingIDs++;
      if (/hudRow\s*=\s*["']core["']/.test(line)) core++;
      if (/hudRow\s*=\s*["']utility["']/.test(line)) utility++;
      if (/category\s*=\s*["']proc["']/.test(line)) proc++;
      if (/sourceTab\s*=\s*["']Eternal["']/.test(line)) eternal++;
    }
    const overlayNames = listLuaFiles(dir).filter(file => path.basename(file) !== 'Data.lua').reduce((count, file) => {
      const text = fs.readFileSync(file, 'utf8');
      return count + [...text.matchAll(/(?:Upsert|Patch)\s*\(\s*(?:\{|["'])/g)].length;
    }, 0);
    const duplicateNames = [...names.values()].filter(count => count > 1).length;
    const duplicateIDs = [...ids.values()].filter(count => count > 1).length;
    if (duplicateNames) issues.push(`${className}: ${duplicateNames} duplicate normalized base names`);
    if (duplicateIDs) issues.push(`${className}: ${duplicateIDs} duplicate base spell IDs`);
    if (missingIDs) issues.push(`${className}: ${missingIDs} base records without id`);
    summary.push([className, recordLines.length, overlayNames, core, utility, proc, duplicateNames, duplicateIDs, missingIDs, eternal].join('\t'));
  }
  fs.mkdirSync(path.join(ROOT, 'AllClasses'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, 'AllClasses', 'summary.tsv'), summary.join('\n') + '\n');
  fs.writeFileSync(path.join(ROOT, 'AllClasses', 'issues.txt'), issues.join('\n') + '\n');
}

(async () => {
  for (const target of WAGO_TARGETS) await auditWago(target);
  const browser = await chromium.launch({ headless: true });
  try {
    for (const target of SIDEKICK_TARGETS) await auditSidekick(target, browser);
  } finally {
    await browser.close();
  }
  auditAllClasses();
})().catch(error => {
  console.error(error);
  process.exit(1);
});
