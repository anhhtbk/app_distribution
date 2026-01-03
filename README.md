# fastlane-plugin-app_distribution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%202.6-red.svg)](https://www.ruby-lang.org/)

🇬🇧 [English](https://github.com/anhhtbk/app_distribution/blob/main/README_EN.md)

Một Fastlane plugin để upload app (APK/IPA) lên distribution server và gửi thông báo Telegram với QR code cho việc cài đặt OTA.

## 📋 Tổng quan

Plugin này tự động hóa quy trình phân phối ứng dụng di động bằng cách:

1. **Upload ứng dụng**: Tự động upload file APK/IPA lên distribution server
2. **Tạo QR code**: Generate QR code chứa link cài đặt OTA
3. **Thông báo Telegram**: Gửi QR code kèm thông tin phiên bản đến Telegram channel/group

### 🔗 Distribution Server

Plugin này được thiết kế để hoạt động cùng với [**Significa App Distribution Server**](https://github.com/significa/app-distribution-server) - một server mã nguồn mở để host và phân phối ứng dụng di động.

> **Tham khảo:** [https://github.com/significa/app-distribution-server](https://github.com/significa/app-distribution-server)

Bạn cần tự host một instance của `app-distribution-server` để sử dụng plugin này.

## ✨ Tính năng

- ✅ Hỗ trợ cả **iOS** (IPA) và **Android** (APK)
- ✅ Tự động phát hiện file build output (auto-discovery)
- ✅ Hỗ trợ **OTA installation** cho iOS qua `itms-services`
- ✅ Tích hợp **Telegram Bot API** để gửi thông báo
- ✅ Generate **QR code** để cài đặt nhanh
- ✅ Đọc thông tin app từ `pubspec.yaml` (Flutter projects)
- ✅ Hỗ trợ Telegram API proxy (cho các vùng bị chặn)

## 🚀 Cài đặt

Thêm vào file `Pluginfile` của Fastlane:

```ruby
# Từ git repository
gem 'fastlane-plugin-app_distribution', git: 'https://github.com/anhhtbk/app_distribution.git'

# Hoặc từ local path
gem 'fastlane-plugin-app_distribution', path: '../fastlane-plugin-app_distribution'
```

Sau đó chạy:

```bash
bundle install
```

## 📖 Cách sử dụng

### Cơ bản

```ruby
app_distribution(
  chat_id: "@your_telegram_chat",    # Bắt buộc: Telegram chat ID
  platform: "iOS",                    # Bắt buộc: iOS hoặc Android
  env: "staging"                      # Tùy chọn: tên môi trường (mặc định: production)
)
```

### Với đường dẫn app cụ thể

```ruby
app_distribution(
  chat_id: "@your_telegram_chat",
  platform: "iOS",
  app_path: "./build/Runner.ipa"
)
```

### Với app đã được upload trước (sử dụng app_id)

```ruby
app_distribution(
  chat_id: "@your_telegram_chat",
  platform: "iOS",
  app_id: "abc123"  # ID trả về từ server sau khi upload
)
```

### Tất cả tham số

```ruby
app_distribution(
  chat_id: "@your_telegram_chat",     # Bắt buộc: Chat ID (-123456789 hoặc @channel_name)
  platform: "iOS",                     # Bắt buộc: iOS hoặc Android
  app_path: "./build/app.ipa",        # Tùy chọn: Đường dẫn file (auto-discover nếu không có)
  app_id: "abc123",                   # Tùy chọn: ID app đã upload trước
  server_url: "https://dist.example.com",  # Tùy chọn: URL server (hoặc dùng ENV)
  token: "your_auth_token",           # Tùy chọn: Token xác thực (hoặc dùng ENV)
  env: "staging"                      # Tùy chọn: Tên môi trường (mặc định: production)
)
```

## ⚙️ Biến môi trường

Cấu hình các biến môi trường trong CI/CD:

| Biến                  | Mô tả                                | Bắt buộc |
| --------------------- | ------------------------------------ | -------- |
| `TELEGRAM_BOT_TOKEN`  | Token của Telegram Bot               | ✅       |
| `TELEGRAM_API_URL`    | URL Telegram API (hỗ trợ proxy)      | ✅       |
| `APP_DIST_SERVER_URL` | URL của distribution server          | ✅       |
| `APP_DIST_TOKEN`      | Token xác thực cho distribution server | ✅     |

### Ví dụ thiết lập

```bash
export TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
export TELEGRAM_API_URL="https://api.telegram.org"
export APP_DIST_SERVER_URL="https://your-dist-server.com"
export APP_DIST_TOKEN="your-secret-token"
```

## 🔍 Auto-discovery

Nếu `app_path` không được cung cấp, plugin sẽ tự động tìm file build output:

### iOS

Plugin tìm kiếm theo thứ tự ưu tiên:
- `build/ios/ipa/*.ipa`
- `build/ios/archive/*.ipa`
- `ios/*.ipa`
- `*.ipa`

### Android

Plugin tìm kiếm theo thứ tự ưu tiên:
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/apk/release/*.apk`
- `build/app/outputs/apk/debug/*.apk`
- `*.apk`

## 🔧 Hoạt động

### Luồng xử lý

```
┌─────────────────────────────────────────────────────────────┐
│                     app_distribution                        │
├─────────────────────────────────────────────────────────────┤
│  1. Đọc thông tin app từ pubspec.yaml                       │
│  2. Tìm file APK/IPA (nếu không cung cấp sẵn)               │
│  3. Upload file lên distribution server                     │
│  4. Tạo link OTA:                                           │
│     - iOS: itms-services://...                              │
│     - Android: direct download link                         │
│  5. Generate QR code từ link                                │
│  6. Gửi QR + thông tin đến Telegram                         │
└─────────────────────────────────────────────────────────────┘
```

### iOS OTA Installation

Đối với iOS, plugin sử dụng protocol `itms-services://` để cài đặt OTA:
```
itms-services://?action=download-manifest&url={server}/get/{app_id}/app.plist
```

### API của Distribution Server

Plugin giao tiếp với distribution server qua REST API:

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

Plugin này sử dụng:

- [`rqrcode`](https://github.com/whomwah/rqrcode) ~> 2.0 - Tạo QR code
- [`chunky_png`](https://github.com/wvanbergen/chunky_png) ~> 1.4 - Render QR thành PNG

## 🤝 Liên quan

- **Distribution Server**: [significa/app-distribution-server](https://github.com/significa/app-distribution-server) - Server để host và phân phối ứng dụng
- **Fastlane**: [fastlane/fastlane](https://github.com/fastlane/fastlane) - Công cụ tự động hóa CI/CD cho mobile

## 📝 License

MIT License - xem file [LICENSE](LICENSE) để biết thêm chi tiết.

## 👤 Tác giả

**Mesoco** - tuananh@pmr.vn

---

> 💡 **Tip**: Để thiết lập distribution server, tham khảo hướng dẫn tại [https://github.com/significa/app-distribution-server](https://github.com/significa/app-distribution-server)
