require "test_helper"

class ConfigurationTest < Minitest::Spec
  describe "trace_color_map" do
    after do
      Trailblazer::Developer.config.trace_color_map.default = :green
      Trailblazer::Developer.config.trace_color_map[Trailblazer::Activity::Right] = :green
    end

    it "sets default" do
      assert_equal Trailblazer::Developer.config.trace_color_map.default, :green
      assert_equal Trailblazer::Developer.config.trace_color_map, {
        Trailblazer::Activity::Right => :green,
        Trailblazer::Activity::Left  => :brown
      }
    end

    it "overrides defaults via block" do
      Trailblazer::Developer.configure { |c| c.trace_color_map.default = :cyan }
      assert_equal Trailblazer::Developer.config.trace_color_map.default, :cyan

      Trailblazer::Developer.configure do |config|
        config.trace_color_map[Trailblazer::Activity::Right] = :cyan
      end
      assert_equal Trailblazer::Developer.config.trace_color_map[Trailblazer::Activity::Right], :cyan
    end
  end
end
