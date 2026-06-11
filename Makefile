include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-nezha-agent
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_PO_VERSION:=$(PKG_VERSION)

PKG_LICENSE:=MIT Apache-2.0
PKG_MAINTAINER:=OpenWrt LuCI Community

NEZHA_AGENT_TAG?=$(strip $(shell curl -fsSL https://api.github.com/repos/nezhahq/agent/releases/latest 2>/dev/null | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1))
NEZHA_AGENT_VERSION:=$(patsubst v%,%,$(NEZHA_AGENT_TAG))

ifeq ($(ARCH),x86_64)
  NEZHA_AGENT_ARCH:=amd64
else ifeq ($(ARCH),i386)
  NEZHA_AGENT_ARCH:=386
else ifeq ($(ARCH),aarch64)
  NEZHA_AGENT_ARCH:=arm64
else ifeq ($(ARCH),arm)
  NEZHA_AGENT_ARCH:=arm
else ifeq ($(ARCH),mips)
  NEZHA_AGENT_ARCH:=mips
else ifeq ($(ARCH),mipsel)
  NEZHA_AGENT_ARCH:=mipsle
else ifeq ($(ARCH),riscv64)
  NEZHA_AGENT_ARCH:=riscv64
else ifeq ($(ARCH),loongarch64)
  NEZHA_AGENT_ARCH:=loong64
else ifeq ($(ARCH),s390x)
  NEZHA_AGENT_ARCH:=s390x
endif

ifneq ($(ARCH),)
  ifeq ($(NEZHA_AGENT_ARCH),)
    $(error Unsupported OpenWrt architecture: $(ARCH))
  endif
endif

PKG_SOURCE:=nezha-agent_linux_$(NEZHA_AGENT_ARCH).zip
PKG_SOURCE_URL:=https://github.com/nezhahq/agent/releases/download/$(NEZHA_AGENT_TAG)
NEZHA_AGENT_HASH?=$(strip $(shell curl -fsSL https://github.com/nezhahq/agent/releases/download/$(NEZHA_AGENT_TAG)/checksums.txt 2>/dev/null | awk '$$2 == "$(PKG_SOURCE)" { print $$1; exit }'))
PKG_HASH:=$(NEZHA_AGENT_HASH)

LUCI_TITLE:=LuCI support for Nezha Agent
LUCI_DEPENDS:=+luci-base +ca-bundle
include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
