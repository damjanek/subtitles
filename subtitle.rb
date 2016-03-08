class Subtitle

  require 'fileutils'
  require 'tempfile'

  def initialize
    ['subotage.sh','ffmpeg'].each do |b|
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
        # File.open(subtitle_file, :encoding => 'UTF-8').each do |line|
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
    `subotage.sh -i '#{subtitle_file}' -fi '#{fps}' -o '#{tmp.path}' 2>&1 >/dev/null`
    if $?.to_i == 0
      FileUtils.mv(tmp.path,subtitle_file)
      File.chmod(0644,subtitle_file)
      true
    else
      File.unlink(subtitle_file)
      tmp.unlink
      nil
    end
  end

  def sub_name(video_file,lang)
    File.basename(video_file,File.extname(video_file)) + '.' + lang + '.srt'
  end

  def framerate(video_file)
    $1 if `ffmpeg -stats -i "#{video_file}" 2>&1 | grep Video` =~ /.*?([\d+\.]+)\s+fps.*/
  end

  def required_bin(bin)
    `which #{bin}`
    if ! $?.success?
      warn "#{bin} is missing in PATH."
      exit 4
    end
  end

end
