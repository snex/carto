require 'yaml'
require 'csv'
require 'map_file'
require 'awesome_print'

class Carto

  attr :tileset, :map_file, :output_file

  def initialize options = {}
    default_options = { :tileset     => 'dungeon',
                        :output_file => 'new_map.rpmap',
                        :version     => '1.3.b88'
                      }
    default_options.merge!(options)

    if !default_options.has_key?(:map_file)
      raise "No map file supplied!"
    end
    map = []
    CSV.foreach(default_options[:map_file], :col_sep => "\t") do |row|
      map << row
    end

    @output_file = default_options[:output_file]
    @map_file = RpTools::MapFile.new build_tileset(default_options[:tileset]), default_options[:version], map
  end

  def write_map
    @map_file.save "output/#{@output_file}"
  end

  private

  def build_tileset tileset_name
    YAML.load_file("config/#{tileset_name}.yml")
  end
end
