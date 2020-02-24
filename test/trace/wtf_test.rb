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
    `-- #<Class:>
        |-- \e[32mStart.default\e[0m
        |-- \e[32m#<Method: #<Class:>.b>\e[0m
        `-- #<Class:>
            |-- \e[32mStart.default\e[0m
            `-- \e[1m\e[31m#<Method: #<Class:>.c>\e[0m\e[22m
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

  it "captures input & output for only given step and not others" do
    _, (_, flow_options), _ = Trailblazer::Developer.wtf?(
      alpha,
      [
        { seq: [], message: 'WTF!' },
        { focus_on: { steps: alpha.method(:a) } }
      ],
    )

    nested = flow_options[:stack].to_a.last
    tasks = nested.select{ |e| e.is_a?(Dev::Trace::Level) } # exclude ends

    # Trace::Entity::Input & Trace::Entity::Output for
    # task `:a` must contain {focused_variables} and not others
    tasks.each do |(input, *remainings)|
      if input.task.inspect.gsub(/0x\w+/, "").include?('#<Method: #<Class:>.a>>')
        input.data.keys.must_include(:focused_variables)
      else
        input.data.keys.wont_include(:focused_variables)
      end

      output = remainings.last

      if output.task.inspect.gsub(/0x\w+/, "").include?('#<Method: #<Class:>.a>>')
        output.data.keys.must_include(:focused_variables)
      else
        output.data.keys.wont_include(:focused_variables)
      end
    end
  end

  it "captures input & output for given step and ctx (captures whole ctx by default)" do
    output, _ = capture_io do
      Trailblazer::Developer.wtf?(
        alpha,
        [
          { seq: [], message: 'WTF!' },
          { focus_on: { steps: alpha.method(:a) } }
        ],
      )
    end

    output.gsub(/0x\w+/, "").must_equal %{`-- #<Class:>
    |-- \e[32mStart.default\e[0m
    |-- \e[32m#<Method: #<Class:>.a>\e[0m
    |   |-- \e[32m********** Input **********
            message: \"WTF!\"
                seq: \e[0m
    |   `-- \e[32m********** Output **********
            message: \"WTF!\"
                seq: :a\e[0m
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

  it "captures input & output inspect for given step and variable within ctx" do
    output, _ = capture_io do
      Trailblazer::Developer.wtf?(
        alpha,
        [
          { seq: [], message: 'WTF!', nested: { message: 'Dude!' } },
          {
            focus_on: {
              steps: alpha.method(:a),
              variables: :message
            },
          }
        ],
      )
    end

    output.gsub(/0x\w+/, "").must_equal %{`-- #<Class:>
    |-- \e[32mStart.default\e[0m
    |-- \e[32m#<Method: #<Class:>.a>\e[0m
    |   |-- \e[32m********** Input **********
            message: \"WTF!\"\e[0m
    |   `-- \e[32m********** Output **********
            message: \"WTF!\"\e[0m
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

  it "captures input & output for given 1/more steps and selected variables witin ctx" do
    output, _ = capture_io do
      Trailblazer::Developer.wtf?(
        alpha,
        [
          { seq: [], message: 'WTF!', nested: { message: 'Dude!' } },
          {
            focus_on: {
              steps: [alpha.method(:a)],
              variables: [
                :message, # symbol for top level key access
                ->(ctx) { ctx[:nested][:message] }, # procs can be used for deep access
              ]
            },
          }
        ],
      )
    end

    output.gsub(/0x\w+/, "").must_equal %{`-- #<Class:>
    |-- \e[32mStart.default\e[0m
    |-- \e[32m#<Method: #<Class:>.a>\e[0m
    |   |-- \e[32m********** Input **********
             Custom: \"Dude!\"
            message: \"WTF!\"\e[0m
    |   `-- \e[32m********** Output **********
             Custom: \"Dude!\"
            message: \"WTF!\"\e[0m
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

  it "allows passing custom inspector" do
    output, _ = capture_io do
      Trailblazer::Developer.wtf?(
        alpha,
        [
          { seq: [], message: 'WTF!', nested: { message: 'Dude!' } },
          {
            focus_on: { steps: [alpha.method(:a)], variables: [:message] },
            default_inspector: ->(value){ "#{value}-inspect" }
          },
        ],
      )
    end

    output.gsub(/0x\w+/, "").must_equal %{`-- #<Class:>
    |-- \e[32mStart.default\e[0m
    |-- \e[32m#<Method: #<Class:>.a>\e[0m
    |   |-- \e[32m********** Input **********
            message: WTF!-inspect\e[0m
    |   `-- \e[32m********** Output **********
            message: WTF!-inspect\e[0m
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

  it "has alias to `wtf` as `wtf?`" do
    assert_equal Dev.method(:wtf), Dev.method(:wtf?)
  end
end
