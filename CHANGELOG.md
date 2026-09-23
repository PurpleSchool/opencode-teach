# Changelog

Формат — [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — [SemVer](https://semver.org/lang/ru/).

## [1.0.0] — 2026-09-23

### Добавлено

- Агент `student` (mode: primary) в форматах V2 (`permissions`) и V1 (`permission`): правки файлов с подтверждения, запуск тестов и программы без подтверждения.
- Скиллы `hint-ladder`, `code-review`, `debug-coach`, `explain-code` (`metadata.version: "1"`).
- Установщики `install.sh` (macOS, Linux) и `install.ps1` (Windows) с флагами `--default`, `--copy`, `--uninstall`, `--yes`.
- Сборка HTTP-каталога для V2 (`npm run build`) с автоматическим подъёмом версий скиллов.
- Проверка набора `npm run check`.
- 5 учебных задач в `examples/` и протокол ручной проверки.
