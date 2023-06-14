require "test_helper"

class StackTest < Minitest::Spec
  it do
    activity, sub_activity, _activity = Tracing.three_level_nested_activity

    stack, signal, (ctx, flow_options) = Dev::Trace.invoke(
      activity,
      [
        {seq: []},
        {}
      ]
    )

    assert_equal ctx[:seq], [:a, :b, :c, :d, :e]

    stack_ary = stack.to_a

    # top activity
    assert_equal stack_ary[0].class, Trailblazer::Developer::Trace::Snapshot::Before
    assert_equal stack_ary[0].task, activity
      assert_equal stack_ary[1].class, Trailblazer::Developer::Trace::Snapshot::Before
      assert_equal stack_ary[1].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
      assert_equal stack_ary[2].class, Trailblazer::Developer::Trace::Snapshot::After
      assert_equal stack_ary[2].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
      assert_equal stack_ary[2].data[:snapshot_before], stack_ary[1]

      assert_equal stack_ary[3].class, Trailblazer::Developer::Trace::Snapshot::Before
      assert_equal stack_ary[3].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>}
      assert_equal stack_ary[4].class, Trailblazer::Developer::Trace::Snapshot::After
      assert_equal stack_ary[4].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=a>}
      assert_equal stack_ary[4].data[:snapshot_before], stack_ary[3]

      # sub_activity
      assert_equal stack_ary[5].class, Trailblazer::Developer::Trace::Snapshot::Before
      assert_equal stack_ary[5].task, sub_activity
        assert_equal stack_ary[6].class, Trailblazer::Developer::Trace::Snapshot::Before
        assert_equal stack_ary[6].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
        assert_equal stack_ary[7].class, Trailblazer::Developer::Trace::Snapshot::After
        assert_equal stack_ary[7].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
        assert_equal stack_ary[7].data[:snapshot_before], stack_ary[6]

        assert_equal stack_ary[8].class, Trailblazer::Developer::Trace::Snapshot::Before
        assert_equal stack_ary[8].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>}
        assert_equal stack_ary[9].class, Trailblazer::Developer::Trace::Snapshot::After
        assert_equal stack_ary[9].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=b>}
        assert_equal stack_ary[9].data[:snapshot_before], stack_ary[8]

        # _activity
        assert_equal stack_ary[10].class, Trailblazer::Developer::Trace::Snapshot::Before
        assert_equal stack_ary[10].task, _activity
          assert_equal stack_ary[11].class, Trailblazer::Developer::Trace::Snapshot::Before
          assert_equal stack_ary[11].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
          assert_equal stack_ary[12].class, Trailblazer::Developer::Trace::Snapshot::After
          assert_equal stack_ary[12].task.inspect, %{#<Trailblazer::Activity::Start semantic=:default>}
          assert_equal stack_ary[12].data[:snapshot_before], stack_ary[11]

          assert_equal stack_ary[13].class, Trailblazer::Developer::Trace::Snapshot::Before
          assert_equal stack_ary[13].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}
          assert_equal stack_ary[14].class, Trailblazer::Developer::Trace::Snapshot::After
          assert_equal stack_ary[14].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=c>}
          assert_equal stack_ary[14].data[:snapshot_before], stack_ary[13]

          assert_equal stack_ary[15].class, Trailblazer::Developer::Trace::Snapshot::Before
          assert_equal stack_ary[15].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=d>}
          assert_equal stack_ary[16].class, Trailblazer::Developer::Trace::Snapshot::After
          assert_equal stack_ary[16].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=d>}
          assert_equal stack_ary[16].data[:snapshot_before], stack_ary[15]

          assert_equal stack_ary[17].class, Trailblazer::Developer::Trace::Snapshot::Before
          assert_equal stack_ary[17].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
          assert_equal stack_ary[18].class, Trailblazer::Developer::Trace::Snapshot::After
          assert_equal stack_ary[18].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
          assert_equal stack_ary[18].data[:snapshot_before], stack_ary[17]

        assert_equal stack_ary[19].class, Trailblazer::Developer::Trace::Snapshot::After
        assert_equal stack_ary[19].task, _activity
        assert_equal stack_ary[19].data[:snapshot_before], stack_ary[10]

        assert_equal stack_ary[20].class, Trailblazer::Developer::Trace::Snapshot::Before
        assert_equal stack_ary[20].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
        assert_equal stack_ary[21].class, Trailblazer::Developer::Trace::Snapshot::After
        assert_equal stack_ary[21].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
        assert_equal stack_ary[21].data[:snapshot_before], stack_ary[20]

      assert_equal stack_ary[22].class, Trailblazer::Developer::Trace::Snapshot::After
      assert_equal stack_ary[22].task, sub_activity
      assert_equal stack_ary[22].data[:snapshot_before], stack_ary[5]

      assert_equal stack_ary[23].class, Trailblazer::Developer::Trace::Snapshot::Before
      assert_equal stack_ary[23].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=e>}
      assert_equal stack_ary[24].class, Trailblazer::Developer::Trace::Snapshot::After
      assert_equal stack_ary[24].task.inspect, %{#<Trailblazer::Activity::TaskBuilder::Task user_proc=e>}
      assert_equal stack_ary[24].data[:snapshot_before], stack_ary[23]

      assert_equal stack_ary[25].class, Trailblazer::Developer::Trace::Snapshot::Before
      assert_equal stack_ary[25].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal stack_ary[26].class, Trailblazer::Developer::Trace::Snapshot::After
      assert_equal stack_ary[26].task.inspect, %{#<Trailblazer::Activity::End semantic=:success>}
      assert_equal stack_ary[26].data[:snapshot_before], stack_ary[25]

    assert_equal stack_ary[27].class, Trailblazer::Developer::Trace::Snapshot::After
    assert_equal stack_ary[27].task, activity
    assert_equal stack_ary[27].data[:snapshot_before], stack_ary[0]

    assert_equal stack.to_a.size, 28
  end
end
