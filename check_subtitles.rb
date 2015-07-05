# encoding: utf-8
require_relative 'common'
require 'json'

if ARGV.count != 2
    puts "Usage:  #{$0} <roku content file> <allcaptionsfile.txt>"
    exit
end

filename = ARGV[0]
data = File.open(filename).read
xml = Nokogiri::XML(data) 
subtitles = xml.css("subtitles")

theirs = {}
filename = ARGV[1]
File.open(filename).each_line do |line|
    theirs[line.chomp] = true
end


mine = Hash.new(false)
found = 0
missing = 0
subtitles.each do |cc|
    url = cc['url']
    mine[url] = true
end

theirs.each do |key, value|
    url = key
    if mine[url]
        found += 1
    else
        missing += 1
        puts "UNUSED CC: " + url
    end
end

puts "Summary:  #{found} found and #{missing} missing"
