module Trailblazer::Developer
  # {config} gives global settings for Developer
  # Trailblazer::Developer.configure do |config|
  #   config.trace_color_map[Trailblazer::Activity::Right] = :green
  #   config.trace_color_map.default = :green
  # end

  class << self
    def configure
      yield config
    end

    def config
      @config ||= Config.new
    end
  end

  class Config
    attr_reader :trace_color_map

    def initialize
      @trace_color_map = {
        Trailblazer::Activity::Right => :green,
        Trailblazer::Activity::Left  => :brown
      }

      @trace_color_map.default = :green
    end
  end
end
