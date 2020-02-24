require "test_helper"

class InspectorTest < Minitest::Spec
  Inspector = Trailblazer::Developer::Trace::Inspector

  it 'runs inspections' do
    # Simple string
    assert_equal Inspector.('String Inspector'), "\"String Inspector\""

    # Array with different objects
    assert_equal(
      Inspector.([ 1, 'String', ['Array'], { key: :value } ]),
      ["1", "\"String\"", ["\"Array\""], {:key=>":value"}]
    )

    # Hash with nested keys
    assert_equal(
      Inspector.({ deep: { nested: { key: 1 } } }),
      { deep: { nested: { key: "1" } } }
    )

    # Any objects with custom inspection
    RandomClass = Class.new do
      def inspect
        %q{Inside Custom inspect}
      end
    end

    assert_equal Inspector.(RandomClass.new), "Inside Custom inspect"
  end

  it 'accepts default inspector' do
    timestamp = 1582549601
    time      = Time.at(timestamp).utc.to_s

    assert_equal(
      Inspector.(timestamp, default_inspector: ->(*) { time }),
      time
    )
  end

  it 'runs ActiveRecord related inspections' do
    module ::ActiveRecord
      class Relation
        def to_sql
          'SELECT column FROM table'
        end
      end
    end

    # ActiveRecord::Relation should give plain SQL query instead of record set on inspection
    assert_equal(
      Inspector.(ActiveRecord::Relation.new),
      { query: 'SELECT column FROM table' }
    )
  end
end
