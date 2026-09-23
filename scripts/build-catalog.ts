// Собирает HTTP-каталог скиллов для OpenCode V2 в dist/catalog/.
//
//   node scripts/build-catalog.ts          — поднять версии изменённых скиллов и собрать каталог
//   node scripts/build-catalog.ts --check  — только проверить, что версии актуальны (для CI)
//
// Версия скилла — metadata.version в SKILL.md. Хеш содержимого на момент последней версии
// хранится в skills.lock.json: если файлы скилла изменились, а версия нет, сборка увеличивает
// версию, иначе OpenCode не обновит кэш каталога.

import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { loadSkills, ROOT, setVersion, skillHash } from "./lib.ts";

type Lock = Record<string, { version: number; hash: string }>;

const LOCK_PATH = join(ROOT, "skills.lock.json");
const OUT_DIR = join(ROOT, "dist", "catalog");
const checkOnly = process.argv.includes("--check");

const lock: Lock = existsSync(LOCK_PATH) ? JSON.parse(readFileSync(LOCK_PATH, "utf8")) : {};
const nextLock: Lock = {};
const stale: string[] = [];

for (const skill of loadSkills()) {
  if (skill.version === undefined) throw new Error(`${skill.id}: нет metadata.version в SKILL.md`);
  const hash = skillHash(skill);
  const locked = lock[skill.id];
  let version = skill.version;

  if (locked && locked.hash !== hash && version <= locked.version) {
    version = locked.version + 1;
    stale.push(`${skill.id}: ${skill.version} → ${version}`);
    if (!checkOnly) {
      writeFileSync(join(skill.dir, "SKILL.md"), setVersion(skill.source, version));
    }
  }
  nextLock[skill.id] = { version, hash };
}

if (checkOnly) {
  if (stale.length) {
    console.error("Файлы скиллов изменились без подъёма версии:\n  " + stale.join("\n  "));
    console.error("Запустите: npm run build");
    process.exit(1);
  }
  console.log("Версии скиллов актуальны.");
  process.exit(0);
}

writeFileSync(LOCK_PATH, JSON.stringify(nextLock, null, 2) + "\n");
for (const line of stale) console.log(`Версия поднята — ${line}`);

// Каталог: dist/catalog/index.json + dist/catalog/<id>/<id>.md и соседние файлы скилла.
// SKILL.md переименовывается в <id>.md: в V2 корневой SKILL.md в каталоге получает ID «SKILL».
rmSync(OUT_DIR, { recursive: true, force: true });
const index: { skills: { name: string; version: string; files: string[] }[] } = { skills: [] };

for (const skill of loadSkills()) {
  const files: string[] = [];
  for (const file of skill.files) {
    const target = file === "SKILL.md" ? `${skill.id}.md` : file;
    const dest = join(OUT_DIR, skill.id, target);
    mkdirSync(dirname(dest), { recursive: true });
    copyFileSync(join(skill.dir, file), dest);
    files.push(target);
  }
  files.sort((a, b) => (a === `${skill.id}.md` ? -1 : b === `${skill.id}.md` ? 1 : a.localeCompare(b)));
  index.skills.push({ name: skill.id, version: String(skill.version), files });
}

writeFileSync(join(OUT_DIR, "index.json"), JSON.stringify(index, null, 2) + "\n");
console.log(`Каталог собран: ${OUT_DIR} (${index.skills.length} скилла)`);
