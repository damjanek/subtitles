#!/usr/bin/env ruby

require 'find'
require 'fileutils'
require 'sequel'

DB = Sequel.sqlite('filelist.db')

DB.create_table?(:subtitles) do
  primary_key String :name
  boolean :pl
  boolean :en
  boolean :pol
  boolean :pt
  boolean :es
  boolean :active
end

subtitles = DB[:subtitles]

File.umask(0022)

$languages = ['en','pl','es','pt','pol']
$filetypes = /(avi|wmv|mkv|rmvb|3gp|mp4|mpe?g)$/
$dirs = ['/data/Movies','/data/TV Shows']
$ignored = /.*TS_Dreambox.*/
$lockfile = '/home/debian-transmission/.feed_db.lock'

def pidfile(action)
  if action == 'create'
    if File.exists?($lockfile)
      puts 'Lockfile exists'
      exit 1
      # TODO - dorobic olewanie pidfile jesli proces nie chodzi
    else
      FileUtils.touch($lockfile)
    end
  elsif action == 'remove'
    FileUtils.rm($lockfile)
 else
    puts "Wrong action: #{action}"
    exit 1
  end
end

def lang_name (path,lang)
  filename = File.basename(path,".*")
  return File.join( File.dirname(path), "#{filename}.#{lang}.srt" )
end

def sub_exists?(path,lang)
  if File.exists?(lang_name(path,lang))
    return 't'
  else
    return 'f'
  end
end

def check_subtitles(path)
  $languages.each do |lang|
    $data["#{path}"]["#{lang}"] = sub_exists?(path,lang)
  end
end

def get_all(dirs)
  if File.exists?($lockfile)
    puts "Lockfile exists. Quitting"
    exit 1
  else
    FileUtils.touch($lockfile)
  end
  $data = Hash.new {|h,k| h[k] = Hash.new(&h.default_proc) }
  dirs.each do |dir|
    Find.find(dir).grep($filetypes).reject{|e| e=~ $ignored }.map.each do |file|
      check_subtitles(file)
    end
  end
  FileUtils.rm($lockfile)
end

get_all($dirs)

DB.transaction do
  $data.each do |t|
    if subtitles.where(:name => t[0]).count > 0
      subtitles.where(:name => t[0]).update(
        :pol  => t[1]['pol'],
        :pl   => t[1]['pl'],
        :en   => t[1]['en'],
        :es   => t[1]['es'],
        :pt   => t[1]['pt'],
        :active => 't'
      )
    else
      subtitles.insert(
        :name => t[0],
        :pol  => t[1]['pol'],
        :pl   => t[1]['pl'],
        :en   => t[1]['en'],
        :es   => t[1]['es'],
        :pt   => t[1]['pt'],
        :active => 't'
      )
    end # if subtitles
  end # $data.each
  subtitles.where(:active => 'f').delete
  subtitles.update(:active => 'f')
end # DB.transaction
