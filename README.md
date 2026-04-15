# Pack

Pack 已开始从 Web 版迁移为 Flutter 多平台应用，目标平台为 `macOS / iOS / Android`。这一版先以 macOS 作为样板，把模板管理、行程创建、清单勾选和复盘学习四条主流程迁到共享 Flutter 代码中。

## 当前状态

- `lib/` 是新的 Flutter 业务入口，按 `common / models / database / features / widgets` 分层。
- `android/`、`ios/`、`macos/` 已补齐平台工程骨架。
- 本地存储改为 Flutter 侧 SQLite，默认仍会预置商务出行、度假、周末短途、徒步四个模板。
- 旧版 Next.js 代码仍保留在 `src/`，便于继续对照迁移，不作为主入口继续扩展。

## 参考架构

迁移时参考了 `/Users/manzhiyuan/workspaces/github/FlClash-new` 的组织方式：

- 共享业务代码集中在 `lib/`
- 平台差异收敛在 `android/`、`ios/`、`macos/`
- 数据层与页面层解耦，先把 macOS 跑通，再把同一套共享逻辑落到移动端

## 目录

```text
lib/
├── application.dart
├── common/
├── database/
├── features/
├── models/
└── widgets/

android/
ios/
macos/
src/   # 旧版 Next.js 实现，当前保留作迁移参考
```

## 运行

先安装 Flutter SDK，然后在项目根目录执行：

```bash
flutter pub get
flutter run -d macos
```

后续移动端可继续使用同一套共享代码：

```bash
flutter run -d ios
flutter run -d android
```

## Android Release

Android 已接入 `android/key.properties` 签名配置。建议把正式 keystore 放在 `android/keystores/` 下，并在本机创建 `android/key.properties`：

```properties
storeFile=keystores/pack-release.jks
storePassword=your-store-password
keyAlias=pack
keyPassword=your-key-password
```

然后执行：

```bash
flutter build apk --release
flutter build appbundle --release
```

如果本机没有 `android/key.properties`，Gradle 会回退到 debug 签名，仅用于本地验证，不适合正式分发。

## 说明

- 共享 Flutter 代码已经在 macOS 和 Android 上完成编译、运行与基础验证。
- Android 图标、启动页和 release 签名接入已经落地，后续可以继续补正式 keystore、发布渠道配置和 Play Console 上架资料。
