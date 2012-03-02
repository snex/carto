require 'chunky_png'
require 'csv'

infile = ARGV[0]
map = []

tsv_mapping = {
  'F' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/FlagsDark.png')
}

CSV.foreach(infile, :col_sep => "\t") do |row|
  map << row
end

map_png = ChunkyPNG::Image.new(50 * map.size, 50 * map[0].size, ChunkyPNG::Color::TRANSPARENT)

map.each_with_index do |row, i|
  row.each_with_index do |tile, j|
    if tsv_mapping.has_key?(tile)
      map_png.compose!(tsv_mapping[tile], 50 * j, 50 * i)
    end
  end
end

map_png.save('blah.png', :fast_rgba)
