#!/bin/sh
set -eu

# Local debugging helper. Official release packages are built with the
# OpenWrt SDK workflow and include a separate LuCI translation package.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
PKG_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${1:-$PKG_DIR/dist}"
TARGET_ARCH="${2:-$(uname -m)}"
PKG_NAME="luci-app-nezha-agent"
PKG_VERSION="1.2.0"
PKG_RELEASE="1"

case "$OUT_DIR" in /*) ;; *) OUT_DIR="$PKG_DIR/$OUT_DIR" ;; esac

case "$TARGET_ARCH" in
	x86_64|amd64)
		OPENWRT_ARCH="x86_64"; AGENT_ARCH="amd64"
		;;
	i386|i486|i586|i686|x86|386)
		OPENWRT_ARCH="i386_pentium4"; AGENT_ARCH="386"
		;;
	aarch64|arm64)
		OPENWRT_ARCH="aarch64_generic"; AGENT_ARCH="arm64"
		;;
	arm|armv5*|armv6*|armv7*|armhf)
		OPENWRT_ARCH="arm_cortex-a7"; AGENT_ARCH="arm"
		;;
	mips)
		OPENWRT_ARCH="mips_24kc"; AGENT_ARCH="mips"
		;;
	mipsel|mipsle)
		OPENWRT_ARCH="mipsel_24kc"; AGENT_ARCH="mipsle"
		;;
	riscv64)
		OPENWRT_ARCH="riscv64_riscv64"; AGENT_ARCH="riscv64"
		;;
	loongarch64|loong64)
		OPENWRT_ARCH="loongarch64_generic"; AGENT_ARCH="loong64"
		;;
	s390x)
		OPENWRT_ARCH="s390x"; AGENT_ARCH="s390x"
		;;
	*) echo "Unsupported architecture: $TARGET_ARCH" >&2; exit 1 ;;
esac

mkdir -p "$OUT_DIR"
STAGING="$(mktemp -d /tmp/nezha-ipk.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT INT TERM
ASSET="nezha-agent_linux_${AGENT_ARCH}.zip"

AGENT_TAG="$(curl -fsSL https://api.github.com/repos/nezhahq/agent/releases/latest |
	sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
[ -n "$AGENT_TAG" ] || { echo "Unable to resolve latest Agent release" >&2; exit 1; }
AGENT_VERSION="${AGENT_TAG#v}"
curl -fL --retry 3 -o "$STAGING/checksums.txt" \
	"https://github.com/nezhahq/agent/releases/download/${AGENT_TAG}/checksums.txt"
AGENT_HASH="$(awk -v file="$ASSET" '$2 == file { print $1; exit }' "$STAGING/checksums.txt")"
[ -n "$AGENT_HASH" ] || { echo "Checksum not found for $ASSET" >&2; exit 1; }

echo "Downloading Nezha Agent v${AGENT_VERSION} for ${AGENT_ARCH}..."
curl -fL --retry 3 -o "$STAGING/$ASSET" \
	"https://github.com/nezhahq/agent/releases/download/${AGENT_TAG}/${ASSET}"
ACTUAL_HASH="$(sha256sum "$STAGING/$ASSET" | awk '{print $1}')"
[ "$ACTUAL_HASH" = "$AGENT_HASH" ] || { echo "SHA-256 mismatch" >&2; exit 1; }
unzip -q "$STAGING/$ASSET" -d "$STAGING/agent"

DATA="$STAGING/data"
mkdir -p "$DATA/etc/config" "$DATA/etc/init.d" "$DATA/usr/bin" "$DATA/usr/libexec"
mkdir -p "$DATA/etc/uci-defaults"
mkdir -p "$DATA/usr/share/luci/menu.d" "$DATA/usr/share/rpcd/acl.d"
mkdir -p "$DATA/www/luci-static/resources/view/nezha-agent"
mkdir -p "$DATA/www/luci-static/resources/nezha-agent"
cp "$PKG_DIR/root/etc/config/nezha-agent" "$DATA/etc/config/nezha-agent"
cp "$PKG_DIR/root/etc/init.d/nezha-agent" "$DATA/etc/init.d/nezha-agent"
cp "$PKG_DIR/root/etc/uci-defaults/99-nezha-agent" "$DATA/etc/uci-defaults/99-nezha-agent"
cp "$PKG_DIR/root/usr/libexec/nezha-agent-manager" "$DATA/usr/libexec/nezha-agent-manager"
cp "$PKG_DIR/root/usr/share/luci/menu.d/luci-app-nezha-agent.json" "$DATA/usr/share/luci/menu.d/"
cp "$PKG_DIR/root/usr/share/rpcd/acl.d/luci-app-nezha-agent.json" "$DATA/usr/share/rpcd/acl.d/"
cp "$PKG_DIR/htdocs/luci-static/resources/view/nezha-agent/config.js" \
	"$DATA/www/luci-static/resources/view/nezha-agent/config.js"
cp "$PKG_DIR/htdocs/luci-static/resources/nezha-agent/import-parser.js" \
	"$DATA/www/luci-static/resources/nezha-agent/import-parser.js"
cp "$STAGING/agent/nezha-agent" "$DATA/usr/bin/nezha-agent"
chmod 0755 "$DATA/etc/init.d/nezha-agent" "$DATA/etc/uci-defaults/99-nezha-agent" \
	"$DATA/usr/libexec/nezha-agent-manager" "$DATA/usr/bin/nezha-agent"

INSTALLED_SIZE="$(du -sk "$DATA" | awk '{print $1}')"
(cd "$DATA" && tar czf "$STAGING/data.tar.gz" .)

CONTROL="$STAGING/control"
mkdir -p "$CONTROL"
cat > "$CONTROL/control" <<EOF
Package: $PKG_NAME
Version: $PKG_VERSION-$PKG_RELEASE
Depends: luci-base, ca-bundle
Section: luci
Architecture: $OPENWRT_ARCH
Installed-Size: $INSTALLED_SIZE
Maintainer: OpenWrt LuCI Community
License: MIT Apache-2.0
Description: LuCI support and packaged binary for Nezha Agent
EOF
printf '/etc/config/nezha-agent\n' > "$CONTROL/conffiles"
cat > "$CONTROL/postinst" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	[ ! -f /etc/uci-defaults/99-nezha-agent ] || {
		( . /etc/uci-defaults/99-nezha-agent ) && rm -f /etc/uci-defaults/99-nezha-agent
	}
	/etc/init.d/nezha-agent enable 2>/dev/null || true
	rm -f /tmp/luci-indexcache.* /tmp/luci-modulecache/* 2>/dev/null
	/etc/init.d/rpcd reload 2>/dev/null || true
}
exit 0
EOF
chmod 0755 "$CONTROL/postinst"
cat > "$CONTROL/prerm" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	/etc/init.d/nezha-agent stop 2>/dev/null || true
	/etc/init.d/nezha-agent disable 2>/dev/null || true
}
exit 0
EOF
chmod 0755 "$CONTROL/prerm"
cat > "$CONTROL/postrm" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] || {
	rm -f /tmp/luci-indexcache.* 2>/dev/null
	rm -rf /tmp/luci-modulecache 2>/dev/null
	/etc/init.d/rpcd reload 2>/dev/null || true
	printf '%s\n' 'Nezha Agent configuration was retained.'
	printf '%s\n' 'Remove it manually if no longer needed:'
	printf '%s\n' '  rm -f /etc/config/nezha-agent /etc/config/nezha-agent-opkg'
	printf '%s\n' '  rm -rf /etc/nezha-agent'
}
exit 0
EOF
chmod 0755 "$CONTROL/postrm"
(cd "$CONTROL" && tar czf "$STAGING/control.tar.gz" .)
printf '2.0\n' > "$STAGING/debian-binary"

IPK="$OUT_DIR/${PKG_NAME}_${PKG_VERSION}-${PKG_RELEASE}_${OPENWRT_ARCH}.ipk"
rm -f "$IPK"
(cd "$STAGING" && tar czf "$IPK" debian-binary control.tar.gz data.tar.gz)

echo "Built: $IPK"
echo "Agent: v$AGENT_VERSION linux/$AGENT_ARCH"
