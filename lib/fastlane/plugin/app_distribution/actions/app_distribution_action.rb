require 'rqrcode'
require 'yaml'
require 'json'
require 'ostruct'

module Fastlane
  module Actions
    class AppDistributionAction < Action
      def self.run(params)
        telegram_token = ENV['TELEGRAM_BOT_TOKEN']
        telegram_chat  = params[:chat_id]
        server = params[:server_url] || ENV["APP_DIST_SERVER_URL"]
        token  = params[:token] || ENV["APP_DIST_TOKEN"]
        env = params[:env] || "production"
        platform = params[:platform] || "App"
        send_icon = params[:send_icon].nil? ? true : params[:send_icon]

        app_id = params[:app_id]
        app_path = params[:app_path]
        icon_path = params[:icon_path]

        # Get app info from pubspec.yaml
        flutter_info = get_flutter_app_info
        app_name = flutter_info[:name]
        app_version = flutter_info[:version]

        # Auto-discover app icon if send_icon is enabled and icon_path not provided
        if send_icon && (icon_path.nil? || icon_path.empty?)
          icon_path = discover_app_icon(platform)
        end

        UI.message("🔔 app_distribution started")
        UI.message("   app_name: #{app_name}")
        UI.message("   app_version: #{app_version}")
        UI.message("   app_id: #{app_id || '(nil)'}")
        UI.message("   app_path: #{app_path || '(auto-discover)'}")
        UI.message("   icon_path: #{icon_path || '(not found)'}")
        UI.message("   server: #{server || '(nil)'}")
        UI.message("   platform: #{platform}")
        UI.message("   send_icon: #{send_icon}")
        UI.message("   telegram_token: #{telegram_token ? 'SET' : 'NOT SET'}")
        UI.message("   telegram_chat: #{telegram_chat}")

        # Upload app (auto-discover if app_path not provided)
        if !app_id || app_id.empty?
          app_id = upload_app(server, token, app_path, platform)
          return unless app_id
        end

        unless app_id && !app_id.empty?
          UI.error("❌ app_id is nil or empty!")
          return
        end

        app_link = "#{server}/get/#{app_id}"
        
        # iOS uses itms-services for OTA install, Android uses direct link
        if platform.downcase == "ios"
          app_link_qr = "itms-services://?action=download-manifest&url=#{server}/get/#{app_id}/app.plist"
        else
          app_link_qr = app_link
        end

        qr_path = File.join(Dir.tmpdir, "qr_#{Time.now.to_i}.png")

        UI.message("📱 App link: #{app_link}")
        UI.message("📱 QR link: #{app_link_qr}")

        # 1. Generate QR PNG
        UI.message("🖼️ Generating QR code...")
        generate_qr_png(app_link_qr, qr_path)
        UI.message("🖼️ QR generated: #{File.exist?(qr_path)} (size: #{File.exist?(qr_path) ? File.size(qr_path) : 0} bytes)")

        # 2. Send to Telegram
        UI.message("📤 Sending to Telegram...")
        caption = "📦 #{app_name} v#{app_version}\n#{platform} • #{env}\n#{app_link}"

        # Send with icon if available, otherwise just QR code
        if icon_path && File.exist?(icon_path)
          UI.message("🎨 Sending with app icon: #{icon_path}")
          result = send_telegram_media_group(
            telegram_token,
            telegram_chat,
            icon_path,
            qr_path,
            caption
          )
        else
          UI.message("📷 Sending QR code only (no icon found)")
          result = send_telegram_photo(
            telegram_token,
            telegram_chat,
            qr_path,
            caption
          )
        end

        # 3. Remove QR image after sending
        File.delete(qr_path) if File.exist?(qr_path)

        if result && result.code == 200
          UI.success("✅ QR code sent to Telegram!")
        else
          UI.error("❌ Failed to send QR code to Telegram")
        end
      end

      def self.upload_app(server, token, app_path, platform)
        app_full_path = resolve_app_path(app_path, platform)

        UI.user_error!("server_url is required") unless server
        UI.user_error!("token is required") unless token
        UI.user_error!("app_path not found: #{app_path}") unless app_full_path

        UI.message("📤 Uploading app to distribution server...")
        UI.message("   Path: #{app_full_path}")

        cmd = %(curl -sfSL -X POST "#{server}/upload" \
          -H "Accept: application/json" \
          -H "X-Auth-Token: #{token}" \
          -F "app_file=@#{app_full_path}")

        resp = Actions.sh(cmd)
        UI.success("Install page: #{resp || '(no url in response)'}")

        app_id = resp.strip.split('/').last if resp
        app_id
      rescue => e
        UI.error("❌ Failed to upload app: #{e.message}")
        nil
      end

      def self.get_flutter_app_info
        pubspec_paths = [
          File.expand_path("../../pubspec.yaml", Dir.pwd),
          File.expand_path("../pubspec.yaml", Dir.pwd),
          File.expand_path("pubspec.yaml", Dir.pwd),
          File.expand_path("../../../pubspec.yaml", Dir.pwd)
        ]

        pubspec_path = pubspec_paths.find { |p| File.exist?(p) }

        unless pubspec_path
          UI.warning("⚠️ pubspec.yaml not found, using defaults")
          return { name: "App", version: "unknown" }
        end

        UI.message("📄 Reading pubspec.yaml from: #{pubspec_path}")
        pubspec = YAML.load_file(pubspec_path)

        {
          name: pubspec['description'] || pubspec['name'] || "App",
          version: pubspec['version'] || "unknown"
        }
      rescue => e
        UI.warning("⚠️ Failed to read pubspec.yaml: #{e.message}")
        { name: "App", version: "unknown" }
      end

      def self.resolve_app_path(app_path, platform)
        if app_path && !app_path.empty?
          return app_path if app_path.start_with?('/') && File.exist?(app_path)

          base_dirs = [
            Dir.pwd,
            File.expand_path("..", Dir.pwd),
            File.expand_path("../..", Dir.pwd),
            ENV['WORKSPACE'] || Dir.pwd,
            File.expand_path("../../..", Dir.pwd)
          ]

          base_dirs.each do |base|
            full_path = File.expand_path(app_path, base)
            return full_path if File.exist?(full_path)
          end
        end

        UI.message("🔍 Auto-discovering #{platform} build output...")
        discover_app_file(platform)
      end

      def self.discover_app_file(platform)
        project_root = find_project_root

        unless project_root
          UI.error("❌ Could not find project root")
          return nil
        end

        UI.message("   Project root: #{project_root}")

        if platform.downcase == "ios"
          patterns = [
            "#{project_root}/build/ios/ipa/*.ipa",
            "#{project_root}/build/ios/archive/*.ipa",
            "#{project_root}/ios/*.ipa",
            "#{project_root}/*.ipa"
          ]
        else
          patterns = [
            "#{project_root}/build/app/outputs/flutter-apk/*.apk",
            "#{project_root}/build/app/outputs/apk/release/*.apk",
            "#{project_root}/build/app/outputs/apk/debug/*.apk",
            "#{project_root}/*.apk"
          ]
        end

        patterns.each do |pattern|
          files = Dir.glob(pattern)
          if files.any?
            found = files.max_by { |f| File.mtime(f) }
            UI.success("   Found: #{found}")
            return found
          end
        end

        UI.error("❌ No #{platform} build output found")
        nil
      end

      def self.find_project_root
        search_dirs = [
          File.expand_path("../..", Dir.pwd),
          File.expand_path("..", Dir.pwd),
          Dir.pwd,
          ENV['WORKSPACE']
        ].compact

        search_dirs.each do |dir|
          return dir if File.exist?(File.join(dir, "pubspec.yaml"))
        end
        nil
      end

      def self.discover_app_icon(platform)
        project_root = find_project_root

        unless project_root
          UI.warning("⚠️ Could not find project root for icon discovery")
          return nil
        end

        UI.message("🔍 Auto-discovering app icon...")

        # Priority order for Flutter app icons
        icon_patterns = []

        if platform.downcase == "ios"
          # iOS app icon locations (Flutter)
          icon_patterns = [
            # Standard Flutter iOS icon locations
            "#{project_root}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",
            "#{project_root}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png",
            "#{project_root}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png",
            "#{project_root}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png",
            "#{project_root}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png",
            "#{project_root}/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png"
          ]
        else
          # Android app icon locations (Flutter)
          icon_patterns = [
            # Adaptive icon foreground (preferred - usually higher quality)
            "#{project_root}/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png",
            "#{project_root}/android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png",
            "#{project_root}/android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png",
            # Standard launcher icon
            "#{project_root}/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png",
            "#{project_root}/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png",
            "#{project_root}/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png",
            "#{project_root}/android/app/src/main/res/mipmap-hdpi/ic_launcher.png",
            "#{project_root}/android/app/src/main/res/mipmap-mdpi/ic_launcher.png",
            # Round launcher icon
            "#{project_root}/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png",
            "#{project_root}/android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png"
          ]
        end

        # Also check common shared icon locations
        shared_patterns = [
          "#{project_root}/assets/icon/app_icon.png",
          "#{project_root}/assets/icons/app_icon.png",
          "#{project_root}/assets/icon.png",
          "#{project_root}/assets/app_icon.png",
          "#{project_root}/assets/launcher_icon.png"
        ]

        all_patterns = icon_patterns + shared_patterns

        all_patterns.each do |pattern|
          files = Dir.glob(pattern)
          if files.any?
            # Get the largest file (usually best quality)
            found = files.max_by { |f| File.size(f) }
            UI.success("   Found app icon: #{found}")
            return found
          end
        end

        UI.warning("⚠️ No app icon found for #{platform}")
        nil
      end

      def self.generate_qr_png(url, output_path)
        qrcode = RQRCode::QRCode.new(url)
        png = qrcode.as_png(
          bit_depth: 1,
          border_modules: 4,
          color_mode: ChunkyPNG::COLOR_GRAYSCALE,
          color: 'black',
          fill: 'white',
          module_px_size: 10,
          size: 300
        )
        IO.binwrite(output_path, png.to_s)
      end

      def self.send_telegram_photo(token, chat_id, photo_path, caption)
        telegram_api = ENV['TELEGRAM_API_URL']

        UI.message("📡 Telegram API URL: #{telegram_api || '(NOT SET)'}")

        unless telegram_api && !telegram_api.empty?
          UI.error("❌ TELEGRAM_API_URL is not set!")
          return nil
        end

        unless File.exist?(photo_path) && File.readable?(photo_path)
          UI.error("❌ Photo file does not exist or not readable: #{photo_path}")
          return nil
        end

        file_size = File.size(photo_path)
        if file_size == 0
          UI.error("❌ Photo file is empty: #{photo_path}")
          return nil
        end

        url = "#{telegram_api}/bot#{token}/sendPhoto"
        escaped_caption = caption.gsub("'", "'\\\\'")

        cmd = "curl -s -X POST '#{url}' " \
              "--form-string 'chat_id=#{chat_id}' " \
              "--form-string 'caption=#{escaped_caption}' " \
              "-F 'photo=@#{photo_path};type=image/png'"

        response_body = `#{cmd} 2>&1`
        exit_code = $?.exitstatus

        UI.message("📡 Curl exit code: #{exit_code}")

        response_json = JSON.parse(response_body) rescue {}

        if response_json['ok']
          UI.success("📡 Telegram API success!")
          return OpenStruct.new(code: 200, body: response_body)
        else
          UI.error("❌ Telegram API returned error: #{response_body}")
          return OpenStruct.new(code: 400, body: response_body)
        end
      rescue => e
        UI.error("❌ Failed to send Telegram photo: #{e.message}")
        nil
      end

      def self.send_telegram_media_group(token, chat_id, icon_path, qr_path, caption)
        telegram_api = ENV['TELEGRAM_API_URL']

        UI.message("📡 Telegram API URL: #{telegram_api || '(NOT SET)'}")

        unless telegram_api && !telegram_api.empty?
          UI.error("❌ TELEGRAM_API_URL is not set!")
          return nil
        end

        # Validate both files exist
        [icon_path, qr_path].each do |path|
          unless File.exist?(path) && File.readable?(path)
            UI.error("❌ File does not exist or not readable: #{path}")
            return nil
          end
          if File.size(path) == 0
            UI.error("❌ File is empty: #{path}")
            return nil
          end
        end

        url = "#{telegram_api}/bot#{token}/sendMediaGroup"

        # Build media array JSON - icon first with caption, then QR
        media = [
          { type: "photo", media: "attach://icon", caption: caption },
          { type: "photo", media: "attach://qr" }
        ].to_json

        escaped_media = media.gsub("'", "'\\''")

        cmd = "curl -s -X POST '#{url}' " \
              "--form-string 'chat_id=#{chat_id}' " \
              "--form-string 'media=#{escaped_media}' " \
              "-F 'icon=@#{icon_path};type=image/png' " \
              "-F 'qr=@#{qr_path};type=image/png'"

        response_body = `#{cmd} 2>&1`
        exit_code = $?.exitstatus

        UI.message("📡 Curl exit code: #{exit_code}")

        response_json = JSON.parse(response_body) rescue {}

        if response_json['ok']
          UI.success("📡 Telegram media group sent successfully!")
          return OpenStruct.new(code: 200, body: response_body)
        else
          UI.error("❌ Telegram API returned error: #{response_body}")
          # Fallback to sending just QR code if media group fails
          UI.message("📷 Falling back to sending QR code only...")
          return send_telegram_photo(token, chat_id, qr_path, caption)
        end
      rescue => e
        UI.error("❌ Failed to send Telegram media group: #{e.message}")
        # Fallback to sending just QR code
        UI.message("📷 Falling back to sending QR code only...")
        send_telegram_photo(token, chat_id, qr_path, caption)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload app to distribution server and send Telegram notification with QR code"
      end

      def self.details
        "Uploads APK/IPA to distribution server, generates a QR code for installation, " \
        "and sends it to a Telegram chat. Supports both iOS (itms-services) and Android platforms."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :chat_id,
            env_name: "APP_DISTRIBUTION_CHAT_ID",
            description: "Telegram chat ID (e.g., @channel_name or -123456789)",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :platform,
            env_name: "APP_DISTRIBUTION_PLATFORM",
            description: "Platform name (iOS or Android)",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_id,
            env_name: "APP_DISTRIBUTION_APP_ID",
            description: "Pre-uploaded app ID from distribution server (optional)",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_path,
            env_name: "APP_DISTRIBUTION_APP_PATH",
            description: "Path to APK/IPA file (optional, auto-discovered if not provided)",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :icon_path,
            env_name: "APP_DISTRIBUTION_ICON_PATH",
            description: "Path to app icon PNG file (optional, auto-discovered from Flutter project if not provided)",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :send_icon,
            env_name: "APP_DISTRIBUTION_SEND_ICON",
            description: "Whether to send app icon along with QR code (default: true)",
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :server_url,
            env_name: "APP_DIST_SERVER_URL",
            description: "Distribution server URL",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :token,
            env_name: "APP_DIST_TOKEN",
            description: "Authentication token for distribution server",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :env,
            env_name: "APP_DISTRIBUTION_ENV",
            description: "Environment name (e.g., staging, production)",
            optional: true,
            default_value: "production",
            type: String
          )
        ]
      end

      def self.authors
        ["Mesoco"]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end
    end
  end
end
