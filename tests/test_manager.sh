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
	*) exit 1 ;;
esac
EOF
chmod 0755 "$TMP/uci"

export TEST_CONFIG="$TMP/config.yml"
cat > "$TEST_CONFIG" <<'EOF'
uuid: '12345678-1234-1234-1234-123456789abc'
custom_ip_api:
  - https://example.com/ip
temperature: true
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
grep -q '^  - https://example.com/ip$' "$TEST_CONFIG"
grep -q '^temperature: true$' "$TEST_CONFIG"
[ "$(ls -l "$TEST_CONFIG" | cut -c1-10)" = "-rw-------" ]

echo "manager tests passed"
