#==============================================================================#
#                                    HM Items                                  #
#                                    by Marin                                  #
#==============================================================================#
#                       No coding knowledge required at all.                   #
#                                                                              #
#  Because the items override the actual moves' functionality, the items have  #
#      switches to toggle them, as you see below (USING_SURF_ITEM, etc.)       #
#   If they're set to true, the items will be active and will override some    #
#                 in-field functionality of the moves themselves.              #
#==============================================================================#
#      Rock Smash, Strength and Cut all use the default Essentials events.     #
#==============================================================================#
#                    Please give credit when using this.                       #
#==============================================================================#

# Future updates may contain: Flash, Headbutt, Sweet Scent, Rock Climb.

COMMONEVENT = 6

BLOCKERNAMES = ["Tree", "Boulder", "Rock", "Blocker"]

# The internal name of the item that will trigger Surf
SURF_ITEM = :SURFITEM

# The internal name of the item that will trigger Rock Smash
ROCK_SMASH_ITEM = :ROCKSMASHITEM

# The internal name of the item that will trigger Fly
FLY_ITEM =  :FLYITEM

# The internal name of the item that will trigger Strength
STRENGTH_ITEM = :STRENGTHITEM

# The internal name of the item that will trigger Cut
CUT_ITEM = :CUTITEM

# The internal name of the item that will trigger Teleport
TELEPORT_ITEM = :TELEPORTDEVICEW

# The switch needed to be able to teleport
TELEPORTSWITCH = 100



# When true, this overrides the old surfing mechanics.
USING_SURF_ITEM = true

# When true, this overrides the old rock smash mechanics.
USING_ROCK_SMASH_ITEM = true

# When true, this overrides the old fly mechanics.
USING_FLY_ITEM = true

# When true, this overrides the old strength mechanics.
USING_STRENGTH_ITEM = true

# When true, this overrides the old cut mechanics.
USING_CUT_ITEM = true

# When true, this overrides the old teleport mechanics.
USING_TELEPORT = true


#==============================================================================#
# This section of code contains minor utility methods.                         #
#==============================================================================#

class Game_Map
  attr_reader :map
end

class Game_Player
  attr_writer :x
  attr_writer :y
end

class HandlerHash
  def delete(sym)
    id = fromSymbol(sym)
    @hash.delete(id) if id && @hash[id]
    symbol = toSymbol(sym)
    @hash.delete(symbol) if symbol && @hash[symbol]
  end
end

def pbSmashEvent(event)
  return unless event
  if event.name == "Tree"
    pbSEPlay("Cut", 80)
  elsif event.name == "Rock"
    pbSEPlay("Rock Smash", 80)
  end
  pbMoveRoute(event,[
     PBMoveRoute::TurnDown,
     PBMoveRoute::Wait, 2,
     PBMoveRoute::TurnLeft,
     PBMoveRoute::Wait, 2,
     PBMoveRoute::TurnRight,
     PBMoveRoute::Wait, 2,
     PBMoveRoute::TurnUp,
     PBMoveRoute::Wait, 2
  ])
  pbWait(16)
  event.erase
  $PokemonMap.addErasedEvent(event.id) if $PokemonMap
end


#==============================================================================#
# This section of the code handles the item that calls Surf.                   #
#==============================================================================#

if USING_SURF_ITEM
  HiddenMoveHandlers::CanUseMove.delete(:SURF)
  HiddenMoveHandlers::UseMove.delete(:SURF)

  def Kernel.pbSurf
    return false if $game_player.pbHasDependentEvents?
    move = getID(PBMoves,:SURF)
    if !pbCheckHiddenMoveBadge(BADGEFORSURF,false) && !$DEBUG
      return false
    end
    if Kernel.pbConfirmMessage(_INTL("The water is a deep blue...\nWould you like to surf on it?"))
      Kernel.pbMessage(_INTL("{1} used the {2}!", $Trainer.name, PBItems.getName(getConst(PBItems,SURF_ITEM))))
      Kernel.pbCancelVehicles
      surfbgm = pbGetMetadata(0,MetadataSurfBGM)
      pbCueBGM(surfbgm,0.5) if surfbgm
      pbStartSurfing
      return true
    end
    return false
  end

  ItemHandlers::UseInField.add(SURF_ITEM, proc do |item|
    $game_temp.in_menu = false
    Kernel.pbSurf
    return true
  end)

  ItemHandlers::UseFromBag.add(SURF_ITEM, proc do |item|
    return false if $PokemonGlobal.surfing ||
                    pbGetMetadata($game_map.map_id,MetadataBicycleAlways) ||
                    !PBTerrain.isSurfable?(Kernel.pbFacingTerrainTag) ||
                    !$game_map.passable?($game_player.x,$game_player.y,$game_player.direction,$game_player)
    return 2
  end)
end


#==============================================================================#
# This section of the code handles the item that calls Fly.                    #
#==============================================================================#

if USING_FLY_ITEM
  ItemHandlers::UseFromBag.add(FLY_ITEM, proc do |item|
    return false unless pbGetMetadata($game_map.map_id,MetadataOutdoor)
    if defined?(BetterRegionMap)
      ret = pbBetterRegionMap(nil, true, true)
    else
      ret = pbFadeOutIn(99999) do
        scene = PokemonRegionMap_Scene.new(-1, false)
        screen = PokemonRegionMapScreen.new(scene)
        next screen.pbStartFlyScreen
      end
    end
    if ret
      $PokemonTemp.flydata = ret
      return 2
    end
    return 0
  end)

  ItemHandlers::UseInField.add(FLY_ITEM, proc do |item|
    $game_temp.in_menu = false
    return false if !$PokemonTemp.flydata
    Kernel.pbMessage(_INTL("{1} used the {2}!", $Trainer.name,PBItems.getName(getConst(PBItems,FLY_ITEM))))
    pbFadeOutIn(99999) do
       $game_temp.player_new_map_id    = $PokemonTemp.flydata[0]
       $game_temp.player_new_x         = $PokemonTemp.flydata[1]
       $game_temp.player_new_y         = $PokemonTemp.flydata[2]
       $game_temp.player_new_direction = 2
       Kernel.pbCancelVehicles
       $PokemonTemp.flydata = nil
       $scene.transfer_player
       $game_map.autoplay
       $game_map.refresh
    end
    pbEraseEscapePoint
    return true
  end)
end


#==============================================================================#
# This section of the code handles the item that calls Rock Smash.             #
#==============================================================================#

if USING_ROCK_SMASH_ITEM
  HiddenMoveHandlers::CanUseMove.delete(:ROCKSMASH)
  HiddenMoveHandlers::UseMove.delete(:ROCKSMASH)

  ItemHandlers::UseFromBag.add(ROCK_SMASH_ITEM, proc do |item|
    if $game_player.pbFacingEvent && $game_player.pbFacingEvent.name == "Rock"
      return 2
    end
    return false
  end)

  ItemHandlers::UseInField.add(ROCK_SMASH_ITEM, proc do |item|
    $game_player.pbFacingEvent.start
    return true
  end)

  def Kernel.pbRockSmash
    if !pbCheckHiddenMoveBadge(BADGEFORROCKSMASH,false)
      Kernel.pbMessage(_INTL("It's a rugged rock, but an item may be able to smash it."))
      return false
    end
    item = PBItems.getName(getConst(PBItems,ROCK_SMASH_ITEM))
    if Kernel.pbConfirmMessage(_INTL("This rock appears to be breakable. Would you like to use the {1}?", item))
      Kernel.pbMessage(_INTL("{1} used the {2}!",$Trainer.name, item))
      return true
    end
    return false
  end
end


#==============================================================================#
# This section of code handles the item that calls Strength.                   #
#==============================================================================#

if USING_STRENGTH_ITEM
  HiddenMoveHandlers::CanUseMove.delete(:STRENGTH)
  HiddenMoveHandlers::UseMove.delete(:STRENGTH)

  def Kernel.pbStrength
    if $PokemonMap.strengthUsed
      Kernel.pbMessage(_INTL("Strength made it possible to move boulders around."))
      return false
    end
    if !pbCheckHiddenMoveBadge(BADGEFORSTRENGTH,false) && !$DEBUG
      Kernel.pbMessage(_INTL("It's a big boulder, but an item may be able to push it aside."))
      return false
    end
    itemname = PBItems.getName(getConst(PBItems,STRENGTH_ITEM))
    Kernel.pbMessage(_INTL("It's a big boulder, but an item may be able to push it aside.\1"))
    if Kernel.pbConfirmMessage(_INTL("Would you like to use the {1}?", itemname))
      Kernel.pbMessage(_INTL("{1} used the {2}!",
          $Trainer.name, itemname))
      Kernel.pbMessage(_INTL("The {1} made it possible to move boulders around!",itemname))
      $PokemonMap.strengthUsed = true
      return true
    end
    return false
  end

  ItemHandlers::UseFromBag.add(STRENGTH_ITEM, proc do
    if $game_player.pbFacingEvent && $game_player.pbFacingEvent.name == "Boulder"
      return 2
    end
    return false
  end)

  ItemHandlers::UseInField.add(STRENGTH_ITEM, proc { Kernel.pbStrength })
end


#==============================================================================#
# This section of code handles the item that calls Cut.                        #
#==============================================================================#

if USING_CUT_ITEM
  HiddenMoveHandlers::CanUseMove.delete(:CUT)
  HiddenMoveHandlers::UseMove.delete(:CUT)

  def Kernel.pbCut
    if !pbCheckHiddenMoveBadge(BADGEFORCUT,false) && !$DEBUG
      Kernel.pbMessage(_INTL("This tree looks like it can be cut down."))
      return false
    end
    Kernel.pbMessage(_INTL("This tree looks like it can be cut down!\1"))
    if Kernel.pbConfirmMessage(_INTL("Would you like to cut it?"))
      itemname = PBItems.getName(getConst(PBItems,CUT_ITEM))
      Kernel.pbMessage(_INTL("{1} used the {2}!",$Trainer.name,itemname))
      pbSmashEvent($game_player.pbFacingEvent)
      return true
    end
    return false
  end

  ItemHandlers::UseFromBag.add(CUT_ITEM, proc do
    if $game_player.pbFacingEvent && $game_player.pbFacingEvent.name == "Tree"
      return 2
    end
    return false
  end)

  ItemHandlers::UseInField.add(CUT_ITEM, proc { $game_player.pbFacingEvent.start })
end




#==============================================================================#
# This section of code handles the item that calls Teleport.                   #
#==============================================================================#

if USING_TELEPORT

  def Kernel.pbTeleport
    value = 1
    i = 0
    newX = $game_player.x
    newY = $game_player.y
    isOnEvent = false
    params = ChooseNumberParams.new
    params.setRange(0,8)
    params.setDefaultValue(value)
    if $game_switches[TELEPORTSWITCH] == false
      pbTeleportDisabled
      return false
    end
    #if pbConfirmMessage(_INTL("Would you like to use Manual Mode?"))
      value = pbMessageChooseNumber(_INTL("How far would you like to go?"),params)
      if value!=0
        case $game_player.direction
          when 2; newY = $game_player.y+value   # Down
          when 4; newX = $game_player.x-value # Left
          when 6; newX = $game_player.x+value # Right
          when 8; newY = $game_player.y-value   # Up
        end
        for e in $game_map.events.values
          if e.x == newX && e.y == newY
            isOnEvent = true
          end
          for i in 0..value
            case $game_player.direction
            when 2
              if e.y == $game_player.y+i
                if BLOCKERNAMES.include? e.name
                  if e.erased == false
                    Kernel.pbTeleportFail
                    return false
                  end
                end
              end
            when 4
              if e.x == $game_player.x-i
                if BLOCKERNAMES.include? e.name
                  if e.erased == false
                    Kernel.pbTeleportFail
                    return false
                  end
                end
              end
            when 6
              if e.x == $game_player.x+i
                if BLOCKERNAMES.include? e.name
                  if e.erased == false
                    Kernel.pbTeleportFail
                    return false
                  end
                end
              end
            when 8
              if e.y == $game_player.y-i
                if BLOCKERNAMES.include? e.name
                  if e.erased == false
                    Kernel.pbTeleportFail
                    return false
                  end
                end
              end
            end
          end
        end
        if $game_map.passable?(newX,newY,$game_player.direction,$game_player) && !isOnEvent
          $game_temp.player_transferring = true
          $game_temp.transition_processing = false
          $game_temp.player_new_map_id = $game_map.map_id
          $game_temp.player_new_x = newX
          $game_temp.player_new_y = newY
          $game_temp.player_new_direction = $game_player.direction
          pbCommonEvent(COMMONEVENT)
          pbUpdateSceneMap
        else
          Kernel.pbTeleportFail
          return false
        end
        return true
      end
      return false
    #end
  end

  def Kernel.pbTeleportFail
    Kernel.pbMessage(_INTL("The area seems to be blocked.\1"))
  end

  def pbTeleportDisabled
    Kernel.pbMessage(_INTL("It seems you can't teleport right now.\1"))
  end

  ItemHandlers::UseFromBag.add(TELEPORT_ITEM, proc do
    if $game_switches[TELEPORTSWITCH] == true
      return 2
    end
    return false
  end)

  ItemHandlers::UseInField.add(TELEPORT_ITEM, proc { Kernel.pbTeleport })
end
