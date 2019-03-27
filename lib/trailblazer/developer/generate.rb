require "representable/hash"

module Trailblazer
  module Developer
    module Generate
      module_function

      Element = Struct.new(:id, :type, :linksTo)
      Link    = Struct.new(:target)

      module Representer
        class Activity < Representable::Decorator
          include Representable::Hash

          collection :elements, class: Element do
            property :id
            property :type
            collection :linksTo, class: Link do
              property :target
            end
          end
        end
      end

      def call(hash)
        elements = Representer::Activity.new(OpenStruct.new).from_hash(hash).elements

        start_events = elements.find_all { |el| el.type == "Event" }
        end_events   = elements.find_all { |el| el.type == "EndEventTerminate" }# DISCUSS: TERMINATE?

        inter = Activity::Intermediate

        inter.new(
          {
            inter::TaskRef(:a) => [inter::Out(:success, :b)],
            inter::TaskRef(:b) => [inter::Out(:success, "End.success")],
            inter::TaskRef("End.success", stop_event: true) => [inter::Out(:success, nil)], # this is how the End semantic is defined.
          },
          [
            "End.success",
            # "End.failure",
          ],
          [:a] # start
        )

        pp elements
      end
    end
  end
end
