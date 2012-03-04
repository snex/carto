require 'yaml'
require 'chunky_png'
require 'csv'
require 'map_file'
require 'awesome_print'

class Carto

  attr :tileset, :map_file

  def initialize options = {}
    default_options = { :tileset => 'default' }
    default_options.merge!(options)

    if !default_options.has_key?(:map_file)
      raise "No map file supplied!"
    end
    map = []
    CSV.foreach(default_options[:map_file], :col_sep => "\t") do |row|
      map << row
    end

    build_tileset default_options[:tileset]
    @map_file = RpTools::MapFile.new map
  end

  def write_map
    @map_file.save
  end

  private

  def build_tileset tileset_name
    yaml = YAML.load_file("config/#{tileset_name}.yml")
  end
end
