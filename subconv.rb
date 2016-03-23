#!/usr/bin/env ruby
require 'mathn'

@frame = ARGV[0].to_f
@x = 1
@out_file

def time_convert(input)
  milliseconds = input.to_f % 1000.0
  seconds = input % 60
  minutes = (input / 60) % 60
  hours = input / (60 * 60)
  return format("%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
end

def frame_converter(hour,minute,second,millisecond)
  frames = ((hour * 3600.0) + (minute * 60.0) + second + (millisecond/1000.0)) * @frame
  return frames.to_i
end

def decy_2_time(input)
    t_seconds = input.to_f / 10
    milliseconds = (t_seconds - t_seconds.to_i) * 1000
    if milliseconds - milliseconds.to_i >= 0.5
      milliseconds = milliseconds + 1
    end
    seconds = (t_seconds.to_i) % 60
    t_minutes = t_seconds / 60
    minutes = (t_minutes.to_i) % 60
    hours = t_minutes / 60
    hours = hours.to_i
    return format("%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
end

def microdvd_converter(input)
  @out_file = File.new("#{ARGV[1][0...-3]}srt", "w")
  IO.foreach(input) do |text|
    match = text.scan(/\{([0-9]*)\}/)
    start_time = match[0].to_s
    start_time = /(\d+)/.match(start_time).to_s
    start = start_time.to_f / @frame
#if ($endframe == $startframe) {$startframe = $startframe + 5};
    stop_time = match[1].to_s
    stop_time = /(\d+)/.match(stop_time).to_s
    stop = stop_time.to_f / @frame
    out = text.gsub("{#{start_time}}{#{stop_time}}", "" )
    out = out.gsub("|","\n")
      texts = "#{@x}\n#{time_convert(start)} --> #{time_convert(stop)}\n#{out}\n"
      @out_file.puts texts
      @x += 1
  end
end

def mpl2_converter(input)
  @out_file = File.new("#{ARGV[1][0...-3]}srt", "w")
  IO.foreach(input) do |text|
    match = text.scan(/\[([0-9]*)\]/)
    start_time = match[0].to_s
    start_time = /(\d+)/.match(start_time).to_s
    start = start_time.to_i
    stop_time = match[1].to_s
    stop_time = /(\d+)/.match(stop_time).to_s
    stop = stop_time.to_i
    if start == stop
       stop = start + 50
    end
    out = text.gsub("[#{start_time}][#{stop_time}]", "" )
    out = out.gsub("|","\n")
      texts = "#{@x}\n#{decy_2_time(start)} --> #{decy_2_time(stop)}\n#{out}\n"
      @out_file.puts texts
      @x += 1
  end
end

def subrip_converter(input)
  pattern = '<>'
  @out_file = File.new("#{ARGV[1][0...-3]}srt", "w")
  input_file = File.read("#{input}")
  input_file = input_file.gsub(/\n{2,}/,"<>")
  match = input_file.split(pattern)
  match.each do |xxx|
    xxx = xxx.gsub("\n","<>")
    start_time, stop_time, out = xxx.match(/^(\d\d:\d\d:\d\d\.\d\d)\,(\d\d:\d\d:\d\d\.\d\d)\<\>(.*$)/i).captures
    start = start_time.to_s.gsub(".",",") + '0'
    stop = stop_time.to_s.gsub(".",",") + '0'
    out = out.to_s.gsub("<>","\n")
    texts = "#{@x}\n#{start} --> #{stop}\n#{out}\n\n"
    @out_file.puts texts
    @x += 1
  end
end

def tmplayer_converter(input)
  @out_file = File.new("#{ARGV[1][0...-3]}srt", "w")
  line = IO.readlines(input)
  text = line[0]
  @start_time, out = text.match(/^(\d\d:\d\d:\d\d):(.*$)/i).captures
  out_next = ''
  IO.foreach(input).with_index do |text, line_number|
    @x = line_number
    stop_time = '00:00:00'
    stop_time, out_next = text.match(/^(\d\d:\d\d:\d\d):(.*$)/i).captures
    if line_number > 0
      start = @start_time.to_s + ',100'
      stop = stop_time.to_s + ',000'
      out = out.gsub("|","\n")
      texts = "#{line_number}\n#{start} --> #{stop}\n#{out}\n\n"
      @out_file.puts texts
      @start_time = stop_time
      if out_next.to_s != ""
        out = out_next
      end
    end
  end
  stop = '23:59:59,000'
  start = @start_time.to_s + ',100'
  texts = "#{@x+1}\n#{start} --> #{stop}\n#{out}\n\n"
  @out_file.puts texts
end

def detect_format(input)
  puts "Checking...."
  lines = IO.readlines(input)
  first_line = lines[0].to_s

  # microdvd format
  # looks like:
  # {startframe}{endframe}Text

  if first_line =~ /^\{\d+\}\{\d+\}.+$/
    second_line = lines[1].to_s
    if second_line =~ /^\{\d+\}\{\d+\}.+$/
      puts "microdvd format detected!\n"
      microdvd_converter(ARGV[1])
    end
  elsif first_line =~ /^\d\d:\d\d:\d\d\.\d\d,\d\d:\d\d:\d\d\.\d\d$/

  # trying subrip format
  # 3 lines:
  # hh:mm:ss.ms,hh:mm:ss.ms
  # text
  # (empty line)

    fourth_line = lines[3].to_s

    if fourth_line =~ /^\d\d:\d\d:\d\d\.\d\d,\d\d:\d\d:\d\d\.\d\d$/
      puts "subrip format detected!\n"
    end
  elsif first_line =~ /^\d$/

  # trying subviewer .srt format
  # line counter
  # hh:mm:ss,ms --> hh:mm:ss,ms
  # text
  # (empty line)
    if second_line =~ /^\d\d:\d\d:\d\d\,\d\d\d\s-->\s\d\d:\d\d:\d\d\,\d\d\d$/
      puts "subviewer .srt format detected!\n"
      puts "Do nothing!\n"
    end

  elsif first_line =~ /^\d\d:\d\d:\d\d:.*$/

  # trying tmplayer format
  # hh:mm:ss:text
  # hh:mm:ss:text

    second_line = lines[1].to_s
    if second_line =~ /^\d\d:\d\d:\d\d:.*$/
      puts "tmplayer format detected!\n"
      tmplayer_converter(ARGV[1])
    end

  elsif first_line =~ /^\[\d+\]\[\d+\].+$/

  # trying mpl2 format
  # [MS][MS]text
  # [MS][MS]text

    second_line = lines[1].to_s
    if second_line =~ /^\[\d+\]\[\d+\].+$/
      puts "mpl2 format detected!\n"
      mpl2_converter(ARGV[1])
    end
  else
    puts "Unsupported format"
  end
end

detect_format(ARGV[1])

#if ARGV[1][-3..-1] == "srt"
#  puts "It's already srt format"
#elsif ARGV[1][-4..-1] == "mpl2"
#  mpl2_converter(ARGV[1])
#elsif ARGV[1][-3..-1] == "txt"
#  microdvd_converter(ARGV[1])
#elsif ARGV[1][-3..-1] == "sub"
#  subrip_converter(ARGV[1])
#elsif ARGV[1][-3..-1] == "tmp"
#  tmplayer_converter(ARGV[1])
#else
#  puts "Unsupported format"
#end
