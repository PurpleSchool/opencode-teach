# purpleschool-learning-kit

Учебный режим PurpleSchool для [OpenCode](https://opencode.ai): агент `student` и 4 скилла, которые помогают писать код, но не решают задачи за студента.

- **Код пишет студент.** Агент подсказывает, проверяет и объясняет. Готовое решение — только по явной просьбе и с предупреждением.
- **Работа с кодом в проекте**, а не теория в отрыве от него.
- **Минимальная достаточная помощь** — ровно столько, чтобы сдвинуться с места.
- **Проверка понимания** — каждый сценарий заканчивается одним вопросом.
- Язык — русский, термины и код — как в оригинале.

Набор один для всех курсов: язык и стек агент определяет по файлам проекта, в котором запущен OpenCode.

## Состав

| ID | Тип | Когда срабатывает | Что делает |
|---|---|---|---|
| `student` | агент, primary | Shift+Tab (в V1 — Tab) или агент по умолчанию | Держит принципы учебного режима, выбирает скилл |
| `hint-ladder` | скилл | «застрял», «не знаю, как дальше», «не получается» | Подсказки по ступеням: направление → конкретнее → фрагмент → решение |
| `code-review` | скилл | «проверь», «посмотри моё решение», «что не так с кодом» | Ревью: работает ли, ошибки, читаемость, что улучшить — с файлом и строкой |
| `debug-coach` | скилл | ошибка, стектрейс, «падает», «не работает» | Воспроизвести → прочитать ошибку → место и причина → как проверить |
| `explain-code` | скилл | «объясни этот код», «что тут происходит» | Разбор по блокам или построчно + вопрос на понимание |

Правило «не решай за студента» живёт в агенте: скилл модель загружает сама и может не загрузить.

Права агента: чтение проекта — свободно; правка файлов — только с подтверждения студента; команды — с подтверждения, кроме запуска тестов и программы (`npm test`, `node …`, `python …`, `pytest`, `go test`, `go run …`, `cargo`, `dotnet`, `mvn`/`gradle test`, `git status`/`git diff`). Модель не фиксируется — используется выбранная студентом.

## Установка

```bash
git clone https://github.com/PurpleSchool/opencode-teach.git
cd opencode-teach
./install.sh
```

Windows (PowerShell):

```powershell
git clone https://github.com/PurpleSchool/opencode-teach.git
cd opencode-teach
.\install.ps1
```

Если PowerShell запрещает запуск скриптов: `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

Скрипт ставит агента и скиллы глобально в `~/.config/opencode/` — они работают во всех проектах. Нужны только bash (или PowerShell) и git, sudo не нужен.

| Флаг `install.sh` | `install.ps1` | Что делает |
|---|---|---|
| `--default` | `-Default` | Прописать `"default_agent": "student"` в `~/.config/opencode/opencode.json` (с бэкапом `opencode.json.bak`, остальные настройки не трогаются) |
| `--copy` | — | Копировать вместо симлинков (в Windows всегда копия) |
| `--uninstall` | `-Uninstall` | Удалить только то, что поставил скрипт, и вернуть бэкапы |
| `--yes` | `-Yes` | Заменять существующие файлы с тем же ID без вопроса (с бэкапом) |
| `--v1` / `--v2` | `-V1` / `-V2` | Не определять версию OpenCode, а взять указанную |
| `--config-dir DIR` | `-ConfigDir DIR` | Другая папка конфига OpenCode |

Что делает установщик:

1. Проверяет, что OpenCode установлен, и определяет версию по `opencode --version`.
2. Создаёт `~/.config/opencode/agents/` и `~/.config/opencode/skills/`, если их нет.
3. Ставит скиллы `skills/<id>` → `~/.config/opencode/skills/<id>`: на macOS и Linux симлинком, в Windows копией.
4. Ставит агента: `agents/student.md` (V2) или `agents/v1/student.md` (V1) → `~/.config/opencode/agents/student.md`.
5. С `--default` делает student агентом по умолчанию.
6. Если скилл или агент с таким ID уже есть и это не наша установка — спрашивает перед заменой и убирает старый в бэкап (`~/.config/opencode/.purpleschool-learning-kit/backup/`).

Что установлено и что было до установки, скрипт записывает в `~/.config/opencode/.purpleschool-learning-kit/` — по этим записям работает `--uninstall`.

### Проверка

1. Если OpenCode V2 уже был запущен, перезапустите фоновый сервис: `opencode service restart`. Он индексирует скиллы и агентов при старте и не замечает новые (`opencode reload` не помогает).
2. Откройте OpenCode в папке своего проекта: `opencode`.
3. Нажмите Shift+Tab (в V1 — Tab) — в списке агентов есть `student`.
4. Наберите `/` — в списке команд есть `hint-ladder`, `code-review`, `debug-coach`, `explain-code`.
5. Напишите «я застрял» — агент загрузит `hint-ladder` и даст первую подсказку без кода.

### Обновление

- macOS, Linux: `git pull` — симлинки подхватят изменения без переустановки.
- Windows или `--copy`: `git pull` и снова `.\install.ps1` / `./install.sh --copy`.

Если изменения не видны в уже запущенном OpenCode V2 — `opencode service restart`.

### Удаление

```bash
./install.sh --uninstall
```

Удаляет только то, что поставил скрипт, возвращает заменённые файлы и `opencode.json`. Если `opencode.json` менялся после установки, скрипт не откатывает весь файл, а убирает только `default_agent` (прежний `opencode.json.bak` остаётся рядом).

## Другие способы установки

| Способ | Версии OpenCode | Обновления | Когда использовать |
|---|---|---|---|
| Клон + скрипт (основной) | V1 и V2 | `git pull` (симлинки) или повторный запуск | Урок «Развёртка», все студенты |
| Шаблон проекта курса | V1 и V2 | С обновлением репозитория | Курсы с общим стартовым проектом |
| HTTP-каталог | V2 | Автоматически по `version` | Обновлять скиллы без действий студента |

### Шаблон проекта курса

Положите агента и скиллы в `.opencode/` стартового репозитория курса:

```bash
mkdir -p <проект>/.opencode/agents <проект>/.opencode/skills
cp agents/student.md <проект>/.opencode/agents/student.md   # для V1: agents/v1/student.md
cp -R skills/* <проект>/.opencode/skills/
```

Проектный `.opencode/skills` перекрывает глобальные скиллы с тем же ID.

### Ручная установка на V1

Скилл в V1 ищется как `~/.config/opencode/skills/<name>/SKILL.md`, и `name` должен совпадать с папкой — исходники уже в этой форме.

```bash
mkdir -p ~/.config/opencode/agents ~/.config/opencode/skills
cp agents/v1/student.md ~/.config/opencode/agents/student.md
cp -R skills/* ~/.config/opencode/skills/
```

### HTTP-каталог (V2)

```bash
npm run build   # → dist/catalog/index.json и dist/catalog/<id>/<id>.md
```

Опубликуйте `dist/catalog/` на любом статическом хостинге и добавьте URL в глобальный `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["https://<host>/purpleschool-learning-kit/catalog/"]
}
```

В каталоге файл скилла называется `<id>.md`, а не `SKILL.md`: в V2 корневой `SKILL.md` в каталоге получает ID `SKILL`. Записи из массива `skills` перекрывают все остальные источники.

## Где OpenCode ищет файлы

- **Скиллы V2:** `~/.config/opencode/skills`, `.opencode/skills` в проекте, совместимые `~/.claude/skills` и `~/.agents/skills`, плюс источники из массива `skills` (локальные пути и HTTP-каталоги).
- **Скиллы V1:** `~/.config/opencode/skills/<name>/SKILL.md` и `.opencode/skills/<name>/SKILL.md`.
- **Агенты:** `~/.config/opencode/agents/<name>.md` глобально, `.opencode/agents/<name>.md` в проекте; имя файла = ID агента.
- **Приоритет:** при совпадении ID побеждает источник, зарегистрированный позже: проектный `.opencode/skills` перекрывает глобальный, а записи из массива `skills` — всё остальное.

## Разработка

```
agents/student.md        агент, формат V2 (permissions)
agents/v1/student.md     тот же агент, формат V1 (permission) — тело промпта должно совпадать
skills/<id>/SKILL.md     скиллы: 5 разделов в фиксированном порядке
scripts/check.ts         проверка набора на требования
scripts/build-catalog.ts сборка HTTP-каталога и подъём версий
skills.lock.json         хеши скиллов на момент последней версии
examples/                учебные задачи и протокол ручной проверки
```

Нужен Node.js 22.18+ (скрипты на TypeScript запускаются без сборки).

```bash
npm run check   # frontmatter, разделы, совпадение агентов V1/V2, актуальность версий
npm run build   # поднять версии изменённых скиллов и собрать dist/catalog/
```

Каждый `SKILL.md` содержит разделы: «Когда использовать», «Запреты», «Процесс», «Формат ответа», «Когда закончить». `description` — на русском, 1–2 предложения с фразами студентов: по нему модель решает, загружать ли скилл. `slash` не выключаем и `opencode/autoinvoke` не ставим.

Версионирование:
- репозиторий — SemVer, теги `v1.0.0`; каждое изменение — запись в [CHANGELOG.md](CHANGELOG.md);
- скилл — `metadata.version` растёт при любом изменении файлов скилла. `npm run build` делает это сам по хешу из `skills.lock.json`, `npm run check` падает, если версию забыли поднять. Без подъёма версии OpenCode не обновит кэш HTTP-каталога.

Правите агента — меняйте тело в обоих файлах (`agents/student.md` и `agents/v1/student.md`); `npm run check` сверит их.

Ручная проверка поведения — по [examples/README.md](examples/README.md).
