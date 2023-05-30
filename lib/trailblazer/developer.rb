require "trailblazer/developer/version"

module Trailblazer
  module Developer
    # Your code goes here...
  end
end

require "trailblazer/activity"
require "trailblazer/developer/wtf"
require "trailblazer/developer/wtf/renderer"
require "trailblazer/developer/trace/snapshot"
require "trailblazer/developer/trace"
require "trailblazer/developer/trace/stack"
require "trailblazer/developer/trace/tree"
require "trailblazer/developer/trace/present"
require "trailblazer/developer/debugger"
require "trailblazer/developer/render/circuit"
require "trailblazer/developer/render/linear"
require "trailblazer/developer/render/task_wrap"
require "trailblazer/developer/introspect" # TODO: might get removed, again.
require "trailblazer/developer/debugger/normalizer"
require "trailblazer/developer/introspect/graph"
Trailblazer::Developer::Trace::Debugger = Trailblazer::Developer::Debugger # FIXME: deprecate constant!
