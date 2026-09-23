import { createHash } from "node:crypto";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

export const ROOT = join(import.meta.dirname, "..");
export const SKILLS_DIR = join(ROOT, "skills");
export const AGENTS_DIR = join(ROOT, "agents");

export const SKILL_SECTIONS = [
  "Когда использовать",
  "Запреты",
  "Процесс",
  "Формат ответа",
  "Когда закончить",
];

const VERSION_LINE = /^(\s+version:\s*)"?(\d+)"?\s*$/m;

export interface Skill {
  id: string;
  dir: string;
  source: string;
  frontmatter: string;
  body: string;
  name: string | undefined;
  description: string | undefined;
  version: number | undefined;
  files: string[];
}

export function splitFrontmatter(source: string): { frontmatter: string; body: string } {
  const match = source.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!match) return { frontmatter: "", body: source };
  return { frontmatter: match[1], body: match[2] };
}

function field(frontmatter: string, key: string): string | undefined {
  const match = frontmatter.match(new RegExp(`^${key}:\\s*(.+)$`, "m"));
  return match?.[1].trim().replace(/^"(.*)"$/, "$1");
}

function listFiles(dir: string): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) files.push(...listFiles(full));
    else files.push(relative(dir, full).split(sep).join("/"));
  }
  return files.sort();
}

export function loadSkills(): Skill[] {
  return readdirSync(SKILLS_DIR)
    .filter((id) => statSync(join(SKILLS_DIR, id)).isDirectory())
    .sort()
    .map((id) => {
      const dir = join(SKILLS_DIR, id);
      const source = readFileSync(join(dir, "SKILL.md"), "utf8");
      const { frontmatter, body } = splitFrontmatter(source);
      const version = frontmatter.match(VERSION_LINE)?.[2];
      return {
        id,
        dir,
        source,
        frontmatter,
        body,
        name: field(frontmatter, "name"),
        description: field(frontmatter, "description"),
        version: version === undefined ? undefined : Number(version),
        files: listFiles(dir),
      };
    });
}

/** Хеш всех файлов скилла без учёта строки metadata.version — чтобы сам подъём версии не менял хеш. */
export function skillHash(skill: Skill): string {
  const hash = createHash("sha256");
  for (const file of skill.files) {
    let content = readFileSync(join(skill.dir, file), "utf8");
    if (file === "SKILL.md") content = content.replace(VERSION_LINE, "$1<version>");
    hash.update(file).update("\0").update(content).update("\0");
  }
  return hash.digest("hex");
}

export function setVersion(source: string, version: number): string {
  return source.replace(VERSION_LINE, `$1"${version}"`);
}
