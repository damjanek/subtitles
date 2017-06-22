class Subtitle

  require 'fileutils'
  require 'tempfile'
  require_relative 'subconv'

  def initialize
    ['mediainfo'].each do |b|
      required_bin(b)
    end
  end

  def recode_file(subtitle_file)
    text = File.read(subtitle_file)
    out = recode_string(text)
    if ! text.nil?
      File.write(subtitle_file,text)
    else
      return nil
    end
  end

  def recode_string(text)
    text.force_encoding(Encoding::CP1250).encode!(Encoding::UTF_8)
  rescue
    return nil
  end

  def is_srt?(subtitle_file)
    if File.file?(subtitle_file)
      begin
        srt = false
        File.open(subtitle_file, 'rb').each do |line|
          srt = true if line =~ /^\d+:\d+:\d+,\d+ --> \d+:\d+:\d+,\d+[ \r\n]*/
        end
        srt
      rescue ArgumentError
        warn 'argument error'
      end
    end
  end

  def to_srt(subtitle_file,video_file)
    fps = framerate(video_file)
    tmp = Tempfile.new('napiser_convert')
    subconv = Subconv.new
    subconv.convert(subtitle_file,fps,tmp.path)
    FileUtils.mv(tmp.path,subtitle_file)
    File.chmod(0644,subtitle_file)
    true
  end

  def sub_name(video_file,lang)
    File.dirname(video_file) + '/' + File.basename(video_file,File.extname(video_file)) + '.' + lang + '.srt'
  end

  def framerate(video_file)
    $1 if `mediainfo "#{video_file}" 2>&1 | grep "Frame rate"` =~ /^Frame rate\s+:\s+([\d+\.]+)\s+.*fps/
  end

  def required_bin(bin)
    `which #{bin}`
    if ! $?.success?
      warn "#{bin} is missing in PATH."
      exit 4
    end
  end

  def check_lockfile(lock)
    if File.exists?(lock)
      warn "Lockfile #{lock} exists."
      begin
        pid = File.read(lock)
        if is_running(pid.to_i)
          warn "And the process is running. Quitting."
          exit 1
        else
          warn "And the process is not running. Ignoring."
        end
      rescue TypeError
        warn "Quitting."
        exit 1
      end
      f = File.new(lock, 'w')
      f.write(Process.pid)
      f.close
    else
      f = File.new(lock, 'w')
      f.write(Process.pid)
      f.close
    end
  end

  private

  def is_running(pid)
    if pid == 0
      false
    else
      begin
        Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        false
      end
    end
  end

end
