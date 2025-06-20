require "test_helper"
require "trailblazer/operation"
Song = Module.new

module Song::Operation
  class Validator < Trailblazer::Operation
    step :extract_params
    step :validate, In() => [:params],
    Inject() => [:current_user]

    def extract_params(ctx, params:, **)
      # ctx[:model] = Object
      ctx[:params_for_validator] = params
    end

    def validate(ctx, **)
      true
    end
  end

  class Create < Trailblazer::Operation
    step :create_model
    step Subprocess(Validator)
    step :save
    step :notify_subscribers
    fail :compile_errors

    def create_model(ctx, **)
      ctx[:model] = Object
    end

    def save(ctx, **)
      true
    end

    def notify_subscribers(ctx, **)
      true
    end
  end
end

class DocsDebuggerTest < Minitest::Spec
  it "what" do
    skip "Once PRO is released..."
    require "trailblazer/pro/debugger"

    debugger_options = {present_options: {render_method: Trailblazer::Pro::Debugger.method(:call)}}

    signal, (options, _) = Trailblazer::Developer.wtf?(Song::Operation::Create, [{params: {title: "The Brews"}}, {}],
      **debugger_options,
    )
  end
end
