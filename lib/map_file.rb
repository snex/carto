require 'nokogiri'
require 'zip/zip'
require 'digest/md5'
require 'awesome_print'

module RpTools
  class MapFile

    attr :content_file, :properties_file, :asset_group

    def initialize tileset, version, map = []
      @asset_group = AssetGroup.new tileset
      @content_file = ContentFile.new map, @asset_group, tileset
      @properties_file = PropertiesFile.new version
    end

    def save filename
      exists = false
      orig_filename = filename
      i = 1
      while exists = File.exists?(filename)
        filename = "output/#{File.basename(orig_filename, '.rpmap')}[#{i}].rpmap"
        i += 1
      end
      Zip::ZipFile.open(filename, Zip::ZipFile::CREATE) do |zipfile|
        zipfile.get_output_stream("content.xml") { |f| f.puts(@content_file.xml_data.to_xml) }
        zipfile.get_output_stream("properties.xml") { |f| f.puts(@properties_file.xml_data.to_xml) }
        zipfile.mkdir("assets")
        @asset_group.assets.each do |asset|
          zipfile.get_output_stream("assets/#{asset.asset_md5}") { |f| f.puts(asset.asset_xml.to_xml) }
          zipfile.get_output_stream("assets/#{asset.asset_md5}#{File.extname(asset.image_file)}") { |f| f.write(asset.asset_data) }
        end
      end
    end

    def self.generate_guid
      (0...24).map{65.+(rand(25)).chr}.join
    end
  end

  class ContentFile
    attr_reader :map, :asset_group, :tileset, :xml_data

    LIGHT_SOURCES = { 5  => 'wKgCY4PCvh0HAAAAAKgCAw==',
                      15 => 'wKgCY4PCvh0IAAAAAKgCAw==',
                      20 => 'wKgCY4PCvh0JAAAAAKgCAw==',
                      30 => 'wKgCY4PCvh0KAAAAAKgCAw==',
                      40 => 'wKgCY4PCvh0LAAAAAKgCAw==',
                      60 => 'wKgCY4PCvh0MAAAAAKgCAw=='
    }
    SIZES = { 'fine'       => 'fwABAc1lFSoBAAAAKgABAQ==',
              'dimunitive' => 'fwABAc1lFSoCAAAAKgABAQ==',
              'tiny'       => 'fwABAc5lFSoDAAAAKgABAA==',
              'small'      => 'fwABAc5lFSoEAAAAKgABAA==',
              'medium'     => 'fwABAc9lFSoFAAAAKgABAQ==',
              'large'      => 'fwABAdBlFSoGAAAAKgABAA==',
              'huge'       => 'fwABAdBlFSoHAAAAKgABAA==',
              'gargantuan' => 'fwABAdFlFSoIAAAAKgABAQ==',
              'colossal'   => 'fwABAeFlFSoJAAAAKgABAQ=='
    }

    def initialize map = [], asset_group, tileset
      @map = map
      @asset_group = asset_group
      @tileset = tileset
      token_map = []
      @xml_data = Nokogiri::XML::Builder.new do |xml|
        xml.send("net.rptools.maptool.util.PersistenceUtil_-PersistedMap") {
          xml.zone {
            xml.creationTime Time.now.to_i * 1000
            xml.id_ {
              xml.baGUID MapFile.generate_guid
            }
            draw_grid xml
            xml.gridColor -1
            xml.imageScaleX 1.0
            xml.imageScaleY 1.0
            xml.tokenVisionDistance 1000
            xml.unitsPerCell 5
            xml.drawables(:class => "linked-list")
            xml.gmDrawables(:class => "linked-list")
            xml.objectDrawables(:class => "linked-list")
            xml.backgroundDrawables(:class => "linked-list") {
              draw_background xml
            } # backgroundDrawables
            xml.labels(:class => "linked-hash-map")
            xml.tokenMap {
              count = 0
              obj_map = []
              map.each_with_index do |row, i|
                row.each_with_index do |tile, j|
                  if tile == 'F'
                    if @tileset['random'] && rand < @tileset['random']['freq'].to_f
                      obj_arr = []
                      @tileset['random']['objects'].each do |obj_name, obj_data|
                        obj_data['likelihood'].to_i.times do
                          obj_arr << obj_name
                        end
                      end
                      obj = obj_arr.sample
                      skip = false
                      squares_to_check = case @tileset['random']['objects'][obj]['size']
                                         when 'large'
                                           1
                                         when 'huge'
                                           2
                                         when 'gargantuan'
                                           3
                                         when 'colossal'
                                           5
                                         else
                                           0
                                         end
                      (i..i+squares_to_check).each do |sq_y|
                        (j..j+squares_to_check).each do |sq_x|
                          if map[sq_y] && map[sq_y][sq_x] && map[sq_y][sq_x] != 'F'
                            skip = true
                          elsif map[sq_y].nil? || map[sq_y][sq_x].nil?
                            skip = true
                          elsif ['small', 'medium', 'large',
                                 'huge', 'gargantuan', 'colossal'].include?(@tileset['random']['objects'][obj]['size']) &&
                                obj_map.include?([sq_x,sq_y])
                            skip = true
                          end
                        end
                      end
                      next if skip
                      count += 1
                      token_map << count
                      (i..i+squares_to_check).each do |sq_y|
                        (j..j+squares_to_check).each do |sq_x|
                          obj_map << [sq_x,sq_y]
                        end
                      end
                      offset = case @tileset['random']['objects'][obj]['size']
                               when 'fine', 'diminutive', 'tiny'
                                 12
                               when 'small'
                                 4
                               else
                                 1 # rand(1) = 0
                               end
                      draw_token xml,
                                 j * 25 + rand(offset),
                                 i * 25 + rand(offset),
                                 obj,
                                 { :layer    => 'BACKGROUND',
                                   :name     => generate_token_name(obj),
                                   :notes    => generate_token_notes(obj),
                                   :gm_notes => generate_token_gm_notes(obj),
                                   :facing   => rand(360),
                                   :light    => @tileset['random']['objects'][obj]['light'],
                                   :size     => @tileset['random']['objects'][obj]['size']
                                 }
                    end
                  elsif tile =~ /^D.*/
                    count += 1
                    token_map << count
                    case tile
                    when /.*(B|T)/
                      draw_token xml,
                                 j * 25,
                                 i * 25 - 12,
                                 tile,
                                 { :layer    => 'OBJECT',
                                   :name     => generate_token_name(tile),
                                   :notes    => generate_token_notes(tile),
                                   :gm_notes => generate_token_gm_notes(tile),
                                   :size     => 'large'
                                 }
                    when /.*(L|R)/
                      draw_token xml,
                                 j * 25 - 12,
                                 i * 25,
                                 tile,
                                 { :layer    => 'OBJECT',
                                   :name     => generate_token_name(tile),
                                   :notes    => generate_token_notes(tile),
                                   :gm_notes => generate_token_gm_notes(tile),
                                   :size     => 'large'
                                 }
                    else
                      # do nothing
                    end
                  else
                    # do nothing
                  end
                end # row.each_with_index
              end # map.each_with_index
            } # tokenMap
            xml.exposedAreaMeta
            xml.tokenOrderedList(:class => "linked-list") {
              token_map.each do |refpoint|
                xml.send("net.rptools.maptool.model.Token", :reference => "../../tokenMap/entry[#{refpoint}]/net.rptools.maptool.model.Token")
              end
            } # tokenOrderedList
            xml.initiativeList {
              xml.tokens
              xml.current -1
              xml.round -1
              xml.zoneId(:reference => "../../id")
              xml.fullUpdate false
              xml.hideNPC true
            } # initiativeList
            xml.exposedArea {
              xml.curves
            } # exposedArea
            xml.hasFog true
            xml.fogPaint(:class => "net.rptools.maptool.model.drawing.DrawableColorPaint") {
              xml.color -16777216
            } # fogPaint
            draw_topology xml
            xml.backgroundPaint(:class => "net.rptools.maptool.model.drawing.DrawableColorPaint") {
              xml.color -16777216
            } # backgroundPaint
            xml.boardPosition {
              xml.x 0
              xml.y_ 0
            } # boardPosition
            xml.drawBoard true
            xml.boardChanged false
            xml.name "Grasslands"
            xml.isVisible true
            xml.visionType "NIGHT"
            xml.height 0
            xml.width 0
          } # zone
          xml.assetMap {
            ['F', 'W'].each_with_index do |paint, i|
              xml.entry {
                xml.send("net.rptools.lib.MD5Key", :reference => "../../../zone/backgroundDrawables/net.rptools.maptool.model.drawing.DrawnElement[#{i+1}]/pen/paint/assetId")
                xml.null
              } # entry
            end
            token_map.each do |refpoint|
              xml.entry {
                xml.send("net.rptools.lib.MD5Key", :reference => "../../../zone/tokenMap/entry[#{refpoint}]/net.rptools.maptool.model.Token/imageAssetMap/entry/net.rptools.lib.MD5Key")
                xml.null
              } # entry
            end
          } # assetMap
        } # net.rptools.maptool.util.PersistenceUtil_-PersistedMap
      end
    end

    private

    def draw_grid xml
      xml.grid(:class => "net.rptools.maptool.model.SquareGrid") {
        xml.offsetX 0
        xml.offsetY 0
        xml.size 25
        xml.zone(:reference => "../..")
        xml.cellShape {
          xml.curves {
            xml.send("sun.awt.geom.Order0") {
              xml.direction 1
              xml.x 0.0
              xml.y_ 0.0
            } # sun.awt.geom.Order0
            xml.send("sun.awt.geom.Order1") {
              xml.direction 1
              xml.x0 0.0
              xml.y0 0.0
              xml.x1 0.0
              xml.y1 25.0
              xml.xmin 0.0
              xml.xmax 0.0
            } # sun.awt.geom.Order1
            xml.send("sun.awt.geom.Order1") {
              xml.direction -1
              xml.x0 25.0
              xml.y0 0.0
              xml.x1 25.0
              xml.y1 25.0
              xml.xmin 25.0
              xml.xmax 25.0
            } # sun.awt.geom.Order1
          } # curves
        } # cellShape
      } # grid
    end

    def draw_background xml
      draw_anchor_tiles xml
      draw_floor_tiles xml
      draw_walls xml
    end

    def draw_anchor_tiles xml
      ['F', 'W'].each do |tile|
        draw_rect xml,
          -100,
          -100,
          10,
          10,
          tile
      end
    end

    def draw_floor_tiles xml
      @map.each_with_index do |row, i|
        row.each_with_index do |tile, j|
          next if tile.nil?
          draw_rect xml,
            j * 25,
            i * 25,
            25,
            25,
            'F'
        end
      end
    end

    def draw_walls xml, options = { :thickness => 3 }
      @map.each_with_index do |row, i|
        row.each_with_index do |tile, j|
          next if tile.nil?
          {:n => i - 1, :s => i + 1, :w => j - 1, :e => j + 1}.each do |dir, neighbor|
            next if i - 1 < 0 || i + 1 >= map.size || j - 1 < 0 || j + 1 >= row.size
            if ([:n, :s].include?(dir) && (map[neighbor][j].nil? || map[neighbor][j] =~ /S/)) || 
               ([:w, :e].include?(dir) && (map[i][neighbor].nil? || map[i][neighbor] =~ /S/))
              case dir
              when :n
                draw_north_wall xml, j, i, options
              when :s
                draw_south_wall xml, j, neighbor, options
              when :w
                draw_west_wall xml, j, i, options
              when :e
                draw_east_wall xml, neighbor, i, options
              else
                # do nothing
              end
            end # if
          end # {:n => i - 1, :s => i + 1, :w => j - 1, :e => j + 1}
        end # row.each_with_index
      end # map.each_with_index
    end

    def draw_north_wall xml, x, y, options = { :thickness => 3 }
      draw_rect xml,
        x * 25 - options[:thickness],
        y * 25,
        25 + options[:thickness] * 2,
        options[:thickness],
        'W'
    end

    def draw_south_wall xml, x, y, options = { :thickness => 3 }
      draw_rect xml,
        x * 25 - options[:thickness],
        y * 25 - options[:thickness],
        25 + options[:thickness] * 2,
        options[:thickness],
        'W'
    end

    def draw_east_wall xml, x, y, options = { :thickness => 3 }
      draw_rect xml,
        x * 25 - options[:thickness],
        y * 25 - options[:thickness],
        options[:thickness],
        25 + options[:thickness] * 2,
        'W'
    end

    def draw_west_wall xml, x, y, options = { :thickness => 3 }
      draw_rect xml,
        x * 25,
        y * 25 - options[:thickness],
        options[:thickness],
        25 + options[:thickness] * 2,
        'W'
    end

    def draw_rect(xml, x, y, width, height, tile)
      xml.send("net.rptools.maptool.model.drawing.DrawnElement") {
        xml.drawable(:class => "net.rptools.maptool.model.drawing.ShapeDrawable") {
          xml.id_ {
            xml.baGUID MapFile.generate_guid
          } # id
          xml.layer "BACKGROUND"
          xml.shape(:class => "java.awt.Rectangle") {
            xml.x x
            xml.y_ y
            xml.width width
            xml.height height
          } # shape
          xml.useAntiAliasing false
        } # drawable
        xml.pen {
          xml.foregroundMode 0
          xml.paint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
            xml.assetId {
              xml.id_ @asset_group.find_asset_by_tile(tile).asset_md5
            } # assetId
            xml.scale 1.0
          } # paint
          xml.backgroundMode 0
          xml.backgroundPaint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
            xml.assetId {
              xml.id_ @asset_group.find_asset_by_tile(tile).asset_md5
            } # assetId
            xml.scale 1.0
          } # backgroundPaint
          xml.thickness 1.0
          xml.eraser false
          xml.opacity 1.0
          xml.color 0
          xml.backgroundColor 0
        } # pen
      } # send("net.rptools.maptool.model.drawing.DrawnElement")
    end

    def draw_token xml, x, y, asset_code, options = {}
      default_options = { :layer  => 'BACKGROUND',
                          :name   => 'Unknown',
                          :facing => -90,
                          :size   => 'medium'
                        }
      options.merge!(default_options) { |key, v1, v2| v1 }
      xml.entry {
        token_guid = MapFile.generate_guid
        xml.send("net.rptools.maptool.model.GUID") {
          xml.baGUID token_guid
        } # net.rptools.maptool.model.GUID
        xml.send("net.rptools.maptool.model.Token") {
          xml.id_ {
            xml.baGUID token_guid
          } # id
          xml.beingImpersonated false
          xml.exposedAreaGUID {
            xml.baGUID MapFile.generate_guid
          } # exposedAreaGUID
          xml.imageAssetMap {
            xml.entry {
              xml.null
              xml.send("net.rptools.lib.MD5Key") {
                xml.id_ asset_group.find_asset_by_tile(asset_code).asset_md5
              } # net.rptools.lib.MD5Key
            } # entry
          } # imageAssetMap
          xml.x x
          xml.y_ y
          xml.z 1
          xml.anchorX 0
          xml.anchorY 0
          xml.sizeScale 1.0
          xml.lastX 0
          xml.lastY 0
          xml.snapToScale true
          xml.width 250
          xml.height 100
          xml.scaleX 1.0
          xml.scaleY 1.0
          xml.sizeMap {
            xml.entry {
              xml.send("java-class", "net.rptools.maptool.model.SquareGrid")
              xml.send("net.rptools.maptool.model.GUID") {
                xml.baGUID SIZES[options[:size]]
              } # net.rptools.maptool.model.GUID
            } # entry
          } # sizeMap
          xml.snapToGrid false
          xml.isVisible true
          xml.visibleOnlyToOwner false
          xml.name options[:name]
          xml.ownerType 0
          xml.tokenShape "TOP_DOWN"
          xml.tokenType "NPC"
          xml.layer options[:layer]
          xml.propertyType "Basic"
          xml.facing options[:facing]
          xml.isFlippedX false
          xml.isFlippedY false
          if options[:light]
            xml.lightSourceList {
              xml.send("net.rptools.maptool.model.AttachedLightSource") {
                xml.lightSourceId {
                  xml.baGUID LIGHT_SOURCES[options[:light]]
                } # lightSourceId
                xml.direction "CENTER"
              } # net.rptools.maptool.model.AttachedLightSource
            } # lightSourceList
          end # if light
          xml.hasSight false
          xml.notes options[:notes] if options[:notes]
          xml.gmNotes options[:gm_notes] if options[:gm_notes]
          xml.state
        } # net.rptools.maptool.model.Token
      } # entry
    end

    def generate_token_name tile
      case tile
      when 'DB', 'DT', 'DR', 'DL'
        'Door'
      when 'DPB', 'DPT', 'DPR', 'DPL'
        'Portcullis'
      when 'DSB', 'DST', 'DSR', 'DSL'
        'Secret Door'
      else
        @tileset['random']['objects'][tile]['name']
      end
    end

    def generate_token_notes tile
      case tile
      when 'DB', 'DT', 'DR', 'DL'
        'Door'
      when 'DPB', 'DPT', 'DPR', 'DPL'
        'Portcullis'
      when 'DSB', 'DST', 'DSR', 'DSL'
        ''
      else
        @tileset['random']['objects'][tile]['notes']
      end
    end

    def generate_token_gm_notes tile
      case tile
      when 'DB', 'DT', 'DR', 'DL'
        'Door'
      when 'DPB', 'DPT', 'DPR', 'DPL'
        'Portcullis'
      when 'DSB', 'DST', 'DSR', 'DSL'
        'Secret Door'
      else
        @tileset['random']['objects'][tile]['gm_notes']
      end
    end

    def draw_topology xml
      xml.topology {
        xml.curves {
          @map.each_with_index do |row, i|
            row.each_with_index do |tile, j|
              case tile
              when 'DSB', 'DST', 'DSR', 'DSL', nil
                xml.send("sun.awt.geom.Order0") {
                  xml.direction 1
                  xml.x  j * 25.0
                  xml.y_ i * 25.0
                } # sun.awt.geom.Order0
                xml.send("sun.awt.geom.Order1") {
                  xml.direction 1
                  xml.x0 j * 25.0
                  xml.y0 i * 25.0
                  xml.x1 j * 25.0
                  xml.y1 (i + 1) * 25.0
                  xml.xmin j * 25.0
                  xml.xmax i * 25.0
                } # sun.awt.geom.Order1
                xml.send("sun.awt.geom.Order1") {
                  xml.direction -1
                  xml.x0 (j + 1) * 25.0
                  xml.y0 i * 25.0
                  xml.x1 (j + 1) * 25.0
                  xml.y1 (i + 1) * 25.0
                  xml.xmin (j + 1) * 25.0
                  xml.xmax (i + 1) * 25.0
                } # sun.awt.geom.Order1
              when 'DB', 'DT'
                xml.send("sun.awt.geom.Order0") {
                  xml.direction 1
                  xml.x  j * 25.0
                  xml.y_ (i + 0.45) * 25.0
                } # sun.awt.geom.Order0
                xml.send("sun.awt.geom.Order1") {
                  xml.direction 1
                  xml.x0 j * 25.0
                  xml.y0 (i + 0.45) * 25.0
                  xml.x1 j * 25.0
                  xml.y1 (i + 0.55) * 25.0
                  xml.xmin j * 25.0
                  xml.xmax i * 25.0
                } # sun.awt.geom.Order1
                xml.send("sun.awt.geom.Order1") {
                  xml.direction -1
                  xml.x0 (j + 1) * 25.0
                  xml.y0 (i + 0.45) * 25.0
                  xml.x1 (j + 1) * 25.0
                  xml.y1 (i + 0.55) * 25.0
                  xml.xmin (j + 1) * 25.0
                  xml.xmax (i + 1) * 25.0
                } # sun.awt.geom.Order1
              when 'DR', 'DL'
                xml.send("sun.awt.geom.Order0") {
                  xml.direction 1
                  xml.x  (j + 0.45) * 25.0
                  xml.y_ i * 25.0
                } # sun.awt.geom.Order0
                xml.send("sun.awt.geom.Order1") {
                  xml.direction 1
                  xml.x0 (j + 0.45) * 25.0
                  xml.y0 i * 25.0
                  xml.x1 (j + 0.45) * 25.0
                  xml.y1 (i + 1) * 25.0
                  xml.xmin j * 25.0
                  xml.xmax i * 25.0
                } # sun.awt.geom.Order1
                xml.send("sun.awt.geom.Order1") {
                  xml.direction -1
                  xml.x0 (j + 0.55) * 25.0
                  xml.y0 i * 25.0
                  xml.x1 (j + 0.55) * 25.0
                  xml.y1 (i + 1) * 25.0
                  xml.xmin (j + 1) * 25.0
                  xml.xmax (i + 1) * 25.0
                } # sun.awt.geom.Order1
              else
                # do nothing
              end
            end
          end
        } # curves
      } # topology
    end
  end

  class PropertiesFile
    attr_reader :xml_data

    def initialize version
      @xml_data = Nokogiri::XML::Builder.new do
        map {
          entry {
           string "campaignVersion"
           string "1.3.85"
          } # entry
          entry {
            string "version"
            string version
          } # entry
        } # map
      end
    end
  end

  class Asset
    attr :asset_xml, :asset_data, :asset_md5, :image_file

    def initialize image_file
      @image_file = image_file
      @asset_data = File.open(image_file, 'rb') { |io| io.read }
      @asset_md5 = Digest::MD5.hexdigest(@asset_data)
      @asset_xml = Nokogiri::XML::Builder.new do |xml|
        xml.send("net.rptools.maptool.model.Asset") {
          xml.id_ {
            xml.id_ @asset_md5
          } # id
          xml.name File.basename(image_file)
          xml.extension File.extname(image_file).gsub(/\./, '')
          xml.image
        } # net.rptools.maptool.model.Asset
      end
    end
  end

  class AssetGroup
    attr :assets, :tileset

    def initialize tileset
      @tileset = tileset
      @assets = []
      @tileset['tiles'].each do |code, image_file|
        @assets << Asset.new(image_file)
      end
      if @tileset['random']
        @tileset['random']['objects'].each do |obj, data|
          @assets << Asset.new(data['file'])
        end
      end
      @assets.uniq! { |asset| [asset.asset_md5, asset.image_file] }
    end

    def find_asset_by_tile obj
      asset = @assets.find { |asset| asset.image_file == @tileset['tiles'][obj] }
      if asset.nil?
        asset = @assets.find { |asset| asset.image_file == @tileset['random']['objects'][obj]['file'] }
      end
      return asset
    end

  end
end
