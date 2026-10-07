require 'ripper'
require 'sorcerer'
require 'given/file_cache'

module Given
  class LineExtractor
    def initialize(file_cache=nil)
      @files = file_cache || FileCache.new
    end

    def line(file_name, line)
      lines = @files.get(file_name)
      extract_lines_from(lines, line-1)
    end

    def to_s
      "<LineExtractor>"
    end

    private

    def extract_lines_from(lines, line_index)
      result = lines[line_index]
      while result && incomplete?(result)
        line_index += 1
        result << lines[line_index]
      end
      result
    end

    def incomplete?(string)
      builder = Ripper::SexpBuilder.new(string)
      sexp = builder.parse
      if builder.error?
        # Modern Ripper recovers from syntax errors by dropping
        # statements. A truncated source line parses to a program with
        # no sourceable content; anything else is left alone.
        extractable_source(sexp).empty?
      else
        ! complete_sexp?(sexp)
      end
    end

    def extractable_source(sexp)
      Sorcerer.source(sexp)
    rescue Sorcerer::Resource::NotSexpError
      ""
    end

    def complete_sexp?(sexp)
      Sorcerer.source(sexp)
      true
    rescue Sorcerer::Resource::NotSexpError => ex
      false
    end
  end
end
