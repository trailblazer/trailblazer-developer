module Trailblazer
  module Developer
    module_function

    def render(value, *args, **options)
      renderer_for(value).(value, *args, **options)
    end

    # private
    def renderer_for(value)
      return Render::Context if value.is_a?(Trailblazer::Context::Container)
      Render::Circuit
    end
  end
end
