# frozen_string_literal: true

module MPS
  module Engines
    class EngineError < StandardError;end;
    class MPS
      attr_reader :logger
      attr_reader :element_classes
      attr_reader :interpolator_classes
      def initialize(config)
        @config = config
        @element_classes = ::MPS::Elements.constants.map{|k|eval("::MPS::Elements::#{k}")}.select{|x|x.class==Class}
        @interpolator_classes = ::MPS::Interpolators.constants.map{|k|eval("::MPS::Interpolators::#{k}")}.select{|x|x.class==Class}
        @logger = @config.logger
      end

      def parse_mps(mps_file_path)
        self.class.parse_mps_file_to_elements_hash(mps_file_path, self.element_classes)
      end

      def self.matched_element_class(str, element_classes)
        element_classes.each do |ec|
          return ec if str=~ec::SIGNATURE_REGEX
        end
        return nil
      end

      def self.look_ahead_pos(str_scanner, regex_la)
        pos = str_scanner.string.size
        if str_scanner.scan_until(regex_la)
          pos = str_scanner.pos
          str_scanner.unscan
        end
        return pos
      end

      def self.parse_mps_file_to_elements_hash(mps_file_path, element_classes)
        main_str = File.read(mps_file_path)
        # add elements::mps signature
        main_str = "@#{::MPS::Elements::MPS::SIGNATURE_STAMP}[]{"+main_str+"}"
        str_scanr = StringScanner.new(main_str)
        base_refs = ::MPS::Constants::MPS_FILE_NAME_TO_REF_PARSER.call(File.basename(mps_file_path)).map(&:to_i)
        base_refs_size = base_refs.length
        refs = [*base_refs]
        elements_hash = {}
        stack = []
        at_first = true
        element = nil

        offset_size = 0
        disp_str = main_str.clone()

        while !str_scanr.eos?
          # at_signature is found first
          #   -> determine the starting position of @
          #   -> determine the main body starting position eg. position just the {
          #   -> parse element sign and args
          #   -> push it to the stack
          if at_first && str_scanr.scan_until(::MPS::Constants::AT_REGEXP_LA)
            s_pos = str_scanr.pos
            str_scanr.scan_until(::MPS::Constants::AT_REGEXP)
            matched_data = str_scanr.string[s_pos..str_scanr.pos-1].match(::MPS::Constants::AT_REGEXP)
            # puts("matched: #{matched_data.inspect}")
            element_class = self.matched_element_class(matched_data["element_sign"], element_classes)

            element_class = matched_data["element_sign"] if element_class==nil
            stack << {
              element_class: element_class,
              element_args: matched_data["args"],
              body_start_pos: str_scanr.pos,
              elm_start_pos: s_pos
            }
          
          # ending curly } is found first and stack not empty
          #   -> pop out stack
          #   -> determine ending position
          #   -> determine main body string
          #   -> create element obj
          #   -> determine offset and display string
          #   -> set display string buffer.
          elsif !at_first && str_scanr.scan_until(::MPS::Constants::END_CURLY_REGEXP) && !stack.empty?
            stack_top = stack.pop()
            stack_top[:end_pos] = str_scanr.pos-1
            body_str = str_scanr.string[stack_top[:body_start_pos]...stack_top[:end_pos]]
            
            # call corresponding element class to create element instance
            trefs = refs.clone()
            if stack_top[:element_class].class!=Class
              element = Struct.new(:ecn, :args, :refs, :body_str).new(
                stack_top[:element_class],
                stack_top[:element_args],
                trefs,
                body_str
              )
              element.class.instance_eval("attr_accessor :disp_str")
              element.disp_str = element.body_str
            else
              element = stack_top[:element_class].new(args: stack_top[:element_args], refs: trefs, body_str: body_str)
            end

            print("\n\nElement Display String\n")
            puts("refs: #{refs.inspect}")
            puts("stack_top[:body_start_pos]: #{stack_top[:body_start_pos]}")
            puts("stack_top[:end_pos]: #{stack_top[:end_pos]}")
            puts("stack_top[:elm_start_pos]: #{stack_top[:elm_start_pos]}")
            puts("offset_size: #{offset_size}")
            puts("disp_str: #{disp_str}")
  
            elm_disp_str = ::MPS::Elements::Element.display_str(
              disp_str[(stack_top[:body_start_pos]+offset_size)...(stack_top[:end_pos]+offset_size)], 
              refs.size-base_refs_size
            )
            
            puts("disp_str[element_start_pos]: #{disp_str[(stack_top[:elm_start_pos]+offset_size)]}")
            puts("dis_str[body_start_pos]: #{disp_str[(stack_top[:body_start_pos]+offset_size)]}")
            puts("disp_str[element_end_pos]: #{disp_str[(stack_top[:end_pos]+offset_size)]}")
            gets
            disp_str[(stack_top[:elm_start_pos]+offset_size)..(stack_top[:end_pos]+offset_size)] = elm_disp_str
            element.disp_str = elm_disp_str
            offset_size += (elm_disp_str.size - (stack_top[:end_pos]-stack_top[:elm_start_pos]+1))

            # offset debug
            element.class.instance_eval("attr_accessor :offset")
            element.offset = offset_size


            ref = refs.join(".")
            elements_hash[ref] = element
            refs[-1] += 1
          end

          at_pos = self.look_ahead_pos(str_scanr, ::MPS::Constants::AT_REGEXP_LA)
          ec_pos =  self.look_ahead_pos(str_scanr, ::MPS::Constants::END_CURLY_REGEXP_LA)

          min_pos = [at_pos, ec_pos].min

          if min_pos==at_pos and at_first
            refs << 1
          elsif min_pos==ec_pos and !at_first
            refs.pop()
          end
          at_first = (min_pos==at_pos)
          str_scanr.pos = min_pos
        end
        
        return elements_hash
      end
    end
  end
end
