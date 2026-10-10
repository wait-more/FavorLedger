# 人情记（FavorLedger）

人情往来账本：以亲友为中心记收/送，本地优先；可选 WebDAV 备份，多端按实体逻辑时钟合并。

开源：https://github.com/wait-more/FavorLedger

## 功能

- **人情录 / 详情 / 流水 / 汇总**：净额用「人情在我 / 人情在彼」与正负号表达
- **记一笔**：方向、金额、日期、事件、备注；流水与详情支持右滑删除
- **云端同步**（设置 → 云端同步）：WebDAV 配置、自动同步（默认关）、立即同步 / 上传 / 合并恢复
- **自动同步开启后**：启动、回前台、改账防抖、前台定时拉取；首页与流水下拉可查云端
- **导出**：JSON、CSV
- 有实质变更或失败时轻提示；设置「关于」可打开仓库页

## 开发

网络访问 Google 较慢时可先设镜像（当前会话）：

```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Android Gradle 已默认优先走阿里云 / Flutter 中国镜像。

## 打包

```bash
flutter build apk --release
```

产物：`build/app/outputs/apk/release/favor_ledger-release.apk`  
（Flutter 也可能再生成 `build/app/outputs/flutter-apk/app-release.apk`，内容相同。）

图标：`dart run flutter_launcher_icons`（源图 `assets/branding/app_icon.png`）

## 技术栈

Flutter · Riverpod · Drift (SQLite) · go_router · WebDAV
