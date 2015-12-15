#!/usr/bin/env ruby

require 'find'
require 'fileutils'
require 'digest'
require 'tempfile'
require 'open-uri'
require 'base64'
require 'nokogiri'
require 'net/http'

File.umask(0022)

#$languages = ['en','pt','es','pl']
$languages = ['en','pl']
#$providers = "opensubtitles thesubdb tvsubtitles"
$providers = "opensubtitles thesubdb"
$filetypes = /(avi|wmv|mkv|rmvb|3gp|mp4|mpe?g)$/
$dirs = ['/data/Movies','/data/TV Shows']
$ignored = /.*TS_Dreambox.*/
$lockfile = '/home/debian-transmission/.napiser.lock'


####
# Napiprojekt checksums, etc.
def sum(file)
  if File.file?(file)
    content = open(file, 'r') { |io| io.read(10485760) }
    Digest::MD5.hexdigest(content)
  else
    nil
  end
end

def get_framerate(file,path)
  $1 if `/usr/bin/ffmpeg -stats -i "#{path}" 2>&1 | grep Video` =~ /.*?([\d+\.]+)\s+fps.*/
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

def srt?(file)
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
  fps = get_framerate(file,path)
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

####
# Recoding stuff

def recode_file(file)
  string = File.read(file)
  out = recode_string(string)
  if ! string.nil?
    File.write(file,string)
  else
    nil
  end
end

def recode_string(string)
  string.encode!(Encoding::UTF_8,Encoding::CP1250, :invalid => :replace, :replace => "")
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
        if ! srt?(file)
          if to_srt(file,videofile).nil?
            print 'Failed'
            nil
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

def fetch_polish(path,lang)
  begin
    md5 = sum(path)
    if ! md5.nil?
      r = get_napi_subtitles(md5,output_file(path),path)
      if r.nil?
        nil
      else
        true
      end
    else
      nil
    end
  rescue Exception => e
    puts "Fetch failed due to: #{e}"
  end
end

def retstring(value)
  if value.nil?
    'Not found'
  else
    'OK'
  end
end

def fetch_other(path,lang)
  `subliminal --providers #{$providers} -l #{lang} -- "#{path}" 2>&1 >/dev/null`
  if $? == 0
    true
  else
    nil
  end
end

def fetch_subs (path,lang)
  print "Processing #{path} lang: #{lang}... "
  if lang != 'pl'
    puts retstring(fetch_other(path,lang))
  else
    vn = fetch_polish(path,lang)
    if vn.nil?
      print 'Not found in NP... In OS: '
      vo = fetch_other(path,lang)
      if ! vo.nil?
        puts retstring(recode_file(path))
      else
        puts retstring(vo)
      end
    else
      puts retstring(vn)
    end
  end
end

def lang_name (path,lang)
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

['subotage.sh','subliminal'].each do |b|
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
