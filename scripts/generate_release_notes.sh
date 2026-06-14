#!/bin/sh

set -eu

tag="${1:-}"
output="${2:-release-notes.md}"

[ -n "$tag" ] || {
	echo "Usage: $0 <tag> [output]" >&2
	exit 1
}

repo_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}"
previous_tag="$(git tag --sort=-version:refname --merged "$tag^{}" |
	awk -v current="$tag" '$0 != current { print; exit }')"

if [ -n "$previous_tag" ]; then
	changed_files="$(git diff --name-only "$previous_tag..$tag^{}")"
else
	changed_files="$(git ls-tree -r --name-only "$tag^{}")"
fi

has_path() {
	printf '%s\n' "$changed_files" | grep -Eq "$1"
}

{
	printf '## 主要更新\n\n'
	found=0
	if has_path '^htdocs/'; then
		printf '%s\n' '- 更新 LuCI 页面、交互功能及前端资源。'
		found=1
	fi
	if has_path '^po/'; then
		printf '%s\n' '- 完善简体中文翻译。'
		found=1
	fi
	if has_path '^root/(etc|usr)/'; then
		printf '%s\n' '- 改进 OpenWrt 配置、服务管理及升级兼容逻辑。'
		found=1
	fi
	if has_path '^(Makefile|src/|scripts/|\.github/)'; then
		printf '%s\n' '- 更新构建、打包及自动发布流程。'
		found=1
	fi
	if has_path '^tests/'; then
		printf '%s\n' '- 补充自动化测试与回归检查。'
		found=1
	fi
	if has_path '^(README|docs/)'; then
		printf '%s\n' '- 更新安装和使用文档。'
		found=1
	fi
	[ "$found" -eq 1 ] || printf '%s\n' '- 常规维护与兼容性更新。'

	cat <<'EOF'

## 安装包

- OpenWrt 23.05 / 24.10：安装标有 `23.05-24.10` 的 IPK 主包及中文语言包。
- OpenWrt 25.12+：安装标有 `25.12+` 的 APK 主包及中文语言包。
- 文件完整性请使用 `sha256sums.txt` 校验。

## 升级提示

升级会保留 `/etc/config/nezha-agent` 和 `/etc/nezha-agent/config.yml`。建议升级前自行备份这两个配置文件。
EOF

	if [ -n "$previous_tag" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
		printf '\n**完整变更记录**：%s/compare/%s...%s\n' "$repo_url" "$previous_tag" "$tag"
	fi
} > "$output"
