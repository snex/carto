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
    attr_reader :xml_data

    def initialize map = [], asset_group, tileset
      token_map = []
      @xml_data = Nokogiri::XML::Builder.new do
        send("net.rptools.maptool.util.PersistenceUtil_-PersistedMap") {
          zone {
            creationTime Time.now.to_i * 1000
            id_ {
              baGUID MapFile.generate_guid
            }
            grid(:class => "net.rptools.maptool.model.SquareGrid") {
              offsetX 0
              offsetY 0
              size 25
              zone(:reference => "../..")
              cellShape {
                curves {
                  send("sun.awt.geom.Order0") {
                    direction 1
                    x 0.0
                    y_ 0.0
                  } # sun.awt.geom.Order0
                  send("sun.awt.geom.Order1") {
                    direction 1
                    x0 0.0
                    y0 0.0
                    x1 0.0
                    y1 25.0
                    xmin 0.0
                    xmax 0.0
                  } # sun.awt.geom.Order1
                  send("sun.awt.geom.Order1") {
                    direction -1
                    x0 25.0
                    y0 0.0
                    x1 25.0
                    y1 25.0
                    xmin 25.0
                    xmax 25.0
                  } # sun.awt.geom.Order1
                } # curves
              } # cellShape
            } # grid
            gridColor -1
            imageScaleX 1.0
            imageScaleY 1.0
            tokenVisionDistance 1000
            unitsPerCell 5
            drawables(:class => "linked-list")
            gmDrawables(:class => "linked-list")
            objectDrawables(:class => "linked-list")
            backgroundDrawables(:class => "linked-list") {
              ['F', 'W'].each do |paint|
                send("net.rptools.maptool.model.drawing.DrawnElement") {
                  drawable(:class => "net.rptools.maptool.model.drawing.ShapeDrawable") {
                    id_ {
                      baGUID MapFile.generate_guid
                    } # id
                    layer "BACKGROUND"
                    shape(:class => "java.awt.Rectangle") {
                      x -100
                      y_ -100
                      width 10
                      height 10
                    } # shape
                    useAntiAliasing false
                  } # drawable
                  pen {
                    foregroundMode 0
                    paint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
                      assetId {
                        id_ asset_group.find_asset_by_tile(paint).asset_md5
                      } # assetId
                      scale 1.0
                    } # paint
                    backgroundMode 0
                    backgroundPaint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
                      assetId {
                        id_ asset_group.find_asset_by_tile(paint).asset_md5
                      } # assetId
                      scale 1.0
                    } # backgroundPaint
                    thickness 1.0
                    eraser false
                    opacity 1.0
                    color 0
                    backgroundColor 0
                  } # pen
                } # send("net.rptools.maptool.model.drawing.DrawnElement")
              end # ['F', 'W'].each
              map.each_with_index do |row, i|
                row.each_with_index do |tile, j|
                  next if tile.nil?
                  send("net.rptools.maptool.model.drawing.DrawnElement") {
                    drawable(:class => "net.rptools.maptool.model.drawing.ShapeDrawable") {
                      id_ {
                        baGUID MapFile.generate_guid
                      } # id_
                      layer "BACKGROUND"
                      shape(:class => "java.awt.Rectangle") {
                        x j * 25
                        y_ i * 25
                        width 25
                        height 25
                      } # shape
                      useAntiAliasing false
                    } # drawable
                    pen {
                      foregroundMode 0
                      paint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
                        assetId {
                          id_ asset_group.find_asset_by_tile('F').asset_md5
                        } # assetId
                        scale 1.0
                      } # paint
                      backgroundMode 0
                      backgroundPaint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
                        assetId {
                          id_ asset_group.find_asset_by_tile('F').asset_md5
                        } # assetId
                        scale 1.0
                      } # backgroundPaint
                      thickness 1.0
                      eraser false
                      opacity 1.0
                      color 0
                      backgroundColor 0
                    } # pen
                  } # net.rptools.maptool.model.drawing.DrawnElement
                end # row.each_with_index
              end # map.each_with_index
              map.each_with_index do |row, i|
                row.each_with_index do |tile, j|
                  next if tile.nil?
                  {:n => i - 1, :s => i + 1, :w => j - 1, :e => j + 1}.each do |dir, neighbor|
                    next if i - 1 < 0 || i + 1 >= map.size || j - 1 < 0 || j + 1 >= row.size
                    if ([:n, :s].include?(dir) && (map[neighbor][j].nil? || map[neighbor][j] =~ /S/)) || 
                       ([:w, :e].include?(dir) && (map[i][neighbor].nil? || map[i][neighbor] =~ /S/))
                      send("net.rptools.maptool.model.drawing.DrawnElement") {
                        drawable(:class => "net.rptools.maptool.model.drawing.ShapeDrawable") {
                          id_ {
                            baGUID MapFile.generate_guid
                          } # id_
                          layer "BACKGROUND"
                          shape(:class => "java.awt.Rectangle") {
                            case dir
                            when :n
                              x j * 25 - 5
                              y_ i * 25
                              width 35
                              height 5
                            when :s
                              x j * 25 - 5
                              y_ neighbor * 25 - 5
                              width 35
                              height 5
                            when :w
                              x j * 25
                              y_ i * 25 - 5
                              width 5
                              height 35
                            when :e
                              x neighbor * 25 - 5
                              y_ i * 25 - 5
                              width 5
                              height 35
                            else
                              # do nothing
                            end
                          } # shape
                          useAntiAliasing false
                        } # drawable
                        pen {
                          foregroundMode 0
                          paint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
                            assetId {
                              id_ asset_group.find_asset_by_tile('W').asset_md5
                            } # assetId
                          scale 1.0
                          } # paint
                          backgroundMode 0
                          backgroundPaint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
                            assetId {
                              id_ asset_group.find_asset_by_tile('W').asset_md5
                            } # assetId
                            scale 1.0
                          } # backgroundPaint
                          thickness 1.0
                          eraser false
                          opacity 1.0
                          color 0
                          backgroundColor 0
                        } # pen
                      } # net.rptools.maptool.model.drawing.DrawnElement
                    end # if
                  end # {:n => i - 1, :s => i + 1, :w => j - 1, :e => j + 1}
                end # row.each_with_index
              end # map.each_with_index
            } # backgroundDrawables
            labels(:class => "linked-hash-map")
            tokenMap {
              count = 0
              map.each_with_index do |row, i|
                row.each_with_index do |tile, j|
                  next if tile.nil? || tile == 'F'
                  count += 1
                  token_map << count
                  entry {
                    token_guid = MapFile.generate_guid
                    send("net.rptools.maptool.model.GUID") {
                      baGUID token_guid
                    } # net.rptools.maptool.model.GUID
                    send("net.rptools.maptool.model.Token") {
                      id_ {
                        baGUID token_guid
                      } # id
                      beingImpersonated false
                      exposedAreaGUID {
                        baGUID MapFile.generate_guid
                      } # exposedAreaGUID
                      imageAssetMap {
                        entry {
                          null
                          send("net.rptools.lib.MD5Key") {
                            id_ asset_group.find_asset_by_tile(tile).asset_md5
                          } # net.rptools.lib.MD5Key
                        } # entry
                      } # imageAssetMap
                      case tile
                      when /.*(B|T)/
                        x j * 25
                        y_ i * 25 - 12
                      when /.*(L|R)/
                        x j * 25 - 12
                        y_ i * 25
                      else
                        # do nothing
                      end
                      z 1
                      anchorX 0
                      anchorY 0
                      sizeScale 2.0
                      lastX 0
                      lastY 0
                      snapToScale true
                      width 250
                      height 100
                      scaleX 1.0
                      scaleY 1.0
                      sizeMap {
                        entry {
                          send("java-class", "net.rptools.maptool.model.SquareGrid")
                          send("net.rptools.maptool.model.GUID") {
                            baGUID MapFile.generate_guid
                          } # net.rptools.maptool.model.GUID
                        } # entry
                      } # sizeMap
                      snapToGrid false
                      isVisible true
                      visibleOnlyToOwner false
                      case tile
                      when 'DB', 'DT', 'DR', 'DL'
                        name 'Door'
                      when 'DPB', 'DPT', 'DPR', 'DPL'
                        name 'Portcullis'
                      when 'DSB', 'DST', 'DSR', 'DSL'
                        name 'Secret Door'
                      else
                        # do nothing
                      end
                      ownerType 0
                      tokenShape "TOP_DOWN"
                      tokenType "NPC"
                      layer "BACKGROUND"
                      propertyType "Basic"
                      isFlippedX false
                      isFlippedY false
                      hasSight false
                      case tile
                      when 'DB', 'DT', 'DR', 'DL'
                        notes 'Door'
                      when 'DPB', 'DPT', 'DPR', 'DPL'
                        notes 'Portcullis'
                      when 'DSB', 'DST', 'DSR', 'DSL'
                        gmNotes 'Secret Door'
                      else
                        # do nothing
                      end
                      state
                    } # net.rptools.maptool.model.Token
                  } # entry
                end
              end
            } # tokenMap
            exposedAreaMeta
            tokenOrderedList(:class => "linked-list") {
              token_map.each do |refpoint|
                send("net.rptools.maptool.model.Token", :reference => "../../tokenMap/entry[#{refpoint}]/net.rptools.maptool.model.Token")
              end
            } # tokenOrderedList
            initiativeList {
              tokens
              current -1
              round -1
              zoneId(:reference => "../../id")
              fullUpdate false
              hideNPC false
            } # initiativeList
            exposedArea {
              curves
            } # exposedArea
            hasFog true
            fogPaint(:class => "net.rptools.maptool.model.drawing.DrawableColorPaint") {
              color -16777216
            } # fogPaint
            topology {
              curves {
                map.each_with_index do |row, i|
                  row.each_with_index do |tile, j|
                    case tile
                    when 'DSB', 'DST', 'DSR', 'DSL', nil
                      send("sun.awt.geom.Order0") {
                        direction 1
                        x  j * 25.0
                        y_ i * 25.0
                      } # sun.awt.geom.Order0
                      send("sun.awt.geom.Order1") {
                        direction 1
                        x0 j * 25.0
                        y0 i * 25.0
                        x1 j * 25.0
                        y1 (i + 1) * 25.0
                        xmin j * 25.0
                        xmax i * 25.0
                      } # sun.awt.geom.Order1
                      send("sun.awt.geom.Order1") {
                        direction -1
                        x0 (j + 1) * 25.0
                        y0 i * 25.0
                        x1 (j + 1) * 25.0
                        y1 (i + 1) * 25.0
                        xmin (j + 1) * 25.0
                        xmax (i + 1) * 25.0
                      } # sun.awt.geom.Order1
                    when 'DB', 'DT'
                      send("sun.awt.geom.Order0") {
                        direction 1
                        x  j * 25.0
                        y_ (i + 0.45) * 25.0
                      } # sun.awt.geom.Order0
                      send("sun.awt.geom.Order1") {
                        direction 1
                        x0 j * 25.0
                        y0 (i + 0.45) * 25.0
                        x1 j * 25.0
                        y1 (i + 0.55) * 25.0
                        xmin j * 25.0
                        xmax i * 25.0
                      } # sun.awt.geom.Order1
                      send("sun.awt.geom.Order1") {
                        direction -1
                        x0 (j + 1) * 25.0
                        y0 (i + 0.45) * 25.0
                        x1 (j + 1) * 25.0
                        y1 (i + 0.55) * 25.0
                        xmin (j + 1) * 25.0
                        xmax (i + 1) * 25.0
                      } # sun.awt.geom.Order1
                    when 'DR', 'DL'
                      send("sun.awt.geom.Order0") {
                        direction 1
                        x  (j + 0.45) * 25.0
                        y_ i * 25.0
                      } # sun.awt.geom.Order0
                      send("sun.awt.geom.Order1") {
                        direction 1
                        x0 (j + 0.45) * 25.0
                        y0 i * 25.0
                        x1 (j + 0.45) * 25.0
                        y1 (i + 1) * 25.0
                        xmin j * 25.0
                        xmax i * 25.0
                      } # sun.awt.geom.Order1
                      send("sun.awt.geom.Order1") {
                        direction -1
                        x0 (j + 0.55) * 25.0
                        y0 i * 25.0
                        x1 (j + 0.55) * 25.0
                        y1 (i + 1) * 25.0
                        xmin (j + 1) * 25.0
                        xmax (i + 1) * 25.0
                      } # sun.awt.geom.Order1
                    else
                      # do nothing
                    end
                  end
                end
              } # curves
            } # topology
            backgroundPaint(:class => "net.rptools.maptool.model.drawing.DrawableColorPaint") {
              color -16777216
            } # backgroundPaint
            boardPosition {
              x 0
              y_ 0
            } # boardPosition
            drawBoard true
            boardChanged false
            name "Grasslands"
            isVisible true
            visionType "OFF"
            height 0
            width 0
          } # zone
          assetMap {
            ['F', 'W'].each_with_index do |paint, i|
              entry {
                send("net.rptools.lib.MD5Key", :reference => "../../../zone/backgroundDrawables/net.rptools.maptool.model.drawing.DrawnElement[#{i+1}]/pen/paint/assetId")
                null
              } # entry
            end
            token_map.each do |refpoint|
              entry {
                send("net.rptools.lib.MD5Key", :reference => "../../../zone/tokenMap/entry[#{refpoint}]/net.rptools.maptool.model.Token/imageAssetMap/entry/net.rptools.lib.MD5Key")
                null
              } # entry
            end
          } # assetMap
        } # net.rptools.maptool.util.PersistenceUtil_-PersistedMap
      end
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
