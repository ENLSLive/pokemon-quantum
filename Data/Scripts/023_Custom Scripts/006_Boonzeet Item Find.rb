#-------------------------------------------------------------------------------
# Item Find
# v1.2.1
# By Boonzeet
#-------------------------------------------------------------------------------
# A script to show a helpful message with item name, icon and description
# when an item is found for the first time.
#-------------------------------------------------------------------------------

PluginManager.register({
  :name => "Item Find",
  :version => "1.2.1",
  :credits => "Boonzeet",
  :link => "https://reliccastle.com/resources/371/"
})

#-------------------------------------------------------------------------------
# Config
#-------------------------------------------------------------------------------

WINDOWSKIN_NAME = "" # set for custom windowskin

#-------------------------------------------------------------------------------
# Base Class
#-------------------------------------------------------------------------------

class PokemonItemFind_Scene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    skin = WINDOWSKIN_NAME == "" ? MessageConfig.pbGetSystemFrame : "Graphics/Windowskins/" + WINDOWSKIN_NAME
   
    @sprites["background"] = Window_UnformattedTextPokemon.newWithSize("", 0, 0, Graphics.width, 0, @viewport)
    @sprites["background"].z = @viewport.z - 1
    @sprites["background"].visible = false
    @sprites["background"].setSkin(skin)
   
    colors = getDefaultTextColors(@sprites["background"].windowskin)
   
    @sprites["itemicon"] = ItemIconSprite.new(42, Graphics.height - 48, -1, @viewport)
    @sprites["itemicon"].visible = false
    @sprites["itemicon"].z = @viewport.z + 2

    @sprites["descwindow"] = Window_UnformattedTextPokemon.newWithSize("", 64, 0, Graphics.width - 64, 64, @viewport)
    @sprites["descwindow"].windowskin = nil
    @sprites["descwindow"].z = @viewport.z
    @sprites["descwindow"].visible = false
    @sprites["descwindow"].baseColor = colors[0]
    @sprites["descwindow"].shadowColor = colors[1]

    @sprites["titlewindow"] = Window_UnformattedTextPokemon.newWithSize("", 0, 0, 128, 16, @viewport)
    @sprites["titlewindow"].visible = false
    @sprites["titlewindow"].z = @viewport.z + 1
    @sprites["titlewindow"].setSkin(skin)
  end

  def pbShow(item)
    name = PBItems.getName(item)
    description = pbGetMessage(MessageTypes::ItemDescriptions, item)

    descwindow = @sprites["descwindow"]
    descwindow.resizeToFit(description, Graphics.width - 64)
    descwindow.text = description
    descwindow.y = Graphics.height - descwindow.height
    descwindow.visible = true
   
    background = @sprites["background"]
    background.height = descwindow.height + 16
    background.y = Graphics.height - background.height
    background.visible = true

    titlewindow = @sprites["titlewindow"]
    titlewindow.resizeToFit(name, Graphics.height)
    titlewindow.text = name
    titlewindow.y = Graphics.height - descwindow.height - 48
    titlewindow.visible = true

    itemicon = @sprites["itemicon"]
    itemicon.item = item
    itemicon.y = Graphics.height - (descwindow.height / 2).floor
    itemicon.visible = true

    loop do
      background.update
      itemicon.update
      descwindow.update
      titlewindow.update
      Graphics.update
      Input.update
      pbUpdateSceneMap
      if Input.trigger?(Input::B) || Input.trigger?(Input::C)
        pbEndScene
        break
      end
    end
  end

  def pbEndScene
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#-------------------------------------------------------------------------------
# Game Player changes
#-------------------------------------------------------------------------------
# Adds a list of found items to the Game Player which is maintained over saves
#-------------------------------------------------------------------------------

class Game_Player
  alias initialize_itemfind initialize
  def initialize(*args)
    @found_items = []
    initialize_itemfind(*args)
  end

  def addFoundItem(item)
    if !defined?(@found_items)
      @found_items = []
    end
    if !@found_items.include?(item)
      @found_items.push(item)
      scene = PokemonItemFind_Scene.new
      scene.pbStartScene
      scene.pbShow(item)
    end
  end
end

#-------------------------------------------------------------------------------
# Overrides of pbItemBall and pbReceiveItem
#-------------------------------------------------------------------------------
# Picking up an item found on the ground
#-------------------------------------------------------------------------------

def pbItemBall(item, quantity = 1)
  item = getID(PBItems,item)
  return false if !item || item<=0 || quantity<1
  itemname = (quantity>1) ? PBItems.getNamePlural(item) : PBItems.getName(item)
  pocket = pbGetPocket(item)
  meName = (pbIsKeyItem?(item)) ? "Key item get" : "Item get"
  if isConst?(item, PBItems, :LEFTOVERS)
    pbMessage(_INTL("\\me[{1}]You found some \\c[1]{2}\\c[0]!\\wtnp[30]", meName, itemname))
  elsif pbIsMachine?(item) # TM or HM
    pbMessage(_INTL("\\me[{1}]You found \\c[1]{2} {3}\\c[0]!\\wtnp[30]", meName, itemname, PBMoves.getName(pbGetMachine(item))))
  elsif quantity > 1
    pbMessage(_INTL("\\me[{1}]You found {2} \\c[1]{3}\\c[0]!\\wtnp[30]", meName, quantity, itemname))
  elsif ["a", "e", "i", "o", "u"].include?(itemname[0, 1].downcase)
    pbMessage(_INTL("\\me[{1}]You found an \\c[1]{2}\\c[0]!\\wtnp[30]", meName, itemname))
  else
    pbMessage(_INTL("\\me[{1}]You found a \\c[1]{2}\\c[0]!\\wtnp[30]", meName, itemname))
  end
  if $PokemonBag.pbStoreItem(item, quantity) # If item can be picked up
    $game_player.addFoundItem(item)
    return true
  else
    pbMessage(_INTL("But your Bag is full..."))
    return false
  end
end

#-------------------------------------------------------------------------------
# Being given an item
#-------------------------------------------------------------------------------
def pbReceiveItem(item, quantity = 1)
  item = getID(PBItems,item)
  return false if !item || item<=0 || quantity<1
  itemname = (quantity>1) ? PBItems.getNamePlural(item) : PBItems.getName(item)
  pocket = pbGetPocket(item)
  meName = (pbIsKeyItem?(item)) ? "Key item get" : "Item get"
  if isConst?(item, PBItems, :LEFTOVERS)
    pbMessage(_INTL("\\me[{1}]You obtained some \\c[1]{2}\\c[0]!\\wtnp[30]", meName, itemname))
  elsif pbIsMachine?(item) # TM or HM
    pbMessage(_INTL("\\me[{1}]You obtained \\c[1]{2} {3}\\c[0]!\\wtnp[30]", meName, itemname, PBMoves.getName(pbGetMachine(item))))
  elsif quantity > 1
    pbMessage(_INTL("\\me[{1}]You obtained {2} \\c[1]{3}\\c[0]!\\wtnp[30]", meName, quantity, itemname))
  elsif ["a", "e", "i", "o", "u"].include?(itemname[0, 1].downcase)
    pbMessage(_INTL("\\me[{1}]You obtained an \\c[1]{2}\\c[0]!\\wtnp[30]", meName, itemname))
  else
    pbMessage(_INTL("\\me[{1}]You obtained a \\c[1]{2}\\c[0]!\\wtnp[30]", meName, itemname))
  end
  if $PokemonBag.pbStoreItem(item, quantity) # If item can be added
    $game_player.addFoundItem(item)
    return true
  end
  return false   # Can't add the item
end