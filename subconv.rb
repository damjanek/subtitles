class Subconv

  def initialize
    require 'mathn'
    @x = 1
  end

  def convert(input,fps,output_file)
    @frame = fps.to_f
    @output_file = output_file
    lines = IO.readlines(input, mode: 'r:binary')
    first = lines[0].to_s
    second = lines[1].to_s
    fourth = lines[3].to_s

    if first =~ /^\{\d+\}\{\d+\}.+$/
      microdvd_converter(input) if second =~ /^\{\d+\}\{\d+\}.+$/
    elsif first =~ /^\d$/
      if second =~ /^\d\d:\d\d:\d\d\,\d\d\d\s-->\s\d\d:\d\d:\d\d\,\d\d\d$/
        warn 'subviewer .srt format detected! Not doing anything'
      end
    elsif first =~ /^\d\d:\d\d:\d\d:.*$/
      tmplayer_converter(input) if second =~ /^\d\d:\d\d:\d\d:.*$/
    elsif first =~ /^\[\d+\]\[\d+\].+$/
      mpl2_converter(input) if second =~ /^\[\d+\]\[\d+\].+$/
    else
      warn 'Unsupported format'
    end
  end

  def time_convert(input)
    milliseconds = input.to_f % 1000.0
    seconds = input % 60
    minutes = (input / 60) % 60
    hours = input / (60 * 60)
    format("%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
  end

  def frame_converter(hour,minute,second,millisecond)
    frames = ((hour * 3600.0) + (minute * 60.0) + second + (millisecond/1000.0)) * @frame
    frames.to_i
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
    format("%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
  end

  def microdvd_converter(input)
    out_file = File.new(@output_file, "w")
    count = 1
    result = ''
    IO.foreach(input, mode: 'r:binary') do |text|
      match = text.scan(/\{([0-9]*)\}/)
      start_time = match[0].to_s
      start_time = /(\d+)/.match(start_time).to_s
      start = start_time.to_f / @frame
      stop_time = match[1].to_s
      stop_time = /(\d+)/.match(stop_time).to_s
      stop = stop_time.to_f / @frame
      out = text.gsub("{#{start_time}}{#{stop_time}}", "" )
      out = out.gsub("|","\n")
        result += "#{count}\n#{time_convert(start)} --> #{time_convert(stop)}\n#{out}\n"
        count += 1
    end
    out_file.write(result)
    out_file.close
  end

  def mpl2_converter(input)
    out_file = File.new(@output_file, 'wb')
    count = 1
    result = ''
    IO.foreach(input,mode: 'r:binary') do |text|
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
      out = text.gsub("[#{start_time}][#{stop_time}]", '')
      out = out.gsub("|","\n")
      result += "#{count}\n#{decy_2_time(start)} --> #{decy_2_time(stop)}\n#{out}\n"
      count += 1
    end
    out_file.write(result)
    out_file.close
  end

  def subrip_converter(input)
    out_file = File.new(@output_file, 'wb')
    count = 1
    result = ''
    pattern = '<>'
    input_file = File.read("#{input}")
    input_file = input_file.gsub(/\n{2,}/,"<>")
    match = input_file.split(pattern)
    match.each do |xxx|
      xxx = xxx.gsub("\n","<>")
      start_time, stop_time, out = xxx.match(/^(\d\d:\d\d:\d\d\.\d\d)\,(\d\d:\d\d:\d\d\.\d\d)\<\>(.*$)/i).captures
      start = start_time.to_s.gsub(".",",") + '0'
      stop = stop_time.to_s.gsub(".",",") + '0'
      out = out.to_s.gsub("<>","\n")
      result += "#{count}\n#{start} --> #{stop}\n#{out}\n\n"
      count += 1
    end
    out_file.write(result)
    out_file.close
  end

  def tmplayer_converter(input)
    out_file = File.new(@output_file, "w")
    result = ''
    line = IO.readlines(input, mode: 'r:binary')
    text = line[0]
    @start_time, out = text.match(/^(\d\d:\d\d:\d\d):(.*$)/i).captures
    out_next = ''
    IO.foreach(input,mode: 'r:binary').with_index do |text, line_number|
      @x = line_number
      stop_time = '00:00:00'
      if text.match(/^(\d\d:\d\d:\d\d):(.*$)/i)
        stop_time, out_next = $1, $2
      end
      if line_number > 0
        start = @start_time.to_s + ',100'
        stop = stop_time.to_s + ',000'
        out = out.gsub("|","\n")
        result += "#{line_number}\n#{start} --> #{stop}\n#{out}\n\n"
        @start_time = stop_time
        if out_next.to_s != ''
          out = out_next
        end
      end
    end
    stop = '23:59:59,000'
    start = @start_time.to_s + ',100'
    result += "#{@x+1}\n#{start} --> #{stop}\n#{out}\n\n"
    out_file.write(result)
    out_file.close
  end

end
