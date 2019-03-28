require "representable/hash"

module Trailblazer
  module Developer
    # Computes an {Intermediate} data structure from a TRB-editor.js file.
    module Generate
      module_function

      Element = Struct.new(:id, :type, :linksTo, :data, :label)
      Arrow   = Struct.new(:target, :label)

      module Representer
        class Activity < Representable::Decorator
          include Representable::Hash

          collection :elements, class: Element do
            property :id
            property :type
            collection :linksTo, class: Arrow, default: [] do
              property :target
              property :label
            end
            property :data, default: {}
            property :label
          end
        end
      end

      def call(hash)
        elements = Representer::Activity.new(OpenStruct.new).from_hash(hash).elements

        start_events = elements.find_all { |el| el.type == "Event" }
        end_events   = elements.find_all { |el| el.type == "EndEventTerminate" }# DISCUSS: TERMINATE?

        inter = Activity::Schema::Intermediate

        wiring = elements.collect { |el| [inter.TaskRef(el.id, el.data), el.linksTo.collect { |arrow| inter.Out(semantic_for(arrow.to_h), arrow.target) } ] }
        wiring = Hash[wiring]

        # end events need this stupid special handling
        wiring = wiring.merge(Hash[
          end_events.collect do |_end|
            ref, outputs = wiring.find { |ref, _| ref.id == _end.id }

            [ref, [inter.Out(semantic_for(_end.to_h), nil)]]
          end
        ])
        # pp wiring

        inter.new(wiring, end_events.collect(&:id), start_events.collect(&:id))
      end

      # private

      # We currently use the {:label} field of an arrow to encode an output semantic.
      # The {:symbol_style} part will be filtered out as semantic. Defaults to {:success}.
      def semantic_for(label:nil, **)
        return :success unless label

        m = label.match(/:(\w+)/)
        return m[1].to_sym
      end
    end
  end
end
# [Inter::Out(:success, nil)]
