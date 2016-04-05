#!/usr/bin/env ruby

#encoding: utf-8

$VERBOSE=nil

require 'etc'
require 'yaml'
require 'sequel'
require_relative 'napiprojekt'

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

logfile = Etc.getpwuid.dir + '/' + @config['logfile']

unless @config['disable_subliminal']
  require_relative 'subliminal'
end

###
# functions

def retstring(value)
  if value.nil?
    'Not found'
  else
    'OK'
  end
end

def get_single_file(video_file)
  if File.file?(video_file)
    puts "Processing #{video_file}:"
    @config['languages'].each do |lang|
      grab(video_file,lang)
    end
  else
    warn "#{video_file} does not exists or is not a file!"
    exit 1
  end
end

def get_directory(directory)
  # TODO
  warn 'Directory search is not supported yet!'
  nil
end

def grab(file,lang)
  subliminal = ! @config['disable_subliminal']
  np = Napiprojekt.new
  sb = Subliminal.new unless @config['disable_subliminal']

  if lang == 'pl'
    result = np.get(file)
    puts "\t#{lang.upcase} Napiprojekt:\t#{retstring(result)}"
    if result.nil?
      puts "\t#{lang.upcase} Subliminal:\t#{retstring(sb.get(file,lang))}" if subliminal
    end
  else
    puts "\t#{lang.upcase} Subliminal:\t#{retstring(sb.get(file,lang))}" if subliminal
  end
end

def feeder
  puts 'Refreshing subtitle database'
  `#{@config['feeder_bin_location']}`
  puts 'Complete'
end

def get_from_database
  lockfile = Etc.getpwuid.dir + '/.subtitles.lock'
  toolkit = Subtitle.new
  toolkit.check_lockfile(lockfile)
  feeder
  db = Sequel.sqlite(@config['dblocation'])
  requested = db[:subtitles]
  total = requested.count
  current = 1
  requested.each do |req|
    puts "[#{current}/#{total}] Processing #{req[:name]}:"
    @config['languages'].each do |lang|
      requested.where(lang.to_sym => 'f', :name => req[:name]).each do |r|
        grab(req[:name],lang)
      end
    end
    current += 1
  end
  puts 'Finished!'
  File.unlink(lockfile)
end

####
# Main app

if ARGV.length == 1
  if File.file?(ARGV[0])
    get_single_file(ARGV[0])
  elsif File.directory?(ARGV[0])
    get_directory(ARGV[0])
  else
    warn "#{ARGV[0]} is not a file or directory"
    exit 1
  end
elsif ARGV.length == 0
  # push everything to logfile if not running from tty
  if ! $stdout.isatty
    $stdout.reopen(File.open(logfile,'a+'))
    $stderr.reopen(File.open(logfile,'a+'))
  end
  get_from_database
else
  warn 'Wrong number of arguments!'
  warn 'It should be one (just one file) or no arguments'
  exit 1
end
