module Trailblazer
  module Developer
    module_function

    def render(activity, path: nil, **options)
      if path # TODO: move to place where all renderers can use this logic!
        node, _, graph   = Developer::Introspect.find_path(activity, path)
        activity = node.task
      end

      Activity::Introspect::Render.(activity, **options)
    end
  end
end
