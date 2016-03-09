#!/usr/bin/env ruby

#encoding: utf-8

require 'etc'
require 'yaml'
require 'sequel'
require_relative 'napiprojekt'
require_relative 'subliminal'

File.umask(0022)

###
# Config operations

config_file = Etc.getpwuid.dir + '/.subtitles.yaml'
begin
  @config = YAML.load_file(config_file)
rescue Errno::ENOENT
  warn 'Config file #{config_file} does not exists!'
  exit 1
end

###
# functions

def retstring(value)
  if value.nil?
    'Not found.'
  else
    'OK.'
  end
end

def get_single_file(video_file)
  if File.file?(video_file)
    napiprojekt = Napiprojekt.new
    print "Trying to get pl subtitles from NapiProjekt for #{video_file}..."
    puts retstring(napiprojekt.get(video_file))
    subliminal = Subliminal.new
    @config['languages'].each do |lang|
      print "Trying to get #{lang} subtitles using subliminal for #{video_file}..."
      puts retstring(subliminal.get(video_file,lang))
    end
  else
    warn "#{video_file} does not exists or is not a file!"
    exit 1
  end
end

def get_from_database
  lockfile = Etc.getpwuid.dir + '/.subtitles.lock'
  db = Sequel.sqlite(@config['dblocation'])
  requested = db[:subtitles]
  # Fetch with napiprojekt
  np = Napiprojekt.new
  sb = Subliminal.new
  requested.where(:pl => 'f').each do |req|
    print "Processing #{req[:name]} with Napiprojekt..."
    result = np.get(req[:name])
    puts retstring(np.get(req[:name]))
    # If not found, search for polish subtitles using subliminal
    if result.nil?
      print "Processing #{req[:name]} with Subliminal..."
      puts retstring(sb.get(req[:name],'pl'))
    end
  end
  # Fetch with subliminal
  @config['languages'].reject{|a| a == 'pl' }.each do |lang|
    requested.where(lang.to_sym => 'f').each do |req|
      print "Processing #{req[:name]} #{lang} with Subliminal..."
      puts retstring(sb.get(req[:name],lang))
    end
  end
end

####
# Main app

if ARGV.length == 1
  get_single_file(ARGV[0])
elsif ARGV.length == 0
  get_from_database
else
  warn 'Wrong number of arguments!'
  warn 'It should be one (just one file) or no arguments'
  exit 1
end
