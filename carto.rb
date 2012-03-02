require 'optparse'
$: << '.'
$: << 'lib/'
require 'lib/carto'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby carto.rb -m map_file -o output_file -t tileset"

  opts.on("-m", "--map_file", "Map File") do |m|
    options[:map_file] = m
  end

  opts.on("-o", "--output_file", "Output file") do |o|
    options[:output_file] = o
  end

  opts.on("-t", "--tileset", "Tileset") do |t|
    options[:tileset] = t
  end
end.parse!

carto = Carto.new options
carto.write_map
