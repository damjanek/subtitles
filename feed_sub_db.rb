#!/usr/bin/env ruby

require 'find'
require 'fileutils'
require 'sequel'
require 'etc'
require 'yaml'
require_relative 'subtitle'

config_file = Etc.getpwuid.dir + '/.subtitles.yaml'

begin
  @config = YAML.load_file(config_file)
rescue Errno::ENOENT
  warn 'Config file #{config_file} does not exists!'
  exit 1
end

$languages = @config['languages']
lockfile = Etc.getpwuid.dir + '/.feed_db.lock'

DB = Sequel.sqlite(@config['dblocation'])

$subtitle = Subtitle.new

DB.create_table?(:subtitles) do
  primary_key String :name
  $languages.each do |lang|
    boolean lang.to_sym
  end
  boolean :active
end

subtitles = DB[:subtitles]

File.umask(0022)


def sub_exists?(path,lang)
  if File.exists?($subtitle.sub_name(path,lang))
    't'
  else
    'f'
  end
end

def check_subtitles(path)
  $languages.each do |lang|
    $data["#{path}"]["#{lang}"] = sub_exists?(path,lang)
  end
end

def get_all(dirs,filetypes,ignored,lockfile)
  toolkit = Subtitle.new
  toolkit.check_lockfile(lockfile)
  $data = Hash.new {|h,k| h[k] = Hash.new(&h.default_proc) }
  ext = Regexp.new('(' + filetypes.join('|') + ')$')
  ignore = Regexp.new('(' + ignored.join('|') + ')', 'i')
  dirs.each do |dir|
    Find.find(dir).grep(ext).reject{|e| e=~ ignore }.map.each do |file|
      check_subtitles(file)
    end
  end
  FileUtils.rm(lockfile)
end


#### Main app:
#

get_all(@config['dirs'],@config['filetypes'],@config['ignored'],lockfile)

DB.transaction do
  $data.each do |t|
    hash = Hash.new
    $languages.each do |lang|
      hash[lang.to_sym] = t[1][lang]
    end
    hash[:active] = 't'
    if subtitles.where(:name => t[0]).count > 0
      subtitles.where(:name => t[0]).update(hash)
    else
      hash[:name] = t[0]
      subtitles.insert(hash)
    end # if subtitles
  end # $data.each
  subtitles.where(:active => 'f').delete
  subtitles.update(:active => 'f')
end # DB.transaction
