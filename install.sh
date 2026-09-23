#!/usr/bin/env bash
# Установка учебного режима PurpleSchool для OpenCode (macOS / Linux).
#
#   ./install.sh               агент student и 4 скилла глобально, симлинками
#   ./install.sh --default     плюс "default_agent": "student" в opencode.json
#   ./install.sh --copy        копии вместо симлинков
#   ./install.sh --uninstall   удалить то, что поставил скрипт, и вернуть бэкапы
#
# Нужны только bash и git. sudo не нужен.

set -euo pipefail

KIT="purpleschool-learning-kit"
SKILLS=(hint-ladder code-review debug-coach explain-code)
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

MODE=link
SET_DEFAULT=0
UNINSTALL=0
ASSUME_YES=0
FORCE_VERSION=""
CONFIG_DIR="${OPENCODE_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"

usage() {
  cat <<EOF
Использование: ./install.sh [флаги]

  --default           сделать student агентом по умолчанию (default_agent в opencode.json)
  --copy              копировать файлы вместо симлинков
  --uninstall         удалить установленное и вернуть бэкапы
  --yes, -y           не спрашивать подтверждения при замене чужих файлов
  --v1 | --v2         не определять версию OpenCode, а взять указанную
  --config-dir DIR    папка конфига OpenCode (по умолчанию $CONFIG_DIR)
  -h, --help          эта справка
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --default) SET_DEFAULT=1 ;;
    --copy) MODE=copy ;;
    --uninstall) UNINSTALL=1 ;;
    --yes | -y) ASSUME_YES=1 ;;
    --v1) FORCE_VERSION=1 ;;
    --v2) FORCE_VERSION=2 ;;
    --config-dir)
      [ $# -ge 2 ] || { echo "--config-dir: не указана папка" >&2; exit 2; }
      CONFIG_DIR="$2"
      shift
      ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Неизвестный флаг: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

STATE_DIR="$CONFIG_DIR/.$KIT"
MANIFEST="$STATE_DIR/manifest.tsv"
CONFIG_STATE="$STATE_DIR/opencode-json.state"
CREATED_DIRS="$STATE_DIR/created-dirs"

info() { printf '  %s\n' "$*"; }
ok() { printf '✓ %s\n' "$*"; }
warn() { printf '! %s\n' "$*" >&2; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  if { : >/dev/tty; } 2>/dev/null; then
    local answer
    printf '%s [y/N] ' "$1" >/dev/tty
    read -r answer </dev/tty || return 1
    case "$answer" in [yYдД]*) return 0 ;; esac
    return 1
  fi
  warn "Нет терминала для подтверждения — пропускаю. Запустите с --yes, чтобы заменить."
  return 1
}

checksum() { cksum <"$1" | awk '{print $1 "-" $2}'; }

# Путь, на который указывает симлинк, в абсолютной форме.
link_target() {
  local target
  target="$(readlink "$1")" || return 1
  case "$target" in /*) ;; *) target="$(dirname "$1")/$target" ;; esac
  printf '%s\n' "$target"
}

points_into_repo() {
  [ -L "$1" ] || return 1
  case "$(link_target "$1")" in "$REPO"/*) return 0 ;; esac
  return 1
}

# Поле из manifest.tsv (kind, dest, mode, backup) для заданного dest.
manifest_field() {
  [ -f "$MANIFEST" ] || return 1
  awk -F '\t' -v dest="$1" -v col="$2" '$2 == dest { print $col; found = 1 } END { exit !found }' "$MANIFEST"
}

is_ours() {
  points_into_repo "$1" && return 0
  manifest_field "$1" 2 >/dev/null && return 0
  return 1
}

# ---------------------------------------------------------------------------
# Удаление
# ---------------------------------------------------------------------------

restore_config() {
  [ -f "$CONFIG_STATE" ] || return 0
  local file prev sum
  file="$(sed -n 's/^file=//p' "$CONFIG_STATE")"
  prev="$(sed -n 's/^prev=//p' "$CONFIG_STATE")"
  sum="$(sed -n 's/^sum=//p' "$CONFIG_STATE")"

  if [ ! -f "$file" ]; then
    warn "$file не найден — нечего возвращать"
  elif [ "$(checksum "$file")" = "$sum" ]; then
    # Файл не меняли после установки — возвращаем бэкап как есть.
    if [ "$prev" = "__nofile__" ]; then
      rm -f "$file"
      ok "Удалён $file (его не было до установки)"
    else
      mv -f "$file.bak" "$file"
      ok "Восстановлен $file из $file.bak"
    fi
  else
    # Файл меняли после установки — трогаем только строку default_agent.
    local tmp="$file.tmp.$$"
    if [ "$prev" = "__none__" ]; then
      sed '/^[[:space:]]*"default_agent"[[:space:]]*:[[:space:]]*"student"[[:space:]]*,\{0,1\}[[:space:]]*$/d' "$file" >"$tmp"
    else
      local escaped
      escaped="$(printf '%s' "$prev" | sed 's/[\/&]/\\&/g')"
      sed "s/\"default_agent\"[[:space:]]*:[[:space:]]*\"student\"/\"default_agent\": \"$escaped\"/" "$file" >"$tmp"
    fi
    mv -f "$tmp" "$file"
    ok "Из $file убрана только настройка default_agent: файл менялся после установки, бэкап оставлен в $file.bak"
  fi
  rm -f "$CONFIG_STATE"
}

uninstall() {
  [ -f "$MANIFEST" ] || [ -f "$CONFIG_STATE" ] || die "Установка $KIT в $CONFIG_DIR не найдена"

  if [ -f "$MANIFEST" ]; then
    local kind dest mode backup
    while IFS=$'\t' read -r kind dest mode backup; do
      [ -n "$dest" ] || continue
      if [ -L "$dest" ] && ! points_into_repo "$dest"; then
        warn "$dest — симлинк не на этот репозиторий, не трогаю"
        continue
      fi
      if [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -rf "$dest"
        ok "Удалён $kind: $dest"
      fi
      if [ "$backup" != "-" ] && [ -e "$backup" ]; then
        mv "$backup" "$dest"
        ok "Возвращён прежний $kind: $dest"
      fi
    done <"$MANIFEST"
    rm -f "$MANIFEST"
  fi

  restore_config

  rm -rf "$STATE_DIR/backup"
  local created=""
  if [ -f "$CREATED_DIRS" ]; then
    created="$(cat "$CREATED_DIRS")"
    rm -f "$CREATED_DIRS"
  fi
  rmdir "$STATE_DIR" 2>/dev/null || true
  # Папки, которые создал установщик, удаляем, только если они пустые (с конца: сначала вложенные).
  local dir
  printf '%s\n' "$created" | sed '1!G;h;$!d' | while IFS= read -r dir; do
    [ -n "$dir" ] && rmdir "$dir" 2>/dev/null || true
  done
  echo
  ok "$KIT удалён"
}

# ---------------------------------------------------------------------------
# Установка
# ---------------------------------------------------------------------------

detect_version() {
  if [ -n "$FORCE_VERSION" ]; then
    OC_VERSION="$FORCE_VERSION"
    info "Версия OpenCode задана флагом: V$OC_VERSION"
    return
  fi
  command -v opencode >/dev/null 2>&1 ||
    die "OpenCode не найден. Установите его: https://opencode.ai — или укажите версию флагом --v1 / --v2"
  local raw major
  raw="$(opencode --version 2>/dev/null | head -n 1)"
  major="$(printf '%s' "$raw" | sed -n 's/^[^0-9]*\([0-9][0-9]*\)\..*/\1/p')"
  [ -n "$major" ] || die "Не удалось определить версию OpenCode из «$raw». Укажите её флагом --v1 или --v2"
  if [ "$major" -ge 2 ]; then OC_VERSION=2; else OC_VERSION=1; fi
  ok "OpenCode $raw → формат V$OC_VERSION"
}

NEW_MANIFEST=""
BACKUP_DIR=""

# install_item <kind> <src> <dest>
install_item() {
  local kind="$1" src="$2" dest="$3" backup="-"

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if is_ours "$dest"; then
      backup="$(manifest_field "$dest" 4 2>/dev/null || echo -)"
      rm -rf "$dest"
    elif confirm "$kind «$(basename "$dest")» уже есть в $(dirname "$dest"). Заменить (старый уйдёт в бэкап)?"; then
      backup="$BACKUP_DIR/$(basename "$(dirname "$dest")")/$(basename "$dest")"
      mkdir -p "$(dirname "$backup")"
      mv "$dest" "$backup"
      info "бэкап: $backup"
    else
      warn "Пропущен $kind: $dest"
      return
    fi
  fi

  if [ "$MODE" = link ]; then
    ln -s "$src" "$dest"
  else
    cp -R "$src" "$dest"
  fi
  NEW_MANIFEST+="$kind"$'\t'"$dest"$'\t'"$MODE"$'\t'"$backup"$'\n'
  ok "$kind: $dest"
}

set_default_agent() {
  local file="$CONFIG_DIR/opencode.json"
  [ -f "$file" ] || [ ! -f "$CONFIG_DIR/opencode.jsonc" ] || file="$CONFIG_DIR/opencode.jsonc"

  local prev
  if [ -f "$CONFIG_STATE" ]; then
    # Уже ставили default_agent раньше — бэкап не перезаписываем, иначе потеряем исходный файл.
    prev="$(sed -n 's/^prev=//p' "$CONFIG_STATE")"
  elif [ ! -f "$file" ]; then
    prev="__nofile__"
  else
    prev="$(sed -n 's/.*"default_agent"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n 1)"
    [ -n "$prev" ] || prev="__none__"
    cp "$file" "$file.bak"
    info "бэкап: $file.bak"
  fi

  local tmp="$file.tmp.$$"
  if [ ! -f "$file" ] || [ -z "$(tr -d '[:space:]' <"$file")" ] || [ "$(tr -d '[:space:]' <"$file")" = "{}" ]; then
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "default_agent": "student"\n}\n' >"$tmp"
  elif grep -q '"default_agent"' "$file"; then
    sed 's/"default_agent"[[:space:]]*:[[:space:]]*"[^"]*"/"default_agent": "student"/' "$file" >"$tmp"
  else
    # Вставляем отдельной строкой сразу после первой «{» — остальной файл не трогаем.
    awk '!done && /\{/ { sub(/\{/, "{\n  \"default_agent\": \"student\","); done = 1 } { print }' "$file" >"$tmp"
  fi
  mv -f "$tmp" "$file"

  printf 'file=%s\nprev=%s\nsum=%s\n' "$file" "$prev" "$(checksum "$file")" >"$CONFIG_STATE"
  ok "default_agent: student → $file"
}

install() {
  echo "Установка $KIT в $CONFIG_DIR"
  detect_version

  local dir created=()
  for dir in "$CONFIG_DIR" "$CONFIG_DIR/agents" "$CONFIG_DIR/skills"; do
    [ -d "$dir" ] || created+=("$dir")
  done
  mkdir -p "$CONFIG_DIR/agents" "$CONFIG_DIR/skills" "$STATE_DIR"
  for dir in ${created[@]+"${created[@]}"}; do
    printf '%s\n' "$dir" >>"$CREATED_DIRS"
  done
  BACKUP_DIR="$STATE_DIR/backup/$(date +%Y%m%d-%H%M%S)"

  local id
  for id in "${SKILLS[@]}"; do
    install_item "скилл" "$REPO/skills/$id" "$CONFIG_DIR/skills/$id"
  done

  local agent_src="$REPO/agents/student.md"
  [ "$OC_VERSION" = 2 ] || agent_src="$REPO/agents/v1/student.md"
  install_item "агент" "$agent_src" "$CONFIG_DIR/agents/student.md"

  # Записи старого манифеста, которые не переустанавливали (например, пропущенные), сохраняем.
  if [ -f "$MANIFEST" ]; then
    local kind dest mode backup
    while IFS=$'\t' read -r kind dest mode backup; do
      [ -n "$dest" ] || continue
      case "$NEW_MANIFEST" in *$'\t'"$dest"$'\t'*) continue ;; esac
      NEW_MANIFEST+="$kind"$'\t'"$dest"$'\t'"$mode"$'\t'"$backup"$'\n'
    done <"$MANIFEST"
  fi
  printf '%s' "$NEW_MANIFEST" >"$MANIFEST"
  rmdir "$BACKUP_DIR" 2>/dev/null || true

  [ "$SET_DEFAULT" = 0 ] || set_default_agent

  echo
  echo "Готово. Как проверить:"
  echo "  1. Откройте OpenCode в папке своего проекта: opencode"
  if [ "$SET_DEFAULT" = 1 ]; then
    echo "  2. Агент student включится сам (он по умолчанию); Tab переключает агентов."
  else
    echo "  2. Нажмите Tab — в списке агентов появится student."
  fi
  echo "  3. Наберите / — в списке команд будут hint-ladder, code-review, debug-coach, explain-code."
  if [ "$MODE" = link ]; then
    echo "Обновление: git pull в $REPO — переустанавливать не нужно."
  else
    echo "Обновление: git pull в $REPO и снова ./install.sh --copy"
  fi
}

if [ "$UNINSTALL" = 1 ]; then uninstall; else install; fi
