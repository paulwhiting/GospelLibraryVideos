#!/usr/bin/ruby

# This code expects the following directory structure

# ./      -  Root folder
# ./code  -  Master branch of (this) code
# ./code/medialibrary_YYYY_M_D  -  Results of running update.rb
# ./gh-pages/  -  gh-pages branch


run = Time.now.strftime("%Y_%-m_%-d")
run_glob = Time.now.strftime("%Y%m%d")
run_standard = Time.now.strftime("%-m/%-d/%y")

puts "Processing medialibrary_#{run}..."

puts "Diffing with previous run (English only.  TODO: other languages)"
system("ruby diff.rb medialibrary_#{run}/roku/medialibrary_English.xml ../gh-pages/roku_channel/medialibrary_English.xml")

puts "Copying medialibrary_diff.xml to gh-pages"
system("cp medialibrary_diff.xml ../gh-pages/roku_channel/recent/medialibrary_recent_English_#{run_glob}.xml")

puts "Updating medialibrary_recent.xml"
recent = ""
File.open('../gh-pages/roku_channel/medialibrary_recent.xml').each_line do |line|
  recent += line
	recent += "\t<category title=\"English - #{run_standard}\" subtitle=\"\" url=\"http://paulwhiting.github.io/GospelLibraryVideos/roku_channel/recent/medialibrary_recent_English_#{run_glob}.xml\" showAsList=\"0\" showAsPortrait=\"0\" />\n" if line.include?("INSERT POINT")
end
File.open('../gh-pages/roku_channel/medialibrary_recent.xml', "w") do |file|
  file.puts recent
end

puts "Copying over rss and roku data"
system("cp medialibrary_#{run}/rss/* ../gh-pages/rss")
system("cp medialibrary_#{run}/roku/* ../gh-pages/roku_channel/")

puts "Splitting English into chunks"
system("ruby split.rb ../gh-pages/roku_channel/medialibrary_English.xml")

puts "Creating English subtitle database (TODO: other languages)"
system("ruby create_subtitle_db.rb ../gh-pages/roku_channel/medialibrary_English.xml > ../gh-pages/closed_captions/subtitles.json")

