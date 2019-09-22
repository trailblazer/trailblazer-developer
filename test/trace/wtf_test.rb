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
      raise "hello from #{value}!" if value == @raise_in
      super
    end
  end

  it "traces until charlie, 3-level and exception occurs" do
    output, _ = capture_io do
      assert_raises RuntimeError do
        Trailblazer::Developer.wtf?(alpha, [{ seq: Raiser.new(raise_in: :c) }])
      end
    end

    output.gsub(/0x\w+/, "").must_equal %{`-- #<Class:>
   |-- \e[32mStart.default\e[0m
   |-- \e[32m#<Method: #<Class:>.a>\e[0m
   |-- #<Class:>
   |   |-- \e[32mStart.default\e[0m
   |   |-- \e[32m#<Method: #<Class:>.b>\e[0m
   |   |-- #<Class:>
   |   |   |-- \e[32mStart.default\e[0m
   |   |   |-- \e[1m\e[31m#<Method: #<Class:>.c>\e[0m\e[22m
}
  end


  it "traces until charlie, 3-level and step takes left track" do
    output, _ = capture_io do
      Trailblazer::Developer.wtf?(alpha, [{ seq: [], c: false }])
    end

    output.gsub(/0x\w+/, "").must_equal %{`-- #<Class:>
   |-- \e[32mStart.default\e[0m
   |-- \e[32m#<Method: #<Class:>.a>\e[0m
   |-- #<Class:>
   |   |-- \e[32mStart.default\e[0m
   |   |-- \e[32m#<Method: #<Class:>.b>\e[0m
   |   |-- #<Class:>
   |   |   |-- \e[32mStart.default\e[0m
   |   |   |-- \e[33m#<Method: #<Class:>.c>\e[0m
   |   |   `-- End.failure
   |   `-- End.failure
   `-- End.failure
}
  end


  it "traces alpha and it's subprocesses, for successful execution" do
    output, _ = capture_io do
      Trailblazer::Developer.wtf?(alpha, [{ seq: [] }])
    end

    output.gsub(/0x\w+/, "").must_equal %{`-- #<Class:>
   |-- \e[32mStart.default\e[0m
   |-- \e[32m#<Method: #<Class:>.a>\e[0m
   |-- #<Class:>
   |   |-- \e[32mStart.default\e[0m
   |   |-- \e[32m#<Method: #<Class:>.b>\e[0m
   |   |-- #<Class:>
   |   |   |-- \e[32mStart.default\e[0m
   |   |   |-- \e[32m#<Method: #<Class:>.c>\e[0m
   |   |   |-- \e[32m#<Method: #<Class:>.cc>\e[0m
   |   |   `-- End.success
   |   |-- \e[32m#<Method: #<Class:>.bb>\e[0m
   |   `-- End.success
   |-- \e[32m#<Method: #<Class:>.aa>\e[0m
   `-- End.success
}
  end

  it "overrides default color map of entities" do
    output, _ = capture_io do
      Trailblazer::Developer.wtf?(
        alpha,
        [
          { seq: [], c: false },
          { color_map: { pass: :cyan, fail: :red } }
        ]
      )
    end

    output.gsub(/0x\w+/, "").must_equal %{`-- #<Class:>
   |-- \e[36mStart.default\e[0m
   |-- \e[36m#<Method: #<Class:>.a>\e[0m
   |-- #<Class:>
   |   |-- \e[36mStart.default\e[0m
   |   |-- \e[36m#<Method: #<Class:>.b>\e[0m
   |   |-- #<Class:>
   |   |   |-- \e[36mStart.default\e[0m
   |   |   |-- \e[31m#<Method: #<Class:>.c>\e[0m
   |   |   `-- End.failure
   |   `-- End.failure
   `-- End.failure
}
  end

  it "has alias to `wtf` as `wtf?`" do
    assert_equal Dev.method(:wtf), Dev.method(:wtf?)
  end
end
