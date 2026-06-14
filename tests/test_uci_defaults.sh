#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/nezha-defaults-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

mkdir -p "$TMP/bin" "$TMP/etc/nezha-agent"
cat > "$TMP/bin/uci" <<'EOF'
#!/bin/sh
[ "$1" != -q ] || shift
action="$1"
argument="${2:-}"
case "$action:$argument" in
	get:nezha-agent.main.auto_update|get:nezha-agent.main.disable_auto_update) ;;
	get:nezha-agent.main.uuid) [ -f "$TEST_UUID" ] && cat "$TEST_UUID" ;;
	get:nezha-agent.main.config_file) printf '%s\n' "$TEST_CONFIG" ;;
	delete:*) ;;
	set:nezha-agent.main.uuid=*) printf '%s\n' "${argument#*=}" > "$TEST_UUID" ;;
	commit:*) ;;
	*) exit 1 ;;
esac
EOF
chmod 0755 "$TMP/bin/uci"

export TEST_CONFIG="$TMP/etc/nezha-agent/config.yml"
export TEST_UUID="$TMP/uci-uuid"
export UUID_LEGACY_FILE="$TMP/legacy-uuid"
cat > "$TEST_CONFIG" <<'EOF'
uuid: 'existing-yaml-id'
server: 'monitor.example.com:5555'
EOF

PATH="$TMP/bin:$PATH" UUID_LEGACY_FILE="$UUID_LEGACY_FILE" sh "$ROOT/root/etc/uci-defaults/99-nezha-agent"
[ "$(cat "$TEST_UUID")" = 'existing-yaml-id' ]

# An existing UCI UUID wins over the YAML value.
printf '%s\n' 'existing-uci-id' > "$TEST_UUID"
sed -i "s/existing-yaml-id/changed-yaml-id/" "$TEST_CONFIG"
PATH="$TMP/bin:$PATH" UUID_LEGACY_FILE="$UUID_LEGACY_FILE" sh "$ROOT/root/etc/uci-defaults/99-nezha-agent"
[ "$(cat "$TEST_UUID")" = 'existing-uci-id' ]

echo "uci defaults tests passed"
