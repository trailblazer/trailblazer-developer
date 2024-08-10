require "trailblazer/developer/version"
require "logger"

module Trailblazer
  module Developer
    # Your code goes here...
    class << self
      attr_writer :logger

      def logger
        @logger ||= Logger.new($stdout, formatter: proc { |*, msg| "#{msg}\n" }).tap do |log|
          log.progname = self.name
        end
      end
    end
  end
end

require "trailblazer/activity"
require "trailblazer/developer/wtf"
require "trailblazer/developer/wtf/renderer"
require "trailblazer/developer/trace/snapshot"
require "trailblazer/developer/trace/snapshot/value"
require "trailblazer/developer/trace/snapshot/versions"
require "trailblazer/developer/trace"
require "trailblazer/developer/trace/stack"
require "trailblazer/developer/trace/node"
require "trailblazer/developer/trace/parent_map"
require "trailblazer/developer/trace/present"
require "trailblazer/developer/debugger"
require "trailblazer/developer/render/circuit"
require "trailblazer/developer/render/linear"
require "trailblazer/developer/render/task_wrap"
require "trailblazer/developer/introspect" # TODO: might get removed, again.
require "trailblazer/developer/debugger/normalizer"
require "trailblazer/developer/introspect/graph"
Trailblazer::Developer::Trace::Debugger = Trailblazer::Developer::Debugger # FIXME: deprecate constant!
