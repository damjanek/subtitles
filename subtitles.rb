#!/usr/bin/env ruby

#encoding: utf-8

require 'find'
require 'fileutils'
require 'tempfile'
require_relative 'napiprojekt'
require_relative 'subliminal'

File.umask(0022)

$languages = ['en','pl']
$providers = 'opensubtitles thesubdb'
$filetypes = /(avi|wmv|mkv|rmvb|3gp|mp4|mpe?g)$/
dirs = ['/data/Movies','/data/TV Shows']
$ignored = /.*TS_Dreambox.*/
$lockfile = '/home/debian-transmission/.subtitles.lock'

###### OLD SCRIPT

def retstring(value)
  if value.nil?
    'Not found'
  else
    'OK'
  end
end

def fetch_subs(path,lang)
  sb = Subliminal.new($providers)
  print "Processing #{path} lang: #{lang}... "
  if lang != 'pl'
    puts retstring(sb.get(path,lang))
  else
    n = $np.get(path)
    if n.nil?
      print 'Not found in NP... In OS: '
      o = sb.get(path,lang)
      puts retstring(o)
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
    fetch_subs(path,lang) if ! File.exists?(lang_name(path,lang))
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
  get_all(dirs)
else
  puts "Wrong number of arguments!\nIt should be one (just one file) or no arguments"
  exit 1
end
