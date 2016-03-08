require_relative 'subtitle'

class Napiprojekt < Subtitle
  def initialize
    require 'nokogiri'
    require 'base64'
    require 'digest'
    require 'open-uri'
    require 'net/http'
  end

  def get(video_file)
    get_subtitles(calculate(video_file), sub_name(video_file,'pl'),video_file)
  end

  private

  def calculate(file)
    if File.file?(file)
      content = open(file, 'r') { |io| io.read(10485760) }
      Digest::MD5.hexdigest(content)
    else
      nil
    end
  end

  def mode
    '1'
  end

  def client
    'pynapi'
  end

  def client_ver
    '0'
  end

  def txt
    '1'
  end

  def lang
    'PL'
  end

  def get_subtitles(calculated_sum,subtitle_file,video_file)
    params = {
      'downloaded_subtitles_id'   => calculated_sum,
      'mode'                      => mode,
      'client'                    => client,
      'client_ver'                => client_ver,
      'downloaded_subtitles_lang' => lang,
      'downloaded_subtitles_txt'  => txt,
    }
    begin
      url = URI.parse('http://napiprojekt.pl/api/api-napiprojekt3.php')
      response = Net::HTTP.post_form(url, params)
      if response.code == '200' && ! response.body.nil?
        begin
          xml = Nokogiri::XML(response.body)
          if xml.at_xpath('//status').content =~ /success/
            sub = Base64.decode64(xml.at_xpath('//content').content)
            nil if sub.size < 40
            File.write(subtitle_file, sub, :mode => 'w')
            if ! is_srt?(subtitle_file)
              if to_srt(subtitle_file,video_file).nil?
                nil
              else
                true
              end
            end
            true
          else
            nil
          end
        rescue Exception => e
          nil
        end
      else
        nil
      end
    rescue Timeout::Error
      warn 'timeout'
      nil
    end
  end

end
