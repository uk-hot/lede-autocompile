#!/bin/bash

# 科学上网插件
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/openwrt-passwall
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/luci-app-passwall

# 移除 lede luci feed 自带的过期 luci-app-passwall (26.4.6)
# 它没有 Iptables/Nftables_Transparent_Proxy 子菜单，且会和上游 26.5.3 抢 Kconfig
# 名字空间，导致 select 链不触发，iptables-mod-socket/iprange 不会被装入固件
rm -rf feeds/luci/applications/luci-app-passwall package/feeds/luci/luci-app-passwall

# 移除 lede packages feed 中与 passwall-packages 同名的旧包 (如 xray-core 26.6.1)
# feed 版本会覆盖 passwall-packages 版本，而新版 passwall 生成的 Xray 配置
# 要求 version.min >= 26.7.11，旧 xray 校验失败直接不启动
for pkg in package/openwrt-passwall/*/; do
	name=$(basename "$pkg")
	find feeds/packages -mindepth 2 -maxdepth 2 -type d -name "$name" -exec rm -rf {} +
	rm -rf "package/feeds/packages/$name"
done

# 升级 tailscale 至上游最新 release
# lede packages feed 长期停在旧版 (1.84.2)，每次编译都不会自动更新
# 若新版 go.mod 要求的 Go 高于 feed 自带 golang，则保留 feed 版本以免编译失败
ts_mk=feeds/packages/net/tailscale/Makefile
ts_ver=$(curl -fsSI https://github.com/tailscale/tailscale/releases/latest | grep -i '^location:' | sed 's#.*/tag/v##' | tr -d '\r')
if [ -f "$ts_mk" ] && [ -n "$ts_ver" ]; then
	go_mk=feeds/packages/lang/golang/golang/Makefile
	go_have=$(awk -F ':=' '/^GO_VERSION_MAJOR_MINOR/{m=$2} /^GO_VERSION_PATCH/{p=$2} END{print m (p ? "." p : "")}' "$go_mk")
	go_need=$(curl -fsSL "https://raw.githubusercontent.com/tailscale/tailscale/v$ts_ver/go.mod" | awk '/^go /{print $2}')
	if [ -n "$go_need" ] && [ "$(printf '%s\n%s\n' "$go_need" "$go_have" | sort -V | tail -n1)" = "$go_have" ]; then
		if ts_hash=$(set -o pipefail; curl -fsSL "https://codeload.github.com/tailscale/tailscale/tar.gz/v$ts_ver" | sha256sum | cut -d ' ' -f1); then
			sed -i -e "s/^PKG_VERSION:=.*/PKG_VERSION:=$ts_ver/" \
				-e "s/^PKG_RELEASE:=.*/PKG_RELEASE:=1/" \
				-e "s/^PKG_HASH:=.*/PKG_HASH:=$ts_hash/" "$ts_mk"
			echo "tailscale -> $ts_ver"
		fi
	else
		echo "tailscale $ts_ver 需要 Go $go_need，feed 仅有 Go $go_have，保留 feed 版本"
	fi
fi

# 修改默认IP
sed -i 's/192.168.1.1/192.168.123.1/g' package/base-files/files/bin/config_generate

# 修改本地时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改版本为编译日期
# date_version=$(date +"%y.%m.%d")
# orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
# sed -i "s/${orig_version}/R${date_version} by emxiong/g" package/lean/default-settings/files/zzz-default-settings

# 修改 Makefile
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# ============================================
# 修复 jdcloud_re-sp-01b 缺少 uimage-lzma-loader 导致无法生成 sysupgrade.bin
# 参考: lenovo_newifi-d1 等同类 MT7621 设备均包含此模板
# ============================================
if [ -f target/linux/ramips/image/mt7621.mk ]; then
  sed -i '/define Device\/jdcloud_re-sp-01b/,/endef/{
    s/$(Device\/dsa-migration)/$(Device\/dsa-migration)\n  $(Device\/uimage-lzma-loader)/
  }' target/linux/ramips/image/mt7621.mk
fi
