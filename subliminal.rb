require_relative 'subtitle'

class Subliminal < Subtitle

  def initialize
    required_bin('subliminal')
  end

  def initialize(providers)
    @providers = providers
  end

  def get(video_file,lang)
    begin
      subtitle_file =  fetch(video_file,lang)
      if ! subtitle_file.nil?
        if ! is_srt? subtitle_file
          recode_file(subtitle_file)
          to_srt(subtitle_file,video_file)
          subtitle_file
        end
      else
        nil
      end
    rescue Errno::ENOENT
      nil
    end
  end

  private

  def fetch(video_file,lang)
    if subliminal_version == 0
      cmd = "subliminal --providers #{@providers} -l #{lang} -- \"#{video_file}\" 2>&1 >/dev/null"
    else
      provider = @providers.split(' ').join(' -p ')
      cmd = "subliminal download -l #{lang} -p #{provider} \"#{video_file}\" 2>&1 >/dev/null"
    end
    `#{cmd}`
    if $? == 0
      sub_name(video_file,lang)
    else
      nil
    end
  end

  def subliminal_version
    if `subliminal --version 2>&1`  =~ /subliminal,\s+version\s+1\.*/
      1
    else
      0
    end
  end

end
