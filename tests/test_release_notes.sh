#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/nezha-release-notes-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

git -C "$TMP" init -q
git -C "$TMP" config user.name test
git -C "$TMP" config user.email test@example.com

printf 'one\n' > "$TMP/file"
git -C "$TMP" add file
git -C "$TMP" commit -qm '初始版本'
git -C "$TMP" tag v1.0.0

mkdir -p "$TMP/htdocs" "$TMP/po/zh_Hans" "$TMP/tests"
printf 'page\n' > "$TMP/htdocs/config.js"
printf 'translation\n' > "$TMP/po/zh_Hans/app.po"
printf 'test\n' > "$TMP/tests/test.sh"
git -C "$TMP" add htdocs po tests
git -C "$TMP" commit -qm 'Add feature with an English commit title'
git -C "$TMP" tag v1.1.0

(
	cd "$TMP"
	GITHUB_REPOSITORY=example/project \
		sh "$ROOT/scripts/generate_release_notes.sh" v1.1.0 notes.md
)

grep -q '^## 主要更新$' "$TMP/notes.md"
grep -q '^- 更新 LuCI 页面、交互功能及前端资源。$' "$TMP/notes.md"
grep -q '^- 完善简体中文翻译。$' "$TMP/notes.md"
grep -q '^- 补充自动化测试与回归检查。$' "$TMP/notes.md"
! grep -q 'English commit title' "$TMP/notes.md"
grep -q '^## 安装包$' "$TMP/notes.md"
grep -q '^## 升级提示$' "$TMP/notes.md"
grep -q 'https://github.com/example/project/compare/v1.0.0...v1.1.0' "$TMP/notes.md"

echo "release notes tests passed"
