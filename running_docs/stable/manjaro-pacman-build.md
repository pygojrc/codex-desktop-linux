<2026-08-15> Manjaro pacman 构建关闭 updater 结论

# Manjaro pacman 构建结论

本次决定构建不包含 updater 的 Manjaro pacman 包，不修改仓库默认配置。

```bash
PACKAGE_WITH_UPDATER=0 make pacman
```

关闭后会跳过 `codex-update-manager` 的 Rust 编译，并从最终包中移除
update-builder、systemd user service、polkit policy、updater 安装钩子及
`polkit`、`curl`、`dpkg`、`gnupg`、`nodejs` 等 updater 专用依赖。应用本体、
`codex-desktop` 命令、桌面入口、AppArmor 配置和已启用 Linux features 不受
影响。

该包不再自动执行事务式更新，后续版本需要重新构建并手动安装：

```bash
PACKAGE_WITH_UPDATER=0 make build-app
PACKAGE_WITH_UPDATER=0 make pacman
sudo pacman -U --noconfirm dist/codex-desktop-latest.pkg.tar.zst
```

本次记录只确认构建选项和影响，未执行安装，也未将构建结果宣称为运行时验收。
