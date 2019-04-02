require "test_helper"

class TraceWtfTest < Minitest::Spec
  let(:alpha) do
    charlie = Class.new(Trailblazer::Activity::Railway) do
      extend T.def_steps(:c, :cc)

      step method(:c)
      step method(:cc)
    end

    beta = Class.new(Trailblazer::Activity::Railway) do
      extend T.def_steps(:b, :bb)

      step method(:b)
      step Subprocess(charlie)
      step method(:bb)
    end

    Class.new(Trailblazer::Activity::Railway) do
      extend T.def_steps(:a, :aa)

      step method(:a)
      step Subprocess(beta)
      step method(:aa)
    end
  end

  class Raiser < Array
    def initialize(raise_in:)
      super()
      @raise_in = raise_in
    end

    def <<(value)
      raise RuntimeError.new("hello from #{value}!") if value == @raise_in
      super
    end
  end

  it "traces until charlie, 3-level" do
    # signal, (ctx, _) = alpha.([{seq: Raiser.new(raise_in: :c)}])
    # signal, (ctx, _) = Trailblazer::Activity::Trace.invoke(alpha, [{seq: Raiser.new(raise_in: :c)}])

    # signal, (ctx, _) = Developer.wtf?(alpha, [{seq: Raiser.new(raise_in: :c)}])
    puts
    signal, (ctx, _) = Dev.wtf(alpha, [{seq: Raiser.new(raise_in: :c)}])



    pp ctx
  end
end
