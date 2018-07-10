require "representable"
require "representable/json"

module Trailblazer
  module Diagram
    module JSON
      COLLABORATION_TYPES = %i[participant message_flow].freeze
      PROCESS_TYPES = %i[start_event task sequence_flow end_event].freeze
      SHAPE_TYPES = %i[participant message_flow start_event task sequence_flow end_event].freeze

      Definition    = Struct.new(:collaboration, :process, :diagram)

      Collaboration = Struct.new(:id, :type, :name, :process, :source, :target)
      Process       = Struct.new(:id, :type, :name, :incoming, :outgoing, :source, :target)
      Shape         = Struct.new(:id, :type, :bounce, :waypoint)
      Bounce        = Struct.new(:x, :y, :width, :height)
      Waypoint      = Struct.new(:x, :y)

      WrongType = Class.new(StandardError)
      MissingInput = Class.new(StandardError)

      class Model < Definition
        # DISUCSS: should collaboration and process be plural because are collections?
        def initialize
          super([], [], Struct.new(:shape).new([]))
        end

        # rubocop:disable Metrics/ParameterLists
        def add_collaboration(id:, type:, name: nil, process: nil, source: nil, target: nil)
          validate_type(type, COLLABORATION_TYPES)

          validate_inputs(Array[process, source, target])

          self[:collaboration] << Collaboration.new(id, type, name, process, source, target)
        end

        def add_process(id:, type:, name: nil, incoming: nil, outgoing: nil, source: nil, target: nil)
          validate_type(type, PROCESS_TYPES)

          validate_inputs(Array[incoming, outgoing, source, target])

          self[:process] << Process.new(id, type, name, incoming, outgoing, source, target)
        end
        # rubocop:enable Metrics/ParameterLists

        # bounce and waypoint can be an array of hashes or just an hash
        def add_shape(id:, type:, bounce: nil, waypoint: nil)
          validate_type(type, SHAPE_TYPES)

          validate_inputs(Array[bounce, waypoint])

          waypoints = wrap(waypoint).map do |a|
            Waypoint.new(a[:x], a[:y])
          end

          self[:diagram][:shape] << Shape.new(
            id,
            type,
            Bounce.new(bounce[:x], bounce[:y], bounce[:width], bounce[:height]),
            waypoints
          )
        end

        private

        # allows to pass an hash or an array of hashes
        def wrap(object)
          if object.nil?
            []
          elsif object.is_a? Array
            object
          else
            [object]
          end
        end

        def validate_type(type, types)
          raise WrongType, "#{type} must be one of: #{types.join(", ")}" unless types.include? type
        end

        def validate_inputs(inputs)
          raise MissingInput, "One of #{inputs} must be passed" unless inputs.any?
        end
      end

      def self.to_json(model)
        Representer::Definition.new(model).to_json
      end

      module Representer
        class Definition < Representable::Decorator
          include Representable::JSON

          collection :collaboration do
            property :id
            property :type
            property :name
            property :process
            property :source
            property :target
          end

          collection :process do
            property :id
            property :type
            property :name
            property :incoming
            property :outgoing
            property :source
            property :target
          end

          property :diagram do
            collection :shape do
              property :id
              property :type # or bpmn element which could be same process types

              property :bounce do
                property :x
                property :y
                property :width
                property :height
              end

              collection :waypoint do
                property :x
                property :y
              end
            end
          end
        end
      end
    end
  end
end
