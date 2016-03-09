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

logfile = Etc.getpwuid.dir + '/' + @config['logfile']

###
# functions

def retstring(value)
  if value.nil?
    'Not found.'
  else
    'OK.'
  end
end

def is_running(pid)
  begin
    Process.getpgid( pid )
    true
  rescue Errno::ESRCH
    false
  end
end

def check_lockfile(lock)
  if File.exists?(lock)
    warn "Lockfile #{lock} exists."
    begin
      pid = File.read(lock)
      if is_running(pid)
        warn "And the process is running. Quitting."
        exit 1
      else
        warn "And the process is not running. Ignoring."
      end
    rescue TypeError
      warn "But has malformed content. Ignoring."
      f = File.new(lock, 'w')
      f.write(Process.pid)
      f.close
    end
  else
    f = File.new(lock, 'w')
    f.write(Process.pid)
    f.close
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
  check_lockfile(lockfile)
  puts "Refreshing subtitle database"
  `#{@config['feeder_bin_location']}`
  puts "Complete"
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
  File.unlink(lockfile)
end

####
# Main app

if ARGV.length == 1
  get_single_file(ARGV[0])
elsif ARGV.length == 0
  # push everything to logfile if not running from tty
  if ! $stdout.isatty
    $stdout.reopen(logfile,'w')
    $stderr.reopen(logfile,'w')
  end
  get_from_database
else
  warn 'Wrong number of arguments!'
  warn 'It should be one (just one file) or no arguments'
  exit 1
end
