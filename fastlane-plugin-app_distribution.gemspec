lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/app_distribution/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-app_distribution'
  spec.version       = Fastlane::AppDistribution::VERSION
  spec.author        = 'Mesoco'
  spec.email         = 'tuananh@pmr.vn'

  spec.summary       = 'Upload app to distribution server and send Telegram notification with QR code'
  spec.homepage      = 'https://github.com/anhhtbk/app_distribution.git'
  spec.license       = 'MIT'

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency 'rqrcode', '~> 2.0'
  spec.add_dependency 'chunky_png', '~> 1.4'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'fastlane', '>= 2.0'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
