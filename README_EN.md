# fastlane-plugin-app_distribution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%202.6-red.svg)](https://www.ruby-lang.org/)

🇻🇳 [Tiếng Việt](https://github.com/anhhtbk/app_distribution/blob/main/README.md)

A Fastlane plugin to upload apps (APK/IPA) to a distribution server and send Telegram notifications with QR codes for OTA installation.

## 📋 Overview

This plugin automates the mobile app distribution process by:

1. **Upload app**: Automatically upload APK/IPA files to a distribution server
2. **Generate QR code**: Create QR code containing OTA installation link
3. **Telegram notification**: Send QR code with version info to Telegram channel/group

### 🔗 Distribution Server

This plugin is designed to work with [**Significa App Distribution Server**](https://github.com/significa/app-distribution-server) - an open-source server for hosting and distributing mobile applications.

> **Reference:** [https://github.com/significa/app-distribution-server](https://github.com/significa/app-distribution-server)

You need to self-host an instance of `app-distribution-server` to use this plugin.

## ✨ Features

- ✅ Support for both **iOS** (IPA) and **Android** (APK)
- ✅ Auto-discovery of build output files
- ✅ **OTA installation** support for iOS via `itms-services`
- ✅ **Telegram Bot API** integration for notifications
- ✅ **QR code** generation for quick installation
- ✅ Read app info from `pubspec.yaml` (Flutter projects)
- ✅ Telegram API proxy support (for restricted regions)

## 🚀 Installation

Add to your Fastlane `Pluginfile`:

```ruby
# From git repository
gem 'fastlane-plugin-app_distribution', git: 'https://github.com/anhhtbk/app_distribution.git'

# Or from local path
gem 'fastlane-plugin-app_distribution', path: '../fastlane-plugin-app_distribution'
```

Then run:

```bash
bundle install
```

## 📖 Usage

### Basic

```ruby
app_distribution(
  chat_id: "@your_telegram_chat",    # Required: Telegram chat ID
  platform: "iOS",                    # Required: iOS or Android
  env: "staging"                      # Optional: environment name (default: production)
)
```

### With explicit app path

```ruby
app_distribution(
  chat_id: "@your_telegram_chat",
  platform: "iOS",
  app_path: "./build/Runner.ipa"
)
```

### With pre-uploaded app (using app_id)

```ruby
app_distribution(
  chat_id: "@your_telegram_chat",
  platform: "iOS",
  app_id: "abc123"  # ID returned from server after upload
)
```

### All parameters

```ruby
app_distribution(
  chat_id: "@your_telegram_chat",     # Required: Chat ID (-123456789 or @channel_name)
  platform: "iOS",                     # Required: iOS or Android
  app_path: "./build/app.ipa",        # Optional: File path (auto-discover if not provided)
  app_id: "abc123",                   # Optional: Pre-uploaded app ID
  server_url: "https://dist.example.com",  # Optional: Server URL (or use ENV)
  token: "your_auth_token",           # Optional: Auth token (or use ENV)
  env: "staging"                      # Optional: Environment name (default: production)
)
```

## ⚙️ Environment Variables

Configure these environment variables in your CI/CD:

| Variable              | Description                        | Required |
| --------------------- | ---------------------------------- | -------- |
| `TELEGRAM_BOT_TOKEN`  | Telegram Bot token                 | ✅       |
| `TELEGRAM_API_URL`    | Telegram API URL (supports proxy)  | ✅       |
| `APP_DIST_SERVER_URL` | Distribution server URL            | ✅       |
| `APP_DIST_TOKEN`      | Auth token for distribution server | ✅       |

### Example setup

```bash
export TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
export TELEGRAM_API_URL="https://api.telegram.org"
export APP_DIST_SERVER_URL="https://your-dist-server.com"
export APP_DIST_TOKEN="your-secret-token"
```

## 🔍 Auto-discovery

If `app_path` is not provided, the plugin will automatically discover build output files:

### iOS

Plugin searches in priority order:

- `build/ios/ipa/*.ipa`
- `build/ios/archive/*.ipa`
- `ios/*.ipa`
- `*.ipa`

### Android

Plugin searches in priority order:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/apk/release/*.apk`
- `build/app/outputs/apk/debug/*.apk`
- `*.apk`

## 🔧 How it Works

### Processing Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     app_distribution                        │
├─────────────────────────────────────────────────────────────┤
│  1. Read app info from pubspec.yaml                         │
│  2. Find APK/IPA file (if not provided)                     │
│  3. Upload file to distribution server                      │
│  4. Create OTA link:                                        │
│     - iOS: itms-services://...                              │
│     - Android: direct download link                         │
│  5. Generate QR code from link                              │
│  6. Send QR + info to Telegram                              │
└─────────────────────────────────────────────────────────────┘
```

### iOS OTA Installation

For iOS, the plugin uses the `itms-services://` protocol for OTA installation:

```
itms-services://?action=download-manifest&url={server}/get/{app_id}/app.plist
```

### Distribution Server API

The plugin communicates with the distribution server via REST API:

```bash
# Upload app
POST /upload
Headers:
  - Accept: application/json
  - X-Auth-Token: {token}
Body:
  - app_file: (multipart file)

Response: URL to install page (e.g., https://server/get/abc123)
```

## 📦 Dependencies

This plugin uses:

- [`rqrcode`](https://github.com/whomwah/rqrcode) ~> 2.0 - QR code generation
- [`chunky_png`](https://github.com/wvanbergen/chunky_png) ~> 1.4 - Render QR to PNG

## 🤝 Related Projects

- **Distribution Server**: [significa/app-distribution-server](https://github.com/significa/app-distribution-server) - Server for hosting and distributing apps
- **Fastlane**: [fastlane/fastlane](https://github.com/fastlane/fastlane) - Mobile CI/CD automation tool

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

---

> 💡 **Tip**: To set up a distribution server, refer to the guide at [https://github.com/significa/app-distribution-server](https://github.com/significa/app-distribution-server)
