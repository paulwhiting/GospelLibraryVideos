# encoding: utf-8
require_relative 'common'
require 'json'

if ARGV.count != 1
    puts "Usage:  #{$0} <roku content file>"
    exit
end

filename = ARGV[0]

data = File.open(filename).read
xml = Nokogiri::XML(data) 

subtitles = xml.css("subtitles")

data = {}

subtitles.each do |cc|
    url = cc['url']
    contents = cc.parent.children.css("content")
    contents.each do |content|
        id = content['url']
        data[id] = url
    end
end

count = data.length
#puts data.to_json
puts "{"
needs_comma = false
i = 0
data.each do |key, value|
    i += 1
    print "'#{key}':'#{value}'"
    print "," if i != count
    puts ""
end
puts "}"


