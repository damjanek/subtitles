#!/usr/bin/env ruby

require 'find'
require 'fileutils'
require 'digest'
require 'tempfile'
require 'open-uri'

File.umask(0022)

#$languages = ['en','pt','es','pl']
$languages = ['en','pl']
#$providers = "opensubtitles thesubdb tvsubtitles"
$providers = "opensubtitles thesubdb"
$filetypes = /(avi|wmv|mkv|rmvb|3gp|mp4|mpe?g)$/
$dirs = ['/data/Movies','/data/TV Shows']
$ignored = /.*TS_Dreambox.*/
$lockfile = '/home/debian-transmission/.napiser.lock'

def sum(file)
  if File.file?(file)
    content = open(file, 'r') { |io| io.read(10485760) }
    Digest::MD5.hexdigest(content)
  else
    nil
  end 
end

def get_framerate(file,path)
  return $1 if `/usr/bin/ffmpeg -stats -i "#{path}" 2>&1 | grep Video` =~ /.*?([\d+\.]+)\s+fps.*/
end

def f_digest(md5sum)

  idx = [0xe, 0x3, 0x6, 0x8, 0x2]
  mul = [2, 2, 5, 4, 3]
  add = [0x0, 0xd, 0x10, 0xb, 0x5]

  idx.map.with_index do |i, j|
    t = add[j] + md5sum[i].to_i(16)
    v = md5sum[t, 2].to_i(16)

    ((v * mul[j]) % 16).to_s(16)
  end.join ''
end

def user
  ''
end

def pass
  ''
end

def lang
  'PL'
end

def ver
  'pynapi'
end

def srt?(file)
  if File.file?(file)
    begin
      srt = false
      File.open(file, :encoding => "UTF-8").each do |line|
        if line =~ /^\d+:\d+:\d+,\d+ --> \d+:\d+:\d+,\d+[ \r\n]*/
          srt = true
        end
      end
      return srt
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
    return true
  else
    File.unlink(file)
    tmp.unlink
    return nil
  end
end

def recode_file(file)
  string = File.read(file)
  out = recode_string(string)
  if ! string.nil?
    File.write(file,string)
  else
    return nil
  end
end

def recode_string(string)
  string.force_encoding(Encoding::CP1250).encode!(Encoding::UTF_8)
rescue
  return nil
end

def recode(path)
  p = output_file(path)
  result = File.read(p)
  begin
    result.force_encoding(Encoding::CP1250).encode!(Encoding::UTF_8)
    File.write(p,result)
    if srt?(p)
      return true
    else
      File.unlink(p)
      return nil
    end
  rescue
    File.unlink(p)
    return nil
  end
end

def get_napi_subtitles(hash,sum,file,videofile)
  url = "http://napiprojekt.pl/unit_napisy/dl.php?l=#{lang}&f=#{sum}&t=#{hash}&v=#{ver}&kolejka=false&nick=#{user}&pass=#{pass}&napios=posix"
  result = open(url, 'r') { |io| io.read }
  if result.start_with? 'NPc'
    return nil
  elsif result.start_with? 'Przerwa techniczna'
    return nil
  else
    begin
      #output = result
      output = recode_string(result)
      File.write(file, output, :mode => 'w')
      return nil if File.size(file) <= 40
      if ! srt?(file)
        print "Found but SRT convertion needed..."
        if to_srt(file,videofile).nil?
          print 'Failed'
          return nil
        end
      end
      true
    rescue
      nil
    end
  end
end

def output_file(file)
  filename  = File.basename(file,".*")
  return File.join( File.dirname(file), "#{filename}.pl.srt" )
end

def fetch_polish(path,lang)
  begin
    md5 = sum(path)
    if ! md5.nil?
      r = get_napi_subtitles(f_digest(md5),md5,output_file(path),path)
      if r.nil?
        return nil
      else
        return true
      end
    else
      return nil
    end
  rescue Exception => e
    puts "Fetch failed due to: #{e}"
  #ensure
  #  return nil
  end
end

def retstring(value)
  if value.nil?
    return 'Not found'
  else
    return 'OK'
  end
end

def fetch_other(path,lang)
  `subliminal --providers #{$providers} -l #{lang} -- "#{path}" 2>&1 >/dev/null`
  if $? == 0
    return true
  else
    return nil
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
        puts retstring(recode(path))
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
  return File.join( File.dirname(path), "#{filename}.#{lang}.srt" )
end

def check_subtitles(path)
  $languages.each do |lang|
    if ! File.exists?(lang_name(path,lang))
      fetch_subs(path,lang)
    end
  end
end

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
