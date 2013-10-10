# encoding: utf-8

require_relative '../core/bowler'

module Typogrowl
  class Html < Bowler
    def ☀ *args
      harvest __callee__, tagify(@mapping[:linewide][__callee__], {}, args)
    end
    
    def ☼ *args
      tagify(@mapping[:inplace][__callee__], {}, args)
    end
    
    def ⏎ *args
      [opening(@mapping[:flush][__callee__]), args]
    end

    def ☎ *args
      param, *rest = args.flatten
      [tagify(@mapping[:magnet][__callee__], {}, param), rest]
    end
    
    def ▶ *args
      dt, dd = args.join(SEPARATOR).split(/\s*—\s*/)
      harvest __callee__, "#{tagify :dt, {}, dt}#{tagify :dd, {}, dd}"
    end
    alias :▷ :▶
    
    def ⚓ *args
      href, *title = args.flatten
      tagify @mapping[:inplace][__callee__], {:href => href}, title
    end
    
    def † *args
      term, *title = args.flatten
      tagify @mapping[:inplace][__callee__], {:title => title.join(SEPARATOR)}, term
    end
    
  private
    def initialize
      super
      { :linewide => :☀, :inplace => :☼, :flush => :⏎, :magnet => :☎
      }.each { |section, meth|
        @mapping[section].each { |tag, htmltag|
          Html.class_eval %Q{
            alias :#{tag} :#{meth}
          } unless self.class.instance_methods(false).include?(tag)
        }
      }
      @mapping[:custom].each { |tag, re|
        Html.class_eval %Q{
          def #{tag} *args
            ["#{re.bowl}", args]
          end
        } unless self.class.instance_methods(false).include?(tag)
      }
    end
    
    def opening tag, params={}
      tag, *clazz = tag.to_s.split('†')
      clazz = clazz.empty? ? nil : " class='#{clazz.join(' ').gsub(/_/, '-')}'"
      attrs = params.inject("") { |m, k| m.prepend " #{k.first}='#{k.last}'" }
      "<#{tag}#{clazz}#{attrs}>"
    end
    
    def closing tag
      "</#{tag.to_s.split('†').first}>"
    end

    def tagify tag, params, *args
      args = args.join(SEPARATOR) if Array === args
      "#{opening tag, params}#{args.strip}#{closing tag}"
    end

    def orphan str
      tagify :p, {:class => "dropcap"}, str.strip
    end

    def level oper
      oper = oper.to_s
      (0..oper.length-1).each { |i| break i if oper[i] != "\u{00A0}" }
    end

    def harvest callee, str
      if @callee != callee
        prv = @mapping[:enclosures][@callee]
        nxt = @mapping[:enclosures][callee]
        @yielded.last.sub! /\A/, opening(prv) \
          if prv && (!callee || level(callee) <= level(@callee))
        str += closing(nxt) \
          if nxt && (!@callee || level(callee) >= level(@callee))
        @callee = callee
      end
      super callee, str
    end
        
    def special_handler method, *args, &block
      # Inplace tags, like “≡” for ≡bold decoration≡ 
      @mapping[:inplace].each { |tag, htmltag|
        if method.to_s.start_with? tag.to_s
          return [method, args].flatten.join(SEPARATOR).gsub(/#{tag}(.*?)(#{tag}|\Z)/) { |m|
            send(tag, eval($1)).bowl
          }.split(SEPARATOR)
        end
      }
      [method, args].flatten
    end
  end
end

tg =  Typogrowl::Html.new 

tg.in = 'welcome! 

℁
≡Twitter≡ ⏎
☎ +7(111)5554433 ⏎
✉ info@twitter.com

▷ Q — 1 trtr ≈eval instance_exec≈  ≡λghgh ghghλ≡ ghgh
▷ P — 2 I like Markdown¹http://daringfireball.net/projects/markdown/syntax
• 3 Wiki†Best online 
knowledge base ever†
 • "And God said "That\'s a 6.3" man, he sees sunsets at 10°20\'30" E." and there was light."
 • 4 instance_exec bye!
• 5'

#» Blockquote 1 asd
#» • Nested 1
#» • Nested 2
#» Blockquote 2'

puts tg.out