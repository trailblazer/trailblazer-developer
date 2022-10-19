module Trailblazer
  module Developer

    module Introspect 
      # DISCUSS: maybe this should sit in Activity, and be merged with patch logic.
      # @private
      def self.find_path(activity, segments)
        node = nil
        segments.each do |segment| # TODO: use logic from Activity/patch.
          node = Trailblazer::Activity::Introspect.Graph(activity).find(segment) or return
          activity = node.task
        end

        node
      end

    end
  end
end
