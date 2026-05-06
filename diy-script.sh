#!/bin/bash

# 添加额外插件
git clone --depth=1 -b master https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community package/luci-app-tailscale

# 科学上网插件
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/openwrt-passwall
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/luci-app-passwall

# 移除 lede luci feed 自带的过期 luci-app-passwall (26.4.6)
# 它没有 Iptables/Nftables_Transparent_Proxy 子菜单，且会和上游 26.5.3 抢 Kconfig
# 名字空间，导致 select 链不触发，iptables-mod-socket/iprange 不会被装入固件
rm -rf feeds/luci/applications/luci-app-passwall package/feeds/luci/luci-app-passwall

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
