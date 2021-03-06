# encoding: utf-8

require 'typogrowth'

require_relative "../constants"
require_relative '../utils/logging'

require_relative 'monkeypatches'

# @author Alexei Matyushkin
module Qipowl::Bowlers

  # Base class for all the parsers.
  #
  # Technically it may be instantiated, but that’s meaningless.
  # Main operation method for it and all the descendants is
  # {#parse}. It sequentially executes following
  # private methods:
  #
  # - {#defreeze}
  # - {#roast}
  # - {#serveup}
  #
  # Normally the developer does not need to interfere the {#roast}
  # method which proceeds the input string. To prepare the input
  # for +evaluation+ one overwrites {#defreeze}, for some afterwork
  # the {#serveup} method is here.
  #
  # Descendants are supposed to overwrite {#method_missing} for some
  # custom processing and introduce DSL methods, which will be executed
  # by `eval` inside the {#roast} method.
  #
  # Instance variables `:in` and `:out` are here to gain an access to
  # the last interpreted input string and the result of evaluation
  # respectively.
  #
  class Bowler
    include TypoLogging

    attr_reader :in, :out

    # Internal constant for joining/splitting the strings during processing.
    # Override on your own risk. I can′t imagine why you would need to do so.
    SEPARATOR = $, || ' '

    def execute str
      @out = (serveup roast defreeze @in = str)
    end

    # Everything is a DSL, remember?
    #
    # @return true
    def respond_to? method, incl_priv = false
      true
    end

    # Everything is a DSL, remember? Even constants.
    # @todo This fails to do with DSLing words, beginning with capitals :-(
    #
    # @return the constant name as is
    def self.const_missing name
      raise "There was CONST [#{name}] met. Stupid programming error."
      name
    end

    # If somebody needs to interfere the standard processing,
    # she supposed to introduce `special_handler` method. The descendants
    # will be processed before standard operation (which in fact simply
    # collects words within an array one by one.)
    def method_missing method, *args, &block
      method, *args = special_handler(method, *args, &block) \
        if self.private_methods.include?(:special_handler)
      [method, args].flatten
    end

    # Adds new +entity+ in the section specified.
    # E. g., call to
    #
    #     add_spice :linewide, :°, :deg, :degrees
    #
    # in HTML implementation adds a support for specifying something like:
    #
    #     ° 15
    #     ° 30
    #     ° 45
    #
    # which is to be converted to the following:
    #
    #     <degrees>
    #       <deg>15</deg>
    #       <deg>30</deg>
    #       <deg>45</deg>
    #     </degrees>
    #
    # @param [Symbol] section the section (it must be one of {Mapping.SPICES}) to add new key to
    # @param [Symbol] key the name for the key
    # @param [Symbol] value the value
    # @param [Symbol] enclosure_value optional value to be added for the key into enclosures section
    def add_entity section, key, value, enclosure_value = null
      if (tags = self.class.const_get("#{section.upcase}_TAGS"))
        key = key.bowl.to_sym
        tags[key] = value.to_sym
        self.class.const_get("ENCLOSURES_TAGS")[key] = enclosure_value.to_sym if enclosure_value
        self.class.const_get("ENTITIES")[section.to_sym][key] = value.to_sym
        self.class.class_eval %Q{
          alias_method :#{key}, :∀_#{section}
        } # unless self.class.instance_methods(true).include?(key.bowl)
        @shadows = nil
      else
        logger.warn "Trying to add key “#{key}” in an invalid section “#{section}”. Ignoring…"
      end
    end

    # Removes key from both {Mapping.SPICES} and {Mapping.SALT}. See {#add_spice}
    #
    # @param [Symbol] entity the key to be removed
    def remove_entity entity
      key = entity.to_sym
      Qipowl::ENTITIES.each { |section|
        next unless (curr_sect = self.class.const_get("#{section.upcase}_TAGS") rescue nil)
        curr_tag = send(:"∃_#{section}", key)
        next unless curr_tag

        curr_sect.delete key
        self.class.const_get("ENCLOSURES_TAGS").delete key
        self.class.const_get("ENTITIES")[section.to_sym].delete key

        self.class.class_eval %Q{
          remove_method :#{key.bowl}
        }
        @shadows = nil
      }
    end

  protected
    Qipowl::ENTITIES.each { |section|
      define_method "∀_#{section}".to_sym, ->(*args) {
        raise "Default method for #{section} (“#{self.class.name.gsub(/_\d+\Z/, '')}#∀_#{section}”) MUST be defined"
      } unless Bowler.instance_methods(true).include?("∀_#{section}".to_sym)
    }

    def defreeze str
      str.typo(sections: :quotes).defuse
    end

    def roast str
      (split str).map { |dish|
        @yielded = []
        rest = begin
          eval(dish.bowl.carriage)
        rescue Exception => e
          msg = e.message.dup
          logger.error '='*78
          logger.error "Could not roast dish [#{msg.force_encoding(Encoding::UTF_8)}].\nWill return as is… Backtrace:\n"
          logger.error e.backtrace.take(Qipowl::BTRACE_COUNT).join("\n")
          logger.error '-'*78
          logger.error "Dish follows:\n"
          logger.error '-'*78
          logger.error dish
          logger.error '='*78
          [*dish]
        end
        harvest(nil, orphan([*rest].join(SEPARATOR))) # FIXME Check if this is correct in all the cases
        @yielded.pop(@yielded.size).reverse.join(SEPARATOR)
      }.join($/).uncarriage.un␚ify.unspacefy.unbowl
    end

    def serveup str
      str.gsub(/⌦./, '').gsub(/.⌫/, '').typo
    end

  protected
    # The handler of the last “orphaned” text block in the input string.
    #
    # E.g.:
    #
    #     Here goes a quite significant list:
    #
    #     • line item 1
    #      • nested li1
    #      • nested li 2
    #     • line item 2
    #
    # While all line items are operated by `•` method, the top sentence
    # is orphaned (has no prepnding DSL method to be called on.)
    # Since we still need to handle it somehow, the {#orphan} method is here.
    #
    # @param [String] str the string to be operated “bu default rule”
    # @return [String] the processed input (in derivatives, here it returns the untouched input string itself)
    def orphan str
      str
    end

    # The handler for harvesting partial result.
    #
    # Processing sometimes calls this method, designating the meaningful
    # part of input text is done and should be yielded. E.g. when the
    # block of code is processed:
    #
    #     Λ ruby
    #       @mapping[:inplace].each { |tag, htmltag|
    #         do_smth tag, htmltag
    #       }
    #     Λ
    #
    # After we have this part of input processed, it should be considered
    # “done.” So block processors call {#harvest} to store processed parts.
    #
    # @param [Symbol] cally of this method. Qipowl hardly relies on method namings and sometimes we may need to know if the call was made by, say, lineitem DSL (`•`), not datalist (`▷`).
    # @param [String] str string to yield
    #
    # @return nil
    def harvest cally, str
      @yielded << str unless str.vacant?
      nil
    end

  private
    # Prepares blocks in the input for the execution
    def block str
      return str unless self.class.const_defined?(:BLOCK_TAGS)
      result = str.dup
      self.class::BLOCK_TAGS.each { |tag, value|
        result.gsub!(/(#{tag})(.*?)(?:#{tag}|\Z)/m) { |m|
          %Q{

#{$1} #{Base64.encode64($2).carriage(false).bowl}

}
        }
      }
      result
    end

    # Prepares customs in the input for the execution
    def custom str
      return str unless self.class.const_defined?(:CUSTOM_TAGS)
      result = str.dup
      self.class::CUSTOM_TAGS.each { |tag, value|
        result.gsub!(/#{tag}/m, value)
      }
      result
    end

    # Prepares grips in the input for the execution
    # FIX<E There is a problem: we append a trailing space, need to remove it later!!
    def grip str
      return str unless self.class.const_defined?(:GRIP_TAGS)
      result = str.bowl
      self.class::GRIP_TAGS.each { |tag, value|
        result.gsub!(/(?:#{tag})(.*?)(?:#{tag})/m) {
          next if (args = $1).vacant?
          tag = value[:marker] if Hash === value && value[:marker]
          "⌦ #{tag} #{args}#{tag}∎⌫"
        }
      }
      result.unbowl
    end

    def split str
      (block str).split(/\R{2,}/).map { |para|
        (grip custom para)
      }
    end

  end
end
