$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
# require "trailblazer/circuit"
# require "trailblazer/activity/dsl"
# require "trailblazer/activity"
require "trailblazer/operation"

require "trailblazer/developer"
require "trailblazer/core"



require "minitest/autorun"
require "pp"

# require "trailblazer/invoke" # FIXME: remove me, this should be done on library level.

require "trailblazer/core"

Minitest::Spec.class_eval do
  include Trailblazer::Core::Utils::AssertRun
  include Trailblazer::Core::Utils::AssertEqual

  T = Trailblazer::Core

  # let(:my_compiler) do
  let(:my_compiler_with_trace) do
    # DISCUSS: this should be done by trailblazer-rails.
    # DISCUSS: where do we do this, is that some "global" constant in Trace?
    Trailblazer::Circuit::Adds.(
      Trailblazer::Activity::Invoke::Args::Compiler,
      [:my_trace, Trailblazer::Circuit::Node[Trailblazer::Developer::Trace::Invoke.method(:add_options_for_trace), Trailblazer::Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
      # [:my_wtf, Trailblazer::Circuit::Node[Trailblazer::Developer::Wtf::Invoke.method(:produce_wtf_node), Trailblazer::Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
      # [:my_wtf_2, Trailblazer::Circuit::Node[Trailblazer::Developer::Wtf::Invoke.method(:produce_condition), Trailblazer::Circuit::Task::Adapter::LibInterface], :before, :produce_wrap_runtime],
    )
  end
end
