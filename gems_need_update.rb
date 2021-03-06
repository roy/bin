#!/usr/bin/env ruby 
puts "looking for the gems to upgrade..."
gem_info = Struct.new(:name, :version)
to_reinstall = []
Dir.glob('/Library/Ruby/Gems/**/*.bundle').map do |path| 
  path =~ /.*1.8\/gems\/(.*)-(.*?)\/.*/
  name, version = $1, $2
  bundle_info = `file path`
  to_reinstall << gem_info.new(name, version) unless bundle_info =~ /bundle x86_64/
end

gemnames = to_reinstall.map{|ginfo| ginfo.name}.uniq.delete_if{|name| name =~ /mysql|passenger/}
puts "***"
puts "Please reinstall:"
gemnames.each do |name|
  gems = to_reinstall.select{|ginfo| ginfo.name == name}
  puts "#{name} versions: #{gems.map{|ginfo| ginfo.version}.join(', ')}"
end 

puts "or uninstall all gems that need to be reinstalled:\n"
puts "$ sudo gem uninstall #{gemnames.join(' ')}"
puts " "
puts "and reinstall them:\n"
puts "$ sudo gem install #{gemnames.join(' ')}"
