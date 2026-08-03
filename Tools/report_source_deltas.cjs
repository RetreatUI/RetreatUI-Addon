const fs = require('fs');
const path = require('path');

const ROOT = path.join('Research', 'Audit20260803');
const TARGETS = [
  {className:'Pyromancer', source:path.join(ROOT,'Wago','g1d1f6fiC')},
  {className:'Tinker', source:path.join(ROOT,'Wago','w-XCZHABg')},
  {className:'Bloodmage', source:path.join(ROOT,'Wago','25AZFWqQH')},
  {className:'Templar', source:path.join(ROOT,'Sidekick','w_173c2281')},
  {className:'Chronomancer', source:path.join(ROOT,'Sidekick','w_cb1725f1')},
];

function listLuaFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry => {
    const full=path.join(dir,entry.name);
    return entry.isDirectory()?listLuaFiles(full):(entry.name.endsWith('.lua')?[full]:[]);
  });
}

function normalize(value) {
  return String(value||'').toLowerCase().replace(/[’`]/g,"'")
    .replace(/[_-]+/g,' ').replace(/\b(buff|aura|spell|icon|tracker|display|main|cd|cooldown)\b/g,' ')
    .replace(/\d+/g,' ').replace(/[^a-z0-9']+/g,' ').replace(/\s+/g,' ').trim();
}

function currentData(className) {
  const ids=new Set(), names=new Set();
  for (const file of listLuaFiles(path.join('RetreatUI_Classes',className))) {
    const text=fs.readFileSync(file,'utf8');
    for (const match of text.matchAll(/\b(?:id|auraID|buffID|runtimeID|chargeSpellID)\s*=\s*(\d+)/g)) ids.add(Number(match[1]));
    for (const match of text.matchAll(/\b(?:spellIDs|runtimeIDs|auraIDs)\s*=\s*\{([^}]*)\}/g)) {
      for (const number of match[1].matchAll(/\d+/g)) ids.add(Number(number[0]));
    }
    for (const match of text.matchAll(/\bname\s*=\s*["']([^"']+)["']/g)) names.add(normalize(match[1]));
    for (const match of text.matchAll(/\baliases\s*=\s*\{([^}]*)\}/g)) {
      for (const alias of match[1].matchAll(/["']([^"']+)["']/g)) names.add(normalize(alias[1]));
    }
  }
  return {ids,names};
}

function numericRefs(value) {
  return [...new Set(String(value||'').match(/\b\d{4,7}\b/g)||[])].map(Number);
}

for (const target of TARGETS) {
  const file=path.join(target.source,'displays.tsv');
  if (!fs.existsSync(file)) continue;
  const lines=fs.readFileSync(file,'utf8').trim().split(/\r?\n/);
  const current=currentData(target.className);
  const rows=[];
  for (const line of lines.slice(1)) {
    const [display,parent,regionType,load,spellRefs,auraRefs,children]=line.split('\t');
    if (!display || /^(group|dynamicgroup)$/i.test(regionType||'')) continue;
    const displayKey=normalize(display);
    const namePresent=current.names.has(displayKey);
    for (const [kind,value] of [['spell',spellRefs],['aura',auraRefs]]) {
      for (const id of numericRefs(value)) {
        rows.push({status:current.ids.has(id)?'present':'missing-id',id,kind,display,parent,regionType,namePresent});
      }
    }
    let parsedLoad={};
    try { parsedLoad=JSON.parse(load||'{}'); } catch (_) {}
    for (const key of ['spellknown','knowntalent','talentknown']) {
      const value=parsedLoad && parsedLoad[key];
      if (Number.isFinite(Number(value))) rows.push({status:current.ids.has(Number(value))?'present':'load-only',id:Number(value),kind:key,display,parent,regionType,namePresent});
    }
  }
  const dedup=new Map();
  for (const row of rows) {
    const key=[row.status,row.id,row.kind,row.display,row.parent].join('|');
    if (!dedup.has(key)) dedup.set(key,row);
  }
  const sorted=[...dedup.values()].sort((a,b)=>a.status.localeCompare(b.status)||a.parent.localeCompare(b.parent)||a.display.localeCompare(b.display)||a.id-b.id);
  const out=['status\tid\tkind\tdisplay\tparent\tregionType\tnamePresent'];
  for (const row of sorted) out.push([row.status,row.id,row.kind,row.display,row.parent,row.regionType,row.namePresent].join('\t'));
  fs.writeFileSync(path.join(target.source,'id-delta.tsv'),out.join('\n')+'\n');

  const missing=sorted.filter(row=>row.status==='missing-id');
  const summary=[
    `class=${target.className}`,
    `current_ids=${current.ids.size}`,
    `current_names=${current.names.size}`,
    `referenced_rows=${sorted.length}`,
    `missing_id_rows=${missing.length}`,
    `missing_unique_ids=${new Set(missing.map(row=>row.id)).size}`,
  ].join('\n')+'\n';
  fs.writeFileSync(path.join(target.source,'id-delta-summary.txt'),summary);
}
