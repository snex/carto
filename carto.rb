require 'chunky_png'
require 'csv'

infile = ARGV[0]
map = []

tsv_mapping = {
  'F'   => ChunkyPNG::Image.from_file('/home/snex/mapstuff/FlagsDark.png'),
  'DT'  => ChunkyPNG::Image.from_file('/home/snex/mapstuff/Door.png'),
  'DB'  => ChunkyPNG::Image.from_file('/home/snex/mapstuff/Door.png').flip_horizontally!,
  'DR'  => ChunkyPNG::Image.from_file('/home/snex/mapstuff/Door.png').rotate_right!,
  'DL'  => ChunkyPNG::Image.from_file('/home/snex/mapstuff/Door.png').rotate_left!,
  'DST' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/DoorSecret.png'),
  'DSB' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/DoorSecret.png').flip_horizontally!,
  'DSR' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/DoorSecret.png').rotate_right!,
  'DSL' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/DoorSecret.png').rotate_left!,
  'DPT' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/Door.png'),
  'DPB' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/Door.png').flip_horizontally!,
  'DPR' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/Door.png').rotate_right!,
  'DPL' => ChunkyPNG::Image.from_file('/home/snex/mapstuff/Door.png').rotate_left!
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
