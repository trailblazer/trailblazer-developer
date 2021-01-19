require "trailblazer/developer/version"
require "dry-configurable"
require "logger"

module Trailblazer
  module Developer
    extend Dry::Configurable
    setting(:logger, Logger.new($stdout), reader: true )
  end
end

require "trailblazer/developer/wtf"
require "trailblazer/developer/wtf/renderer"
require "trailblazer/developer/trace"
require "trailblazer/developer/trace/present"
require "trailblazer/developer/trace/focusable"
require "trailblazer/developer/trace/inspector"
require "trailblazer/developer/generate"
require "trailblazer/developer/render/circuit"
require "trailblazer/developer/render/linear"

# require "trailblazer/developer/client"
