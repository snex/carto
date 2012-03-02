require 'optparse'
$: << '.'
$: << 'lib/'
require 'lib/carto'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby carto.rb -m map-file -o output_file -t tileset"

  opts.on("-m", "--map-file [MAP_FILE]", "TSV Map File") do |m|
    options[:map_file] = m
  end

  opts.on("-o", "--output-file [OUTPUT_FILE]", "Output rpmap file") do |o|
    options[:output_file] = o
  end

  opts.on("-t", "--tileset [TILESET]", "Tileset") do |t|
    options[:tileset] = t
  end
end.parse!

carto = Carto.new options
carto.write_map
