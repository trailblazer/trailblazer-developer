module Trailblazer
  module Developer
    module Introspect
      # find the path for Strategy subclasses.
      # FIXME: will be removed
      def self.find_path(activity_class, segments)
        activity = activity_class.is_a?(Object) && activity_class.instance_of?(Trailblazer::Activity) ? activity_class : activity_class.to_h[:activity] # FIXME: not a real fan of this, maybe always do {to_h[:activity]}
          node, activity, graph = Activity::Introspect.find_path(activity, segments)
        activity = activity.is_a?(Object) && activity.instance_of?(Trailblazer::Activity) ? activity : activity.to_h[:activity] # FIXME: not a real fan of this, maybe always do {to_h[:activity]}

        return node, activity, graph
      end
    end
  end
end
