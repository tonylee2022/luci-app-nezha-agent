#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/nezha-manager-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

cat > "$TMP/uci" <<'EOF'
#!/bin/sh
key="${3##*.}"
case "$key" in
	config_file) printf '%s\n' "$TEST_CONFIG" ;;
	server) printf '%s\n' "monitor.example.com:5555" ;;
	client_secret) printf '%s\n' "secret'value" ;;
	tls|disable_command_execute) printf '1\n' ;;
	insecure_tls|disable_auto_update|disable_force_update|disable_nat|disable_send_query) printf '0\n' ;;
	report_delay) printf '4\n' ;;
	custom_ip_api) printf '%s\n' "${TEST_CUSTOM_IP_API:-}" ;;
	*) exit 1 ;;
esac
EOF
chmod 0755 "$TMP/uci"

export TEST_CONFIG="$TMP/config.yml"
printf '%s\n' 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee' > "$TMP/random-uuid"
export UUID_SOURCE="$TMP/random-uuid"
export TEST_CUSTOM_IP_API="https://api.example.com/ip https://api.example.com/user's-ip"
cat > "$TEST_CONFIG" <<'EOF'
uuid: '12345678-1234-1234-1234-123456789abc'
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

# A missing config gets a UUID from the system random source.
rm -f "$TEST_CONFIG"
UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config
grep -q "^uuid: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'$" "$TEST_CONFIG"

# The config file is the only UUID source after first generation.
sed -i "s/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee/12345678-1234-1234-1234-123456789abc/" "$TEST_CONFIG"
UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config
grep -q "^uuid: '12345678-1234-1234-1234-123456789abc'$" "$TEST_CONFIG"

# Existing UUID text is preserved without manager-side validation.
sed -i "s/12345678-1234-1234-1234-123456789abc/manually-managed-id/" "$TEST_CONFIG"
UCI_BIN="$TMP/uci" "$ROOT/root/usr/libexec/nezha-agent-manager" sync-config
grep -q "^uuid: 'manually-managed-id'$" "$TEST_CONFIG"

echo "manager tests passed"
