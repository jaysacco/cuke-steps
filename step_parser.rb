# Class that parses step definitions from Ruby files and c# files

class StepParser

  attr_reader :steps
  def initialize
    @steps = []
  end

  def read(file)
    @current_file = file
    @line_number = 0
    @lines = IO.read(file).split(/\r?\n/)
    parse_lines
  end


  private

  def next_line
    @line_number += 1
    @lines.shift
  end

  def unread(line)
    @line_number -= 1
    @lines.unshift(line)
  end

  def parse_lines
    @comments = []
    while not @lines.empty?
      line = next_line
      case line
        # process ruby or c# comment lines
        when /^ *(#|\/+)/
          @comments << line
        # process ruby step lines, with or without leading white space
        when /^\s*(Given|When|Then|Before|After|AfterStep|Transform)[ (]/
          # remove leading spaces
          line = line.lstrip
          unread(line)
          parse_step
          @comments = []
        # process c# step lines, with or without leading white space
        when /^\s*(\[Given|\[When|\[Then|\[Before|\[After|\[AfterStep|\[Transform)/
          line = cleanCSharpAttribute(line)
          type = parse_step_type(line)
          name = parse_step_name(line)
          line_number = @line_number
          # for now, don't bother trying to include the code, it's too much work to parse correctly
          code = @comments << "The actual c# code is not displayed. This could be a future enhancement"
          @steps << { :type => type, :name => name, :filename => @current_file, :code => code, :line_number => line_number }
          @comments = []
        else
          @comments = []
      end

    end
  end

  def cleanCSharpAttribute(line)
    # remove leading spaces
    line = line.lstrip
    # remove c# attribute decoration characters
    line = line.sub('@','')
    line = line.sub('[','')
    line = line.sub(']','')
  end

  def parse_step
    type = parse_step_type(@lines.first)
    name = parse_step_name(@lines.first)
    line_number = @line_number + 1
    code = @comments
    line = ""
    # we need to find at least one end before we're done
    openEndCount = 0
    while !@lines.empty?
      # process the line
      line = next_line
      code << line
      # if the line contains a ruby keyword that will require a corresponding end statement
      match = line =~ /^[^,#]* (Given|When|Then|Transform|while|case|if|do|begin)\s*#*.*$/
      if(match != nil && match)
        openEndCount += 1
      end
      # if the line contains an end statement)
      match = line =~ /^\s*end\s*#*.*$/
      if(match != nil && match)
        openEndCount -= 1
      end
    # if we've found the end statement that completes this step definition, we're done
      if(openEndCount == 0)
        break
      end
    end
    @steps << { :type => type, :name => name, :filename => @current_file, :code => code, :line_number => line_number }
  end

  def parse_step_type(line)
    line.sub(/^([A-Za-z]+).*/, '\1')
  end

  def parse_step_name(line)
    line = line.sub(/^(Given|When|Then|Transform) *\(?\/\^?(.*?)\$?\/.*/, '\1 \2')
    line = line.gsub('\ ', ' ')
    line
  end

end
