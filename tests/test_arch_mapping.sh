#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
MAKEFILE="$ROOT/Makefile"

assert_mapping() {
	local openwrt_arch="$1" release_arch="$2" block

	block="$(awk -v arch="$openwrt_arch" '
		$0 ~ "^ifeq \\(\\$\\(ARCH\\)," arch "\\)$" ||
		$0 ~ "^else ifeq \\(\\$\\(ARCH\\)," arch "\\)$" { found=1; next }
		found && /^else ifeq / { exit }
		found && /^endif/ { exit }
		found { print }
	' "$MAKEFILE")"

	printf '%s\n' "$block" | grep -q "NEZHA_AGENT_ARCH:=$release_arch"
}

assert_mapping x86_64 amd64
assert_mapping i386 386
assert_mapping aarch64 arm64
assert_mapping arm arm
assert_mapping mips mips
assert_mapping mipsel mipsle
assert_mapping riscv64 riscv64
assert_mapping loongarch64 loong64
assert_mapping s390x s390x

grep -q '^PKG_SOURCE:=nezha-agent_linux_$(NEZHA_AGENT_ARCH).zip$' "$MAKEFILE"
grep -q '^PKG_SOURCE_URL:=https://github.com/nezhahq/agent/releases/download/$(NEZHA_AGENT_TAG)$' "$MAKEFILE"
grep -q '^NEZHA_AGENT_TAG?=' "$MAKEFILE"
grep -q '^NEZHA_AGENT_HASH?=' "$MAKEFILE"
grep -q '^PKG_HASH:=$(NEZHA_AGENT_HASH)$' "$MAKEFILE"
grep -q '^compile: all$' "$ROOT/src/Makefile"

echo "architecture mapping tests passed"
