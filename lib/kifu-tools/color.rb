module Kifu
  module Tools

    class Color
    
      def self.color(text, color_code)
        # color_enabled? ? "#{color_code}#{text}\e[0m" : text
        "#{color_code}#{text}\e[0m"
      end

      def self.bold(text)
        color(text, "\e[1m")
      end

      def self.red(text)
        color(text, "\e[31m")
      end

      def self.green(text)
        color(text, "\e[32m")
      end

      def self.yellow(text)
        color(text, "\e[33m")
      end

      def self.blue(text)
        color(text, "\e[34m")
      end

      def self.magenta(text)
        color(text, "\e[35m")
      end

      def self.cyan(text)
        color(text, "\e[36m")
      end

      def self.white(text)
        color(text, "\e[37m")
      end

      def self.short_padding
        '  '
      end

      def self.long_padding
        '     '
      end
    end

  end
end
