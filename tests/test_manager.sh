#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/nezha-manager-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

cat > "$TMP/uci" <<'EOF'
#!/bin/sh
[ "$1" != -q ] || shift
action="$1"
argument="${2:-}"
key="${argument##*.}"
case "$action:$key" in
	get:config_file) printf '%s\n' "$TEST_CONFIG" ;;
	get:server) printf '%s\n' "monitor.example.com:5555" ;;
	get:client_secret) printf '%s\n' "secret'value" ;;
	get:uuid) [ -f "$TEST_UCI_UUID" ] && cat "$TEST_UCI_UUID" ;;
	get:tls|get:disable_command_execute) printf '1\n' ;;
	get:insecure_tls|get:disable_auto_update|get:disable_force_update|get:disable_nat|get:disable_send_query) printf '0\n' ;;
	get:report_delay) printf '4\n' ;;
	get:custom_ip_api) printf '%s\n' "${TEST_CUSTOM_IP_API:-}" ;;
	set:uuid=*) printf '%s\n' "${argument#*=}" > "$TEST_UCI_UUID" ;;
	commit:*) ;;
	*) exit 1 ;;
esac
EOF
chmod 0755 "$TMP/uci"

export TEST_CONFIG="$TMP/config.yml"
export TEST_UCI_UUID="$TMP/uci-uuid"
printf '%s\n' 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee' > "$TMP/random-uuid"
export UUID_SOURCE="$TMP/random-uuid"
export TEST_CUSTOM_IP_API="https://api.example.com/ip https://api.example.com/user's-ip"
printf '%s\n' '12345678-1234-1234-1234-123456789abc' > "$TEST_UCI_UUID"
cat > "$TEST_CONFIG" <<'EOF'
uuid: 'old-yaml-id'
custom_ip_api:
  - https://old.example.com/ip
temperature: true
unknown_list:
  - first
  - second
unknown_object:
  enabled: true
EOF

UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config

grep -q "^server: 'monitor.example.com:5555'$" "$TEST_CONFIG"
grep -q "^client_secret: 'secret''value'$" "$TEST_CONFIG"
grep -q "^uuid: '12345678-1234-1234-1234-123456789abc'$" "$TEST_CONFIG"
grep -q '^tls: true$' "$TEST_CONFIG"
grep -q '^insecure_tls: false$' "$TEST_CONFIG"
grep -q '^disable_auto_update: false$' "$TEST_CONFIG"
grep -q '^disable_command_execute: true$' "$TEST_CONFIG"
grep -q '^report_delay: 4$' "$TEST_CONFIG"
grep -q '^custom_ip_api:$' "$TEST_CONFIG"
grep -q "^  - 'https://api.example.com/ip'$" "$TEST_CONFIG"
grep -q "^  - 'https://api.example.com/user''s-ip'$" "$TEST_CONFIG"
! grep -q 'old.example.com' "$TEST_CONFIG"
grep -q '^temperature: true$' "$TEST_CONFIG"
grep -q '^unknown_list:$' "$TEST_CONFIG"
grep -q '^  - first$' "$TEST_CONFIG"
grep -q '^  - second$' "$TEST_CONFIG"
grep -q '^unknown_object:$' "$TEST_CONFIG"
grep -q '^  enabled: true$' "$TEST_CONFIG"
[ "$(ls -l "$TEST_CONFIG" | cut -c1-10)" = "-rw-------" ]

# An empty UCI list clears only the managed custom_ip_api block.
TEST_CUSTOM_IP_API='' UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config
grep -q '^custom_ip_api: \[\]$' "$TEST_CONFIG"
! grep -q 'api.example.com' "$TEST_CONFIG"
grep -q '^unknown_list:$' "$TEST_CONFIG"
grep -q '^  - first$' "$TEST_CONFIG"
grep -q '^unknown_object:$' "$TEST_CONFIG"
grep -q '^  enabled: true$' "$TEST_CONFIG"

# An empty UCI UUID gets a UUID from the system random source and persists it.
rm -f "$TEST_CONFIG"
rm -f "$TEST_UCI_UUID"
UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config
grep -q "^uuid: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'$" "$TEST_CONFIG"
[ "$(cat "$TEST_UCI_UUID")" = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee' ]

# The persisted UCI UUID is reused even if the YAML value is edited.
sed -i "s/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/old-yaml-id/" "$TEST_CONFIG"
UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config
grep -q "^uuid: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'$" "$TEST_CONFIG"

# Non-standard identifiers set through UCI remain supported.
printf '%s\n' 'manually-managed-id' > "$TEST_UCI_UUID"
UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config
grep -q "^uuid: 'manually-managed-id'$" "$TEST_CONFIG"

# UUID values containing whitespace are rejected.
printf '%s\n' 'invalid id' > "$TEST_UCI_UUID"
if UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config; then
	echo "manager accepted an invalid UUID" >&2
	exit 1
fi

echo "manager tests passed"
