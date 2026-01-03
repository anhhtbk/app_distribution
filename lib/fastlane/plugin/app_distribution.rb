require 'fastlane/plugin/app_distribution/version'

module Fastlane
  module AppDistribution
    def self.all_classes
      Dir[File.expand_path('app_distribution/actions/*.rb', File.dirname(__FILE__))]
    end
  end
end

Fastlane::AppDistribution.all_classes.each do |current|
  require current
end
