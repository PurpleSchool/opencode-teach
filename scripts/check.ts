// Проверяет, что набор соответствует требованиям ТЗ:
// frontmatter и разделы скиллов, совпадение агентов V1 и V2, права на скиллы набора.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { AGENTS_DIR, loadSkills, SKILL_SECTIONS, splitFrontmatter } from "./lib.ts";

const errors: string[] = [];
const NAME = /^[a-z0-9]+(-[a-z0-9]+)*$/;

const skills = loadSkills();
for (const skill of skills) {
  const where = `skills/${skill.id}/SKILL.md`;
  if (!NAME.test(skill.id)) errors.push(`${where}: ID должен быть строчной латиницей через дефис`);
  if (skill.name !== skill.id) errors.push(`${where}: name «${skill.name}» не совпадает с папкой`);
  if (!skill.description) errors.push(`${where}: нет description`);
  else if (skill.description.length > 1024) errors.push(`${where}: description длиннее 1024 символов`);
  else if (!/[а-яё]/i.test(skill.description)) errors.push(`${where}: description должен быть на русском`);
  if (skill.version === undefined) errors.push(`${where}: нет metadata.version`);
  if (/^slash:\s*false/m.test(skill.frontmatter)) errors.push(`${where}: slash не выключаем`);
  if (/opencode\/autoinvoke/.test(skill.frontmatter)) errors.push(`${where}: opencode/autoinvoke не ставим`);

  const sections = [...skill.body.matchAll(/^## (.+)$/gm)].map((m) => m[1].trim());
  if (sections.join("|") !== SKILL_SECTIONS.join("|")) {
    errors.push(`${where}: разделы ${JSON.stringify(sections)}, ожидаются ${JSON.stringify(SKILL_SECTIONS)}`);
  }
}

const v2 = splitFrontmatter(readFileSync(join(AGENTS_DIR, "student.md"), "utf8"));
const v1 = splitFrontmatter(readFileSync(join(AGENTS_DIR, "v1", "student.md"), "utf8"));
if (v1.body !== v2.body) errors.push("agents/v1/student.md: тело промпта отличается от agents/student.md");
if (!/^permissions:/m.test(v2.frontmatter)) errors.push("agents/student.md: нужен формат V2 (permissions)");
if (!/^permission:/m.test(v1.frontmatter)) errors.push("agents/v1/student.md: нужен формат V1 (permission)");
for (const [file, fm] of [["agents/student.md", v2.frontmatter], ["agents/v1/student.md", v1.frontmatter]]) {
  if (/^model:/m.test(fm)) errors.push(`${file}: модель в агенте не фиксируем`);
  if (!/^mode:\s*primary/m.test(fm)) errors.push(`${file}: нужен mode: primary`);
  for (const skill of skills) {
    if (!fm.includes(`"${skill.id}"`)) errors.push(`${file}: нет разрешения на скилл ${skill.id}`);
    if (!v2.body.includes(`\`${skill.id}\``)) errors.push(`${file}: скилл ${skill.id} не упомянут в промпте`);
  }
}

if (errors.length) {
  console.error(errors.map((e) => `✗ ${e}`).join("\n"));
  process.exit(1);
}
console.log(`✓ ${skills.length} скилла и 2 агента соответствуют требованиям`);
