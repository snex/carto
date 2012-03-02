require 'nokogiri'
require 'zip/zip'
require 'digest/md5'
require 'awesome_print'

module RpTools
  class MapFile

    attr :content_file, :properties_file, :asset_group

    def initialize map = []
      @asset_group = AssetGroup.new
      @content_file = ContentFile.new map, @asset_group
      @properties_file = PropertiesFile.new
    end

    def save filename = 'output/new_map.rpmap'
      Zip::ZipFile.open(filename, Zip::ZipFile::CREATE) do |zipfile|
        zipfile.get_output_stream("content.xml") { |f| f.puts(@content_file.xml_data.to_xml) }
        zipfile.get_output_stream("properties.xml") { |f| f.puts(@properties_file.xml_data.to_xml) }
        zipfile.mkdir("assets")
        @asset_group.assets.each do |asset|
          zipfile.get_output_stream("assets/#{Digest::MD5.hexdigest(asset_group.assets[0].asset_data)}") { |f| f.puts(asset.asset_xml.to_xml) }
          zipfile.get_output_stream("assets/#{Digest::MD5.hexdigest(asset_group.assets[0].asset_data)}.png") { |f| f.write(asset.asset_data) }
        end
      end
    end
  end

  class ContentFile
    attr_reader :xml_data

    def initialize map = [], asset_group = []
      @xml_data = Nokogiri::XML::Builder.new do
        send("net.rptools.maptool.util.PersistenceUtil_-PersistedMap") {
          zone {
            creationTime Time.now.to_i * 1000
            id_ {
              baGUID (0...8).map{65.+(rand(25)).chr}.join
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
            gridColor -16777216
            imageScaleX 1.0
            imageScaleY 1.0
            tokenVisionDistance 1000
            unitsPerCell 5
            drawables(:class => "linked-list") {
              send("net.rptools.maptool.model.drawing.DrawnElement") {
                drawable(:class => "net.rptools.maptool.model.drawing.ShapeDrawable") {
                  id_ {
                    baGUID (0...8).map{65.+(rand(25)).chr}.join
                  } # id_
                  layer "BACKGROUND"
                  shape(:class => "java.awt.Rectangle") {
                    x 0
                    y_ 0
                    width 25
                    height 25
                  } # shape
                  useAntiAliasing false
                } # drawable
                pen {
                  foregroundMode 0
                  paint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
                    assetId {
                      id_ Digest::MD5.hexdigest(asset_group.assets[0].asset_data)
                    } # assetId
                    scale 1.0
                  } # paint
                  backgroundMode 0
                  backgroundPaint(:class => "net.rptools.maptool.model.drawing.DrawableTexturePaint") {
                    assetId {
                      id_ Digest::MD5.hexdigest(asset_group.assets[0].asset_data)
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
            } # drawables
            gmDrawables(:class => "linked-list")
            objectDrawables(:class => "linked-list")
            backgroundDrawables(:class => "linked-list")
            labels(:class => "linked-hash-map")
            tokenMap
            exposedAreaMeta
            tokenOrderedList(:class => "linked-list")
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
            entry {
              send("net.rptools.lib.MD5Key", :reference => "../../../zone/drawables/net.rptools.maptool.model.drawing.DrawnElement/pen/paint/assetId")
              null
            } # entry
          } # assetMap
        } # net.rptools.maptool.util.PersistenceUtil_-PersistedMap
      end
    end
  end

  class PropertiesFile
    attr_reader :xml_data

    def initialize
      @xml_data = Nokogiri::XML::Builder.new do
        map {
          entry {
           string "campaignVersion"
           string "1.3.85"
          } # entry
          entry {
            string "version"
            string "1.3.b87"
          } # entry
        } # map
      end
    end
  end

  class Asset
    attr :asset_xml, :asset_data

    def initialize
      @asset_data = File.open('assets/default/FlagsDark.png', 'rb') { |io| io.read }
      @asset_xml = Nokogiri::XML::Builder.new do |xml|
        xml.send("net.rptools.maptool.model.Asset") {
          xml.id_ {
            xml.id_ Digest::MD5.hexdigest(@asset_data)
          } # id
          xml.name "test"
          xml.extension "png"
          xml.image
        } # net.rptools.maptool.model.Asset
      end
    end
  end

  class AssetGroup
    attr :assets

    def initialize
      @assets = []
      @assets << Asset.new
    end
  end
end
