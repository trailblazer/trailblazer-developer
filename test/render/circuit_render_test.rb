require "test_helper"

class RenderCircuitTest < Minitest::Spec
  def normalize_macro_interface; end
  def is_step?; end
  def normalize_id_for_step; end
  def build_node_for_task; end
  def build_node_for_step; end
  def build_task_wrap_pipeline; end
  def normalize_magnetic_to; end
  def normalize_prepositions; end
  def normalize_adds_insertion_args; end
  def build_task_wrap_node; end
  def build_sequence_row; end
  def compile_adds_for_sequence; end

  it "what" do
    my_circuit = Trailblazer::Circuit::Builder.Circuit(
      [:normalize_macro_interface, method(:normalize_macro_interface)],
      [:is_step?, method(:is_step?), connections: {Trailblazer::Activity::Left => [:build_node_for_task, Trailblazer::Activity::Left], Trailblazer::Activity::Right => [:normalize_id_for_step, Trailblazer::Activity::Right]}],
      [:normalize_id_for_step, method(:normalize_id_for_step), connections: {nil => :build_node_for_step}], # DISCUSS: what if we need to know what
      [:build_node_for_task, method(:build_node_for_task), connections: {nil => :build_task_wrap_pipeline}],
      [:build_node_for_step, method(:build_node_for_step), connections: {nil => :build_task_wrap_pipeline}],
      [:build_task_wrap_pipeline, method(:build_task_wrap_pipeline)],
      [:normalize_magnetic_to, method(:normalize_magnetic_to)], # DISCUSS: position?
      [:normalize_prepositions, method(:normalize_prepositions)],
      [:normalize_adds_insertion_args, method(:normalize_adds_insertion_args)], # DISCUSS: position?
      [:build_task_wrap_node, method(:build_task_wrap_node)],
      [:build_sequence_row, method(:build_sequence_row)],
      [:compile_adds_for_sequence, method(:compile_adds_for_sequence)],
    )

    puts Trailblazer::Developer::Render::Circuit.(my_circuit)

    assert_equal Trailblazer::Developer::Render::Circuit.(my_circuit), %(
asf
)
  end
end
