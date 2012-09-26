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
              map.each_with_index do |row, i|
                row.each_with_index do |tile, j|
                  next if tile.nil? || tile == 'F'
                  count += 1
                  token_map << count
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
                            xml.id_ asset_group.find_asset_by_tile(tile).asset_md5
                          } # net.rptools.lib.MD5Key
                        } # entry
                      } # imageAssetMap
                      case tile
                      when /.*(B|T)/
                        xml.x j * 25
                        xml.y_ i * 25 - 12
                      when /.*(L|R)/
                        xml.x j * 25 - 12
                        xml.y_ i * 25
                      else
                        # do nothing
                      end
                      xml.z 1
                      xml.anchorX 0
                      xml.anchorY 0
                      xml.sizeScale 2.0
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
                            xml.baGUID MapFile.generate_guid
                          } # net.rptools.maptool.model.GUID
                        } # entry
                      } # sizeMap
                      xml.snapToGrid false
                      xml.isVisible true
                      xml.visibleOnlyToOwner false
                      case tile
                      when 'DB', 'DT', 'DR', 'DL'
                        xml.name 'Door'
                      when 'DPB', 'DPT', 'DPR', 'DPL'
                        xml.name 'Portcullis'
                      when 'DSB', 'DST', 'DSR', 'DSL'
                        xml.name 'Secret Door'
                      else
                        # do nothing
                      end
                      xml.ownerType 0
                      xml.tokenShape "TOP_DOWN"
                      xml.tokenType "NPC"
                      xml.layer "OBJECT"
                      xml.propertyType "Basic"
                      xml.isFlippedX false
                      xml.isFlippedY false
                      xml.hasSight false
                      case tile
                      when 'DB', 'DT', 'DR', 'DL'
                        xml.notes 'Door'
                      when 'DPB', 'DPT', 'DPR', 'DPL'
                        xml.notes 'Portcullis'
                      when 'DSB', 'DST', 'DSR', 'DSL'
                        xml.gmNotes 'Secret Door'
                      else
                        # do nothing
                      end
                      xml.state
                    } # net.rptools.maptool.model.Token
                  } # entry
                end
              end
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
            xml.topology {
              xml.curves {
                map.each_with_index do |row, i|
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
            xml.visionType "OFF"
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
        draw_rect xml, -100, -100, 10, 10, tile
      end
    end

    def draw_floor_tiles xml
      @map.each_with_index do |row, i|
        row.each_with_index do |tile, j|
          next if tile.nil?
          draw_rect xml, j * 25, i * 25, 25, 25, 'F'
        end
      end
    end

    def draw_walls xml
      @map.each_with_index do |row, i|
        row.each_with_index do |tile, j|
          next if tile.nil?
          {:n => i - 1, :s => i + 1, :w => j - 1, :e => j + 1}.each do |dir, neighbor|
            next if i - 1 < 0 || i + 1 >= map.size || j - 1 < 0 || j + 1 >= row.size
            if ([:n, :s].include?(dir) && (map[neighbor][j].nil? || map[neighbor][j] =~ /S/)) || 
               ([:w, :e].include?(dir) && (map[i][neighbor].nil? || map[i][neighbor] =~ /S/))
              case dir
              when :n
                draw_rect xml, j * 25 - 5, i * 25, 35, 3, 'W'
              when :s
                draw_rect xml, j * 25 - 5, neighbor * 25 - 3, 35, 3, 'W'
              when :w
                draw_rect xml, j * 25, i * 25 - 5, 3, 35, 'W'
              when :e
                draw_rect xml, neighbor * 25 - 3, i * 25 - 5, 3, 35, 'W'
              else
                # do nothing
              end
            end # if
          end # {:n => i - 1, :s => i + 1, :w => j - 1, :e => j + 1}
        end # row.each_with_index
      end # map.each_with_index
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
      @tileset.each do |code, image_file|
        @assets << Asset.new(image_file)
      end
      @assets.uniq! { |asset| [asset.asset_md5, asset.image_file] }
    end

    def find_asset_by_tile tile
      @assets.find { |asset| asset.image_file == @tileset[tile] }
    end
  end
end
