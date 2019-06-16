require "representable/hash"

module Trailblazer
  module Developer
    # Computes an {Intermediate} data structure from a TRB-editor.js file.
    module Generate
      module_function

      Element = Struct.new(:id, :type, :linksTo, :data, :label)
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
          end
        end
      end

      def call(hash)
        elements = transform_from_hash(hash)
        elements = remap_ids(elements)

        compute_intermediate(elements)
      end

      def transform_from_hash(hash)
        Representer::Activity.new(OpenStruct.new).from_hash(hash).elements
      end

      def find_start_events(elements)
        elements.find_all { |el| el.type == "Event" }
      end

      def compute_intermediate(elements, find_start_events: method(:find_start_events))
        start_events = find_start_events.(elements)
        end_events   = elements.find_all { |el| el.type == "EndEventTerminate" } # DISCUSS: is it really called TERMINATE?

        inter = Activity::Schema::Intermediate

        wiring = elements.collect { |el| [inter.TaskRef(el.id, el.data), el.linksTo.collect { |arrow| inter.Out(semantic_for(arrow.to_h), arrow.target) } ] }
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

        inter.new(wiring, end_events.collect(&:id), start_events.collect(&:id))
      end

      # private



      # We currently use the {:label} field of an arrow to encode an output semantic.
      # The {:symbol_style} part will be filtered out as semantic. Defaults to {:success}.
      def semantic_for(label:nil, **)
        return :success unless label

        extract_semantic(label)
      end

      def extract_semantic(label)
        m = label.match(/:([^\s][\w\?!]+)/) or return
        return m[1].to_sym
      end

      def extract_string_id(label)
        m = label.match(/"(.+)"/) or return
        return m[1].to_sym
      end

      def extract_id(label)
        extract_string_id(label) || extract_semantic(label)
      end

      # remap {id}
      def remap_ids(elements)
        map = {}

        elements.collect do |el|
          id = (el.label && semantic = extract_id(el.label)) ? semantic : el.id.to_sym

          map[el.id] = id

          el.id = id
        end

        # remap {linksTo}
        elements.collect do |el|
          el.linksTo.collect do |link|
            link.target = map[link.target]
          end
        end

        elements
      end
    end
  end
end
# [Inter::Out(:success, nil)]