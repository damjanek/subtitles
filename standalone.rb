#!/usr/bin/env ruby

#encoding: utf-8

require 'find'
require_relative 'napiprojekt'
require_relative 'subliminal'

np = Napiprojekt.new
sb = Subliminal.new

wanted = ARGV[0]

puts np.get(wanted)
