# 0.0.30

* Introduce the concept of `Snapshot` which can be a moment in time before or after a step.
  `Captured::Input`/`Captured::Output` are now `Snapshot::Before` and `Snapshot::After`.
* Rename `:output_data_collector` and `:input_data_collector` to `:after_snapshooter` and `:before_snapshooter`
  as they both produce instances of `Snapshot`.
* Add `Snapshot::Ctx` which is a new, faster way of capturing variables in ctx before and after a step.

# 0.0.29

* The `:render_method` callable can now return output along with additional returned values.
* Pass the top-level `:activity` into the `:render_method`.
* In `#wtf?`, only complete the stack when an exception occurred.
* `wtf?` now returns all original return values plus the computed output from `:render_method`,
  followed by an arbitrary object from the rendering code.

# 0.0.28

* Move `Introspect::Graph` over from `trailblazer-activity`. It's a data structure very specific
  to rendering, which is not a part of pure runtime behavior.
* Use `Introspect.Nodes` API instead of `TaskMap`.
* Remove `:task_maps_per_activity` in `Debugger` as we don't need to cache anymore.
* Require `trailblazer-activity-dsl-linear-1.2.0`.
* Remove `Render::Circuit` as this is part of `trailblazer-activity` now.

# 0.0.27

## Trace

* `Trace.capture_args` and `capture_return` no longer use any `Graph` logic. This
  is moved to `Trace::Present` instead to reduce complexity at crunch time.
* Removed the `:focus_on` option for `#wtf?`. This is now solved through the debugger.
* `Trace.default_input_collector` and `default_output_collector` now receive the original taskWrap/pipeline-args
  `[wrap_ctx, original_args]`.
* In `Trace::Present.call` it's now possible to provide labels to the `default_renderer` using the `:label` option.
* `Circuit.render` now accepts segments/path.
* Fixed a bug in `Trace::Present` where the traced top activity would show up as a node, which was wrong.
* Rename `Trace::Entity` to `Trace::Captured`.
* Removed `:position` keyword in `Trace::Renderer` and friends.
* Changed `Trace::Stack` from a nested datastructure to a linear `Captured` stack.

## Debugger

* Add `Debugger::Node` as an interface and datastructure between tracing (`Stack` and `Captured`) and `Present`,
  the latter now having access to `Debugger::Node`, only.
* Add `Debugger::Normalizer`, which computes default values for `Debugger::Node` at present-time.

## Internals

* Use `trailblazer-activity-dsl-linear-1.0.0`.

# 0.0.26

* Fixing release, and allow using beta versions.

# 0.0.25

* Use `trailblazer-activity-dsl-linear` >= 1.0.0.beta1. This allows using this gem for testing beta versions.

# 0.0.24

* Use `trailblazer-activity-dsl-linear` >= 1.0.

# 0.0.23

* Remove `representable` dependency.
* Moved all editor-specific code to the `pro` gem (`client.rb` and `generate.rb`).

# 0.0.22

* Upgrade trb-activity, trb-activity-dsl-linear and representable versions.

# 0.0.21

* Ruby 3.0 support. :sunset:

# 0.0.20

* Ruby 2.7 support

# 0.0.17

* Add `Arrow.target_lane` field in the `Generate` component.

# 0.0.16

* Remove Declarative warning correctly

# 0.0.15

* Fix `Dev.wtf` circuit interface definition

# 0.0.14

* Revert declarative warning changes

# 0.0.13

* Allow focusing on selected variables for all steps in wtf
* Fix declarative deprecation warning

# 0.0.12

* Revert Hash#compact usage to support Rubies <= 2.4

# 0.0.11

* Allow injecting custom data collector in Trace API, to collect custom input/output ctx of task nodes.
* Allow focusing on specfic steps and ctx variables in Dev.wtf?
* Allow custom inspection while tracing using Inspector definations

# 0.0.10

* Make Generate::Pipeline an activity for better customization/extendability.

# 0.0.9

* `Render.strip` is now a class method.
* Added the `.type` field to the `data` field in `Generate`.

# 0.0.8

* Fix `Introspect` references.

# 0.0.7

* Move `Activity::Trace` and `Activity::Present` from `activity` to `developer`.
* Remove global configurations and use `flow_options` to override defaults in `wtf?`.

# 0.0.6

* Remove ID extraction logic from `Generate`, this is done on the server-side.
* Print `wtf` trace in all cases (with or without exception)
* Allow color configuration in `wtf` trace

# 0.0.5

* Introduce `:query` option for `Client.import`.
* In `Generate`, added `Element.parent` field.
* No more magic is applied when extracting the ID/semantic. We just use the plain string.

# 0.0.4

* Allow injecting `:parser` into `Generate.transform_from_hash`.

# 0.0.3

* Add `Developer.railway`.

# 0.0.2

* Add `Developer.render` shortcut to `Render::Circuit`.

# 0.0.1

* Initial release into an unsuspecting world.
