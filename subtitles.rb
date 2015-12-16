#!/usr/bin/env ruby

require 'find'
require 'fileutils'
require 'tempfile'

File.umask(0022)

$languages = ['en','pl']
$providers = "opensubtitles thesubdb"
$filetypes = /(avi|wmv|mkv|rmvb|3gp|mp4|mpe?g)$/
$dirs = ['/data/Movies','/data/TV Shows']
$ignored = /.*TS_Dreambox.*/
$lockfile = '/home/debian-transmission/.napiser.lock'

class Napiprojekt
  def initialize
    require 'nokogiri'
    require 'base64'
    require 'digest'
    require 'open-uri'
    require 'net/http'
  end

  def get(path)
    get_napi_subtitles(sum(path), output_file(path), path)
  end

  private

  def sum(file)
    if File.file?(file)
      content = open(file, 'r') { |io| io.read(10485760) }
      Digest::MD5.hexdigest(content)
    else
      nil
    end
  end

  def framerate(file,path)
    $1 if `ffmpeg -stats -i "#{path}" 2>&1 | grep Video` =~ /.*?([\d+\.]+)\s+fps.*/
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

  ####
  # SRT related logic

  def is_srt?(file)
    if File.file?(file)
      begin
        srt = false
        File.open(file, :encoding => "UTF-8").each do |line|
          if line =~ /^\d+:\d+:\d+,\d+ --> \d+:\d+:\d+,\d+[ \r\n]*/
            srt = true
          end
        end
        srt
      rescue Exception => e
        puts e
      end
    end
  end

  def to_srt(file,path)
    fps = framerate(file,path)
    tmp = Tempfile.new('napiser_convert')
    `subotage.sh -i '#{file}' -fi '#{fps}' -o '#{tmp.path}' 2>&1 >/dev/null`
    if $?.to_i == 0
      FileUtils.mv(tmp.path,file)
      File.chmod(0644,file)
      true
    else
      File.unlink(file)
      tmp.unlink
      nil
    end
  end

  def get_napi_subtitles(sum,file,videofile)
    params = {
      'downloaded_subtitles_id'   => sum,
      'mode'                      => mode,
      'client'                    => client,
      'client_ver'                => client_ver,
      'downloaded_subtitles_lang' => lang,
      'downloaded_subtitles_txt'  => txt,
    }

    url = URI.parse('http://napiprojekt.pl/api/api-napiprojekt3.php')
    response = Net::HTTP.post_form(url, params)
    if response.code == '200' && ! response.body.nil?
      begin
        xml = Nokogiri::XML(response.body)
        if xml.at_xpath('//status').content =~ /success/
          sub = Base64.decode64(xml.at_xpath('//content').content)
          nil if sub.size < 40
          File.write(file, sub, :mode => 'w')
          if ! is_srt?(file)
            if to_srt(file,videofile).nil?
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
  end

  def output_file(file)
    filename  = File.basename(file,".*")
    File.join( File.dirname(file), "#{filename}.pl.srt" )
  end

end ### Napiprojekt class

class Subliminal
  def initialize
    # TODO - todo
  end

  def get(path,lang)
    fetch(path,lang)
  end

  private

  def fetch(path,lang)
    if subliminal_version == 0
      cmd = "subliminal --providers #{$providers} -l #{lang} -- \"#{path}\" 2>&1 >/dev/null"
    else
      provider = $providers.split(' ').join('-p ')
      cmd = "subliminal download -l #{lang} -p #{provider} \"#{path}\" 2>&1 >/dev/null"
    end
    `#{cmd}`
    if $? == 0
      true
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

###### OLD SCRIPT

def retstring(value)
  if value.nil?
    'Not found'
  else
    'OK'
  end
end

def fetch_subs(path,lang)
  sb = Subliminal.new
  print "Processing #{path} lang: #{lang}... "
  if lang != 'pl'
    puts retstring(sb.get(path,lang))
  else
    n = $np.get(path)
    if n.nil?
      print 'Not found in NP... In OS: '
      o = sb.get(path,lang)
      if ! o.nil?
        puts retstring(recode_file(path))
      else
        puts retstring(o)
      end
    else
      puts retstring(n)
    end
  end
end

def lang_name(path,lang)
  filename = File.basename(path,".*")
  File.join( File.dirname(path), "#{filename}.#{lang}.srt" )
end

def check_subtitles(path)
  $languages.each do |lang|
    if ! File.exists?(lang_name(path,lang))
      fetch_subs(path,lang)
    end
  end
end

####
# MISC logic

def get_all(dirs)
  if File.exists?($lockfile)
    puts "Lockfile exists. Quitting"
    exit 2
  else
    FileUtils.touch($lockfile)
  end
  dirs.each do |dir|
    file_list = Find.find(dir).grep($filetypes).reject{|e| e=~ $ignored }.map
    file_list.each do |file|
      check_subtitles(file)
    end
  end
  FileUtils.rm($lockfile)
end

def get_single_file(file)
  if File.file?(file)
    check_subtitles(file)
  else
    puts "#{file} is not a file!"
    exit 3
  end
end

def required_bin(bin)
  `which #{bin}`
  if ! $?.success?
    puts "#{bin} is missing in PATH."
    exit 4
  end
end

####
# MAIN APP

$np = Napiprojekt.new

['subotage.sh','subliminal','ffmpeg'].each do |b|
  required_bin(b)
end

if ARGV.length == 1
  get_single_file(ARGV[0])
elsif ARGV.length == 0
  get_all($dirs)
else
  puts "Wrong number of arguments!\nIt should be one (just one file) or no arguments"
  exit 1
end
