require "representable/hash"
require "trailblazer/activity/dsl/linear" # Railway.

module Trailblazer
  module Developer
    # Computes an {Intermediate} data structure from a TRB-editor.js file.
    module Generate
      module_function

      Element = Struct.new(:id, :type, :linksTo, :data, :label, :parent)
      Arrow   = Struct.new(:target, :label, :message)

      module Representer
        class Activity < Representable::Decorator
          include Representable::Hash

          collection :elements, class: Element do
            property :id
            property :type
            collection :linksTo, class: Arrow, default: [] do
              property :target
              property :label
              property :message
            end
            property :data, default: {}

            property :label
            property :parent # TODO: remove?
          end
        end
      end

      def call(hash)
        signal, (ctx, _) = Activity::TaskWrap.invoke(Pipeline, hash: hash)
        ctx[:intermediate]
      end

      def transform_from_hash(ctx, hash:, parser: Representer::Activity, **)
        ctx[:elements] = parser.new(OpenStruct.new).from_hash(hash).elements
      end

      def find_start_events(ctx, elements:, **)
        ctx[:start_events] = elements.find_all { |el| el.type == "Event" }
      end

      def compute_intermediate(ctx, elements:, start_events:, **)
        end_events   = elements.find_all { |el| el.type == "EndEventTerminate" } # DISCUSS: is it really called TERMINATE?

        inter = Activity::Schema::Intermediate

        wiring = elements.collect { |el|
          data = data_for(el)

          [inter.TaskRef(el.id, data), el.linksTo.collect { |arrow| inter.Out(semantic_for(arrow.to_h), arrow.target) } ] }
        wiring = Hash[wiring]

        # end events need this stupid special handling
        # DISCUSS: currently, the END-SEMANTIC is read from the event's label.
        wiring = wiring.merge(Hash[
          end_events.collect do |_end|
            ref, outputs = wiring.find { |ref, _| ref.id == _end.id }

            [ref, [inter.Out(semantic_for(_end.to_h)|| raise, nil)]] # TODO: test the raise, happens when the semantic of an End can't be distinguished. # TODO: don't extract semantic from :label but from :data.
          end
        ])
        # pp wiring

        ctx[:intermediate] = inter.new(wiring, end_events.collect(&:id), start_events.collect(&:id))
      end

      # private

      def data_for(element)
        {type: element.type}.merge(element.data)
      end

      # We currently use the {:label} field of an arrow to encode an output semantic.
      # The {:symbol_style} part will be filtered out as semantic. Defaults to {:success}.
      def semantic_for(label:nil, **)
        return :success unless label

        extract_semantic(label)
      end

      def extract_semantic(label)
        label.to_sym
      end

      class Pipeline < Trailblazer::Activity::Railway
        step Generate.method(:transform_from_hash),   id: :transform_from_hash
        step Generate.method(:find_start_events),     id: :find_start_events
        step Generate.method(:compute_intermediate),  id: :compute_intermediate
      end
    end
  end
end
# [Inter::Out(:success, nil)]
