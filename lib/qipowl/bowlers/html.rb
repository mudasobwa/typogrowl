# encoding: utf-8

require 'net/http'
require 'htmlbeautifier'

require_relative '../core/bowler'

module Qipowl
  module Mappers
    class HtmlBowlerMapper < BowlerMapper
      
    end
  end

  # Module placeholder for dynamically created bowlers
  module Bowlers
    class Html < Bowler
##############################################################################
###              Default handlers for all the types of markup              ###
##############################################################################

      # `:grip` default handler
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Array] the array of words with trimmed `grip` tag
      def ∀_grip *args
        mine, rest = [*args].join(SEPARATOR).split("#{__callee__}∎", 2)
        [tagify(∃_grip_tag(__callee__), {:class => ∃_grip(__callee__)[:class]}, mine), rest]
      end

      # `:alone` default handler
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Array] the array of words with prepended `alone` tag
      def ∀_alone *args
        [standalone(∃_alone_tag(__callee__), {:class => ∃_alone(__callee__)[:class]}), args]
      end

      # `:block` default handler
      # @param [Array] args the words, gained since last call to {#harvest}
      # @param [String] param the text to be places on the same string as
      # opening tag
      # @return [Nil] nil
      def ∀_block *args
        param, *args = args.flatten
        param = param.to_s
        harvest __callee__, 
                tagify(
                  ∃_block_tag(__callee__), 
                  {:class => (param.strip.empty? ? ∃_block(__callee__)[:class] : param.strip)}, 
                  args.join(SEPARATOR).hsub(String::HTML_ENTITIES)
                )
      end
  
      # `:magnet` default handler
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Array] the array of words with trimmed `magnet` tag
      def ∀_magnet *args
        param, *rest = args.flatten
        param = param.unbowl.to_s.prepend("#{__callee__}#{String::NBSP}")
        [tagify(∃_magnet_tag(__callee__), {:class => ∃_magnet(__callee__)[:class]}, param), rest]
      end
  
      # `:regular` default handler
      # @param [Array] args the words, gained since last call to {#harvest}
      def ∀_regular *args
        harvest __callee__,
                tagify(
                  ∃_regular_tag(canonize(__callee__)),
                  {:class => ∃_regular(canonize(__callee__))[:class]},
                  args
                )
      end
    
##############################################################################
###              Grip :: Specific handlers                                 ###
##############################################################################
      # Handler for abbrs.
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Array] the array of words with trimmed `abbr` tag
      def † *args
        term, *title = args.flatten
        mine, rest = [*title].join(SEPARATOR).split("#{__callee__}∎", 2)
        [tagify(∃_grip_tag(__callee__), {:title => mine, :class => ∃_grip(__callee__)[:class]}, term), rest]
      end

      # Handler for anchors.
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Array] the array of words with trimmed `a` tag
      def ⚓ *args
        href, *title = args.flatten
        mine, rest = [*title].join(SEPARATOR).split("#{__callee__}∎", 2)
        href = href.unbowl
        [
          case get_href_content(href)
          when :img 
            standalone :img, { :src => href, :alt => [*mine].join(SEPARATOR), :class => 'inplace' }
          else 
            tagify ∃_grip_tag(__callee__), {:href => href}, mine
          end, rest
        ]
      end
  
##############################################################################
###             Alone :: Specific handlers                                 ###
##############################################################################
      # `:alone` handler for horizontal rule; it differs from default
      # handler since orphans around must be handled as well.
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Nil] nil
      def —— *args
        harvest nil, orphan(args.join(SEPARATOR)) unless args.vacant?
        harvest __callee__, standalone(∃_alone_tag(__callee__))
      end

##############################################################################
###             Block :: Specific handlers                                 ###
##############################################################################
      # `:block` handler for comment (required because comments are
      # formatted in HTML in some specific way.)
      # @param [String] param the text to be places on the same string as opening tag
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Nil] nil
      def ✍ *args
        []
      end

##############################################################################
###            Magnet :: Specific handlers                                 ###
##############################################################################
      # `:magnet` handler for reference to Livejournal user.
      # @param [String] param the text to be places on the same string as opening tag
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Nil] nil
      def ✎ *args
        param, *rest = args.flatten
        param = param.unbowl
        ljref = "<span style='white-space: nowrap;'><a href='http://#{param}.livejournal.com/profile?mode=full'><img src='http://l-stat.livejournal.com/img/userinfo.gif' alt='[info]' style='border: 0pt none ; vertical-align: bottom; padding-right: 1px;' height='17' width='17'></a><a href='http://#{param}.livejournal.com/?style=mine'><b>#{param}</b></a></span>"
        [ljref, rest]
      end
      
      def ☇ *args
        param, *rest = args.flatten
        [tagify(∃_magnet_tag(__callee__), {:name => param.unbowl}, String::ZERO_WIDTH_SPACE), rest]
      end
    
##############################################################################
###           Regular :: Specific handlers                                 ###
##############################################################################
      # Handler for Youtube video
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Nil] nil
      def ✇ *args
        id, *rest = args.flatten
        harvest nil, orphan(rest.join(SEPARATOR)) unless rest.vacant?
        harvest __callee__, %Q(
<iframe class='youtube' width='560' height='315' src='http://www.youtube.com/embed/#{id.unbowl}' 
        frameborder='0' allowfullscreen></iframe>
)
      end
      
      # Handler for standalone pictures and
      # @todo Make it to understand quotes when there is a plain HTML on the other side
      # 
      # @param 
      # @return [Nil] nil
      def ⚘ *args
        href, *title = args.flatten
        harvest __callee__, %Q(
<figure>
  <img src='#{href.unbowl}'/>
  <figcaption>
    <p>
      #{title.join(SEPARATOR)}
    </p>
  </figcaption>
</figure>
)
      end

      # `:regular` handler for data lists (required since data list items
      # consist of two tags: `dt` and `dd`.)
      # @param [Array] args the words, gained since last call to {#harvest}
      # @return [Nil] nil
      def ▶ *args
        dt, dd = args.join(SEPARATOR).split(/\s+(?:—)\s+/)
        harvest __callee__, %Q(
#{tagify :dt, {}, dt}
#{tagify :dd, {}, dd}
)
      end
      # Alias for {#▶}, according to YAML rules specifies additional 
      # class for the data list `<dl>` tag behind (`dl-horizontal`.)
      alias_method :▷, :▶

    protected
      # Computes the level of the `:linewide` element by counting
      # preceeding non-breakable spaces. For instance, nested lists
      # are produced by appending `"\u{00A0}"` to the line item
      # DSL tag: 
      # 
      #     li = "• li1 \u{00A0}• nested 1 \u{00A0}• nested 2 • li2"
      #     
      # @param [Symbol|String] callee the DSL symbol to get the level information for.
      # @return [Integer] the level requested. 
      #
      def level callee
        (callee = callee.to_s).gsub(/#{String::NBSP}/, '').empty? ?
          -1 : (0..callee.length-1).each { |i| break i if callee[i] != String::NBSP }
      end
      
      def canonize callee
        callee.to_s.gsub(/^#{String::NBSP}*/, '').to_sym if callee
      end

      # @see Qipowl::Bowler#harvest
      # 
      # Additionally it checks if there was a `:linewide` item, requiring
      # surrounding html element (like `<ul>` aroung several `<li>`s.)
      # 
      # @param [Symbol] callee of method
      # @param [String] str to be harvested
      def harvest callee, str
        if callee.nil? || callee != @callee
          level(callee).downto(level(@callee) + 1) { |i|
            str += i.␚ify
          } unless ∃_enclosures(canonize(callee)).nil?
  
          if prev = ∃_enclosures(canonize(@callee))
            level(@callee).downto(level(callee) + 1) { |i|
              @yielded.last.sub!(/\A/, opening(prev[:tag], {:class => prev[:class]}))
              @yielded.each { |s| s.gsub!(/#{i.␚ify}/) { closing(prev[:tag]) } }
            }
          end
          
          @callee = callee
        end
        super callee, str
      end

    private
      # Hence we cannot simply declare the DSL for it, we need to handle 
      # calls to all the _methods_, starting with those symbols.
      # 
      # @param [Symbol] method as specified by caller (`method_missing`.)
      # @param [Array] args as specified by caller (`method_missing`.)
      # @param [Proc] block as specified by caller (`method_missing`.)
      # 
      # @return [Array] the array of words
      def special_handler method, *args, &block
        # Sublevel markers, e.g. “ •” is level 2 line-item
        return [method, args].flatten \
          unless level(method) > 0 && self.class::REGULAR_TAGS.keys.include?(canonize(method))
        
        self.class.class_eval "alias_method :#{method}, :#{canonize(method)}"
        send method, args, block
      end

      # Produces html paragraph tag (`<p>`) with class `owl`.
      # @see Qipowl::Bowler#orphan
      # @param str the words, to be put in paragraph tag.
      # @return [String] tagged words.
      def orphan str
        "#{tagify(:p, {}, str.to_s.strip)}"
      end
      # Constructs opening html tag for the input given.
      # 
      # To construct `abbr` tag with `title` _Title_ and class _default_:
      # 
      #     opening :abbr, { :title=>'Title', :class=>'default' }
      # 
      # @param [String] tag to produce opening tag string from.
      # @param [Hash] params to be put into opening tag as attributes. 
      # @return [String] opening tag for the input given.
      def opening tag, params={}
        attrs = params.inject("") { |m, el| m.prepend " #{el.first}='#{el.last}'" unless el.last.nil? ; m }
        "<#{tag}#{attrs}>"
      end
      
      # Constructs closing html tag for the input given.
      # 
      # @param [String] tag to produce closing tag string from.
      # @return [String] opening tag for the input given.
      def closing tag
        "</#{tag}>"
      end
  
      # (see opening)
      # Acts most like an {#opening} method, but closes an element inplace
      # (used for `hr`, `br`, `img`).
      def standalone tag, params={}
        opening(tag, params).sub('>', '/>')
      end
      # Constructs valid tag for the input given, concatenating
      # opening and closing tags around the text passed in `args`.
      # 
      # @param [String] tag to produce html tag string from.
      # @param [Hash] params to be put into opening tag as attributes. 
      # @param [Array] args the words, to be tagged around. 
      # @return [String] opening tag for the input given.
      def tagify tag, params, *args
        text = [*args].join(SEPARATOR)
        text.vacant? ? '' : "#{opening tag, params}#{text}#{closing tag}"
      end


      # Determines content of remote link by href.
      # TODO Make image patterns configurable.
      # @param [String] href link to remote resource
      # @return [Symbol] content type (`:img` or `:text` currently)
      def get_href_content href
        href = href.to_s.unbowl.strip
        if href.end_with?(* %w{png jpg jpeg gif PNG JPG JPEG GIF})
          :img
        elsif /\/\/i\.chzbgr/ =~ href
          :img
        else
          :text
        end
          
      #  uri = URI(href.to_s.unbowl)
      #  Net::HTTP.start(uri.host, uri.port) do |http|
      #    http.open_timeout = 1
      #    http.read_timeout = 1
      #
      #    request = Net::HTTP::Head.new uri
      #    response = http.request request
      #    case response.to_hash["content-type"].first
      #    when /image/ then return :img
      #    when /text/ then return :text
      #    end
      #  end
      #  :unknown
      #rescue
      #  logger.warn "Unable to determine link [#{href.to_s.unbowl}] type: no internet connection. Reverting to default."
      #  :unknown
      end

    end
  end
end
=begin
  # Markup processor for Html output.
  # 
  # This class produces HTML from markup as Markdown does.
    
    # Amount of unnamed instances of the class (needed for new class name generation)
    @@inst_count = 0
    
    
    # `:handshake` default handler
    # @param [String] from packed as string operand “before”
    # @param [String] from packed as string operand “after”
    # @return 
    def ∈ *args
      from, till, *rest = args.flatten
      tag = @mapping.handshake(__callee__)
      tag = tag[:tag] if Hash === tag
      [tagify(tag, {}, "#{from.unbowl}#{__callee__}#{till.unbowl}".gsub(String::SYMBOL_FOR_SPACE, ' ')), rest]
    end
    alias_method :⊂, :∈
    

    
    # @see {Qipowl::Bowler#defreeze}
    # 
    # Additionally it checks if tag is a `:block` tag and 
    # substitutes all the carriage returns (`$/`) with special symbol
    # {String::CARRIAGE_RETURN} to prevent format damage.
    # 
    # @param [String] str to be defreezed
    def defreeze str
      str = super str
      @mapping[:block].each { |tag, htmltag|
        str.gsub!(/(#{tag})(.*?)$(.*?)(#{tag}|\Z)/m) { |m|
          "#{$1}('#{$2}', '#{$3}')\n\n"
        }
      }
      str
    end

    # @see {Qipowl::Bowler#serveup}
    #
    # Additionally it beatifies the output HTML
    # 
    # @param [String] str to be roasted
    def serveup str
      result = ''
      %w(. , : ; ! ? »).map(&:bowl).each { |punct|
        str.gsub!(/(?:\p{Space}|#{String::CARRIAGE_RETURN})*(#{punct})/, '\1')
#        str.gsub!(/(#{punct})(?=\p{Alnum})/, '\1 ')
      }
      %w(«).map(&:bowl).each { |punct|
        str.gsub!(/(#{punct})(?:\p{Space}|#{String::CARRIAGE_RETURN})*/, '\1')
        str.gsub!(/(?<=\p{Alnum})(#{punct})/, ' \1')
      }
      served = super(str)
      begin
        HtmlBeautifier::Beautifier.new(result).scan(served)
      rescue
        logger.error "Was unable to tidyfy resulting HTML. Returning as is."
        result = served
      end
      result
    end

end

if __FILE__ == $0
  
  i = 0
  Dir.glob("#{File.dirname(__FILE__)}/../../../data/octopress-site/source/_posts/**/*.owl").each {|f|
    puts "Processing ##{i += 1}: #{f}"
    Qipowl::Html.parse File.read(f)
  }
end
=end