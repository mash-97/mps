# frozen_string_literal: true

module MPS
  module Engines
    class EngineError < StandardError; end

    class Parser
      # Holds an unknown element type (sign not in registered element_classes).
      Unknown = Struct.new(:ecn, :args, :refs, :body_str)

      attr_reader :logger
      attr_reader :element_classes
      attr_reader :interpolator_classes

      def initialize(config)
        @config = config
        @element_classes = ::MPS::Elements.constants
          .map    { |k| ::MPS::Elements.const_get(k) }
          .select { |x| x.class == Class }
        @interpolator_classes = ::MPS::Interpolators.constants
          .map    { |k| ::MPS::Interpolators.const_get(k) }
          .select { |x| x.class == Class }
        @logger = @config.logger
      end

      # Returns the element class whose SIGNATURE_REGEX matches +str+, or nil.
      def self.matched_element_class(str, element_classes)
        element_classes.find { |ec| str =~ ec::SIGNATURE_REGEX }
      end

      # Parses +mps_file_path+ into a flat hash of ref-path => element instances.
      # Applies interpolators to body strings if +interpolator_classes+ are provided.
      def self.parse_mps_file_to_elements_hash(mps_file_path, element_classes,
                                               interpolator_classes: [])
        content  = File.read(mps_file_path)
        wrapped  = "@#{::MPS::Elements::MPS::SIGNATURE_STAMP}[]{\n#{content}\n}"
        base_ref = ::MPS::Constants::MPS_FILE_NAME_CLIPPER
                     .call(File.basename(mps_file_path)).to_i

        open_re  = ::MPS::Constants::AT_REGEXP
        close_re = ::MPS::Constants::END_CURLY_REGEXP

        elements = {}
        stack    = []
        pos      = 0

        while pos < wrapped.size
          open_m  = open_re.match(wrapped, pos)
          close_m = close_re.match(wrapped, pos)

          break if open_m.nil? && close_m.nil?

          use_open = open_m && (close_m.nil? || open_m.begin(0) < close_m.begin(0))

          if use_open
            ref_path = if stack.empty?
              [base_ref]
            else
              parent = stack.last
              parent[:child_counter] += 1
              parent[:ref_path] + [parent[:child_counter]]
            end

            stack.push(
              sign:          open_m[:element_sign],
              args:          open_m[:args],
              body_start:    open_m.end(0),
              child_counter: 0,
              ref_path:      ref_path
            )
            pos = open_m.end(0)
          else
            break if stack.empty?

            frame    = stack.pop
            body_str = wrapped[frame[:body_start]...close_m.begin(0)]
            ref_key  = frame[:ref_path].join(".")
            ec       = matched_element_class(frame[:sign], element_classes)

            elements[ref_key] = if ec
              ec.new(args: frame[:args], refs: frame[:ref_path], body_str: body_str)
            else
              Unknown.new(frame[:sign], frame[:args], frame[:ref_path], body_str)
            end

            pos = close_m.end(0)
          end
        end

        _apply_interpolations(elements, interpolator_classes) unless interpolator_classes.empty?
        elements
      end

      # Apply registered interpolators to the body_str of each element.
      def self._apply_interpolations(elements, interpolator_classes)
        return if interpolator_classes.empty?
        elements.each_value do |el|
          next unless el.respond_to?(:body_str)
          body = el.instance_variable_get(:@body_str)
          next unless body
          interpolator_classes.each do |ic|
            obj = ic.new
            new_body = body.gsub(ic::SIGNATURE_REGEX) { obj.get_str }
            el.instance_variable_set(:@body_str, new_body) if new_body != body
            body = new_body
          end
        end
      end

      class << self
        alias parse_mps_file_to_elments_hash parse_mps_file_to_elements_hash
      end
    end

    # Backward-compatible alias — existing code using Engines::MPS still works.
    MPS = Parser
  end
end
