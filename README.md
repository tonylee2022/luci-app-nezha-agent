# luci-app-nezha-agent

适用于 OpenWrt 的哪吒监控 Agent LuCI 管理插件，采用现代 LuCI JavaScript
页面并通过 procd 管理 Agent 服务。

哪吒监控 Agent 官方仓库：<https://github.com/nezhahq/agent>

## 功能

- 在 LuCI 中配置面板服务器、客户端密钥和官方 Agent 参数
- 显示服务状态并支持 procd 开机启动、重载和异常重启
- 构建时获取官方最新 Agent Release，并校验官方 SHA-256
- 保存配置时保留 Agent UUID 和其他未由 LuCI 管理的 YAML 字段
- 提供独立简体中文语言包

## 支持范围

GitHub Release 仅发布 OpenWrt `x86_64` 安装包：

| 适用版本 | 包格式 | 构建 SDK |
| --- | --- | --- |
| OpenWrt 23.05 / 24.10 | IPK | OpenWrt 24.10.5 x86/64 SDK |
| OpenWrt 25.12+ | APK | OpenWrt 25.12.4 x86/64 SDK |

Release 中每个平台包含两个包：

- `luci-app-nezha-agent`：主程序、服务和 LuCI 页面
- `luci-i18n-nezha-agent-zh-cn`：简体中文语言包

## 安装

OpenWrt 23.05 / 24.10：

```sh
opkg install ./23.05-24.10_luci-app-nezha-agent_*.ipk
opkg install ./23.05-24.10_luci-i18n-nezha-agent-zh-cn_*.ipk
```

OpenWrt 25.12+：

```sh
apk add --allow-untrusted ./25.12+_luci-app-nezha-agent-*.apk
apk add --allow-untrusted ./25.12+_luci-i18n-nezha-agent-zh-cn-*.apk
```

安装后进入“服务 → 哪吒监控 Agent”完成配置。

## OpenWrt SDK 编译

将项目放入源码树或 SDK 的 `package/luci-app-nezha-agent`：

```sh
cat >> .config <<'EOF'
CONFIG_PACKAGE_luci-app-nezha-agent=m
CONFIG_LUCI_LANG_zh_Hans=y
EOF

make defconfig
make package/luci-app-nezha-agent/{clean,compile} V=s
```

默认会解析官方最新 Agent Release。CI 可以通过以下 Make 变量固定同一次构建：

```sh
make package/luci-app-nezha-agent/compile \
  NEZHA_AGENT_TAG=v2.2.2 \
  NEZHA_AGENT_HASH=<nezha-agent_linux_amd64.zip 的 SHA-256>
```

## 自动更新

Agent 自带自动更新功能，默认配置为：

```yaml
disable_auto_update: false
```

即默认允许自动更新，LuCI 中的“禁用 Agent 自动更新”默认不勾选。

## 配置文件

- UCI 配置：`/etc/config/nezha-agent`
- Agent 配置：`/etc/nezha-agent/config.yml`
- Agent 程序：`/usr/bin/nezha-agent`
- 服务脚本：`/etc/init.d/nezha-agent`

UUID 仅保存在 Agent 配置文件中；首次缺失时生成，后续同步会继续使用配置中的值。LuCI 支持配置多个 `custom_ip_api`。使用透明代理时，应将对应 API 域名加入代理软件的直连规则，避免 Agent 获取到代理出口 IP。配置同步只更新 LuCI 管理的字段，手动添加的其他 YAML 参数不会被校验或删除。

卸载软件包会自动停止并禁用服务，但保留用户配置。若不再需要，可手动删除 `/etc/config/nezha-agent`、`/etc/config/nezha-agent-opkg` 和 `/etc/nezha-agent`。
