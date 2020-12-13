#===============================================================================
# Records which file, section and line are currently being read
#===============================================================================
module FileLineData
  @file     = ""
  @linedata = ""
  @lineno   = 0
  @section  = nil
  @key      = nil
  @value    = nil

  def self.file; return @file; end
  def self.file=(value); @file = value; end

  def self.clear
    @file     = ""
    @linedata = ""
    @lineno   = ""
    @section  = nil
    @key      = nil
    @value    = nil
  end

  def self.setSection(section,key,value)
    @section = section
    @key     = key
    if value && value.length>200
      @value = _INTL("{1}...",value[0,200])
    else
      @value = (value) ? value.clone : ""
    end
  end

  def self.setLine(line,lineno)
    @section  = nil
    @linedata = (line && line.length>200) ? sprintf("%s...",line[0,200]) : line.clone
    @lineno   = lineno
  end

  def self.linereport
    if @section
      if @key!=nil
        return _INTL("File {1}, section {2}, key {3}\r\n{4}\r\n\r\n",@file,@section,@key,@value)
      else
        return _INTL("File {1}, section {2}\r\n{3}\r\n\r\n",@file,@section,@value)
      end
    else
      return _INTL("File {1}, line {2}\r\n{3}\r\n\r\n",@file,@lineno,@linedata)
    end
  end
end

#===============================================================================
# Compiler
#===============================================================================
module Compiler
  module_function

  def findIndex(a)
    index = -1
    count = 0
    a.each { |i|
      if yield i
        index = count
        break
      end
      count += 1
    }
    return index
  end

  def prepline(line)
    line.sub!(/\s*\#.*$/,"")
    line.sub!(/^\s+/,"")
    line.sub!(/\s+$/,"")
    return line
  end

  #=============================================================================
  # PBS file readers
  #=============================================================================
  def pbEachFileSectionEx(f)
    lineno      = 1
    havesection = false
    sectionname = nil
    lastsection = {}
    f.each_line { |line|
      if lineno==1 && line[0]==0xEF && line[1]==0xBB && line[2]==0xBF
        line = line[3,line.length-3]
      end
      if !line[/^\#/] && !line[/^\s*$/]
        if line[/^\s*\[\s*(.*)\s*\]\s*$/]   # Of the format: [something]
          yield lastsection,sectionname if havesection
          sectionname = $~[1]
          havesection = true
          lastsection = {}
        else
          if sectionname==nil
            FileLineData.setLine(line,lineno)
            raise _INTL("Expected a section at the beginning of the file. This error may also occur if the file was not saved in UTF-8.\r\n{1}",FileLineData.linereport)
          end
          if !line[/^\s*(\w+)\s*=\s*(.*)$/]
            FileLineData.setSection(sectionname,nil,line)
            raise _INTL("Bad line syntax (expected syntax like XXX=YYY)\r\n{1}",FileLineData.linereport)
          end
          r1 = $~[1]
          r2 = $~[2]
          lastsection[r1] = r2.gsub(/\s+$/,"")
        end
      end
      lineno += 1
      Graphics.update if lineno%500==0
      pbSetWindowText(_INTL("Processing {1} line {2}",FileLineData.file,lineno)) if lineno%50==0
    }
    yield lastsection,sectionname  if havesection
  end

  # Used for pokemon.txt
  def pbEachFileSection(f)
    pbEachFileSectionEx(f) { |section,name|
      yield section,name.to_i if block_given? && name[/^\d+$/]
    }
  end

  # Used for pokemonforms.txt
  def pbEachFileSection2(f)
    pbEachFileSectionEx(f) { |section,name|
      yield section,name if block_given? && name[/^\w+[-,\s]{1}\d+$/]
    }
  end

  # Used for phone.txt
  def pbEachSection(f)
    lineno      = 1
    havesection = false
    sectionname = nil
    lastsection = []
    f.each_line { |line|
      if lineno==1 && line[0]==0xEF && line[1]==0xBB && line[2]==0xBF
        line = line[3,line.length-3]
      end
      if !line[/^\#/] && !line[/^\s*$/]
        if line[/^\s*\[\s*(.+?)\s*\]\s*$/]
          yield lastsection,sectionname  if havesection
          sectionname = $~[1]
          lastsection = []
          havesection = true
        else
          if sectionname==nil
            raise _INTL("Expected a section at the beginning of the file (line {1}). Sections begin with '[name of section]'",lineno)
          end
          lastsection.push(line.gsub(/^\s+/,"").gsub(/\s+$/,""))
        end
      end
      lineno += 1
      Graphics.update if lineno%500==0
    }
    yield lastsection,sectionname  if havesection
  end

  # Unused
  def pbEachCommentedLine(f)
    lineno = 1
    f.each_line { |line|
      if lineno==1 && line[0]==0xEF && line[1]==0xBB && line[2]==0xBF
        line = line[3,line.length-3]
      end
      yield line, lineno if !line[/^\#/] && !line[/^\s*$/]
      lineno += 1
    }
  end

  # Used for many PBS files
  def pbCompilerEachCommentedLine(filename)
    File.open(filename,"rb") { |f|
      FileLineData.file = filename
      lineno = 1
      f.each_line { |line|
        if lineno==1 && line[0]==0xEF && line[1]==0xBB && line[2]==0xBF
          line = line[3,line.length-3]
        end
        if !line[/^\#/] && !line[/^\s*$/]
          FileLineData.setLine(line,lineno)
          yield line, lineno
        end
        lineno += 1
      }
    }
  end

  # Unused
  def pbEachPreppedLine(f)
    lineno = 1
    f.each_line { |line|
      if lineno==1 && line[0]==0xEF && line[1]==0xBB && line[2]==0xBF
        line = line[3,line.length-3]
      end
      line = prepline(line)
      yield line, lineno if !line[/^\#/] && !line[/^\s*$/]
      lineno += 1
    }
  end

  # Used for connections.txt, abilities.txt, moves.txt, trainertypes.txt
  def pbCompilerEachPreppedLine(filename)
    File.open(filename,"rb") { |f|
      FileLineData.file = filename
      lineno = 1
      f.each_line { |line|
        if lineno==1 && line[0]==0xEF && line[1]==0xBB && line[2]==0xBF
          line = line[3,line.length-3]
        end
        line = prepline(line)
        if !line[/^\#/] && !line[/^\s*$/]
          FileLineData.setLine(line,lineno)
          yield line, lineno
        end
        lineno += 1
      }
    }
  end

  #=============================================================================
  # Convert a string to certain kinds of values
  #=============================================================================
  def csvfield!(str)
    ret = ""
    str.sub!(/^\s*/,"")
    if str[0,1]=="\""
      str[0,1] = ""
      escaped = false
      fieldbytes = 0
      str.scan(/./) do |s|
        fieldbytes += s.length
        break if s=="\"" && !escaped
        if s=="\\" && !escaped
          escaped = true
        else
          ret += s
          escaped = false
        end
      end
      str[0,fieldbytes] = ""
      if !str[/^\s*,/] && !str[/^\s*$/]
        raise _INTL("Invalid quoted field (in: {1})\r\n{2}",str,FileLineData.linereport)
      end
      str[0,str.length] = $~.post_match
    else
      if str[/,/]
        str[0,str.length] = $~.post_match
        ret = $~.pre_match
      else
        ret = str.clone
        str[0,str.length] = ""
      end
      ret.gsub!(/\s+$/,"")
    end
    return ret
  end

  def csvBoolean!(str,_line=-1)
    field = csvfield!(str)
    if field[/^1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Yy]$/]
      return true
    elsif field[/^0|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo]|[Nn]$/]
      return false
    end
    raise _INTL("Field {1} is not a Boolean value (true, false, 1, 0)\r\n{2}",field,FileLineData.linereport)
  end

  def csvInt!(str,_line=-1)
    ret = csvfield!(str)
    if !ret[/^\-?\d+$/]
      raise _INTL("Field {1} is not an integer\r\n{2}",ret,FileLineData.linereport)
    end
    return ret.to_i
  end

  def csvPosInt!(str,_line=-1)
    ret = csvfield!(str)
    if !ret[/^\d+$/]
      raise _INTL("Field {1} is not a positive integer\r\n{2}",ret,FileLineData.linereport)
    end
    return ret.to_i
  end

  def csvFloat!(str,_line=-1)
    ret = csvfield!(str)
    return Float(ret) rescue raise _INTL("Field {1} is not a number\r\n{2}",ret,FileLineData.linereport)
  end

  def csvEnumField!(value,enumer,_key,_section)
    ret = csvfield!(value)
    return checkEnumField(ret,enumer)
  end

  def csvEnumFieldOrInt!(value,enumer,_key,_section)
    ret = csvfield!(value)
    return ret.to_i if ret[/\-?\d+/]
    return checkEnumField(ret,enumer)
  end

  def checkEnumField(ret,enumer)
    if enumer.is_a?(Module)
      begin
        if ret=="" || !enumer.const_defined?(ret)
          raise _INTL("Undefined value {1} in {2}\r\n{3}",ret,enumer.name,FileLineData.linereport)
        end
      rescue NameError
        raise _INTL("Incorrect value {1} in {2}\r\n{3}",ret,enumer.name,FileLineData.linereport)
      end
      return enumer.const_get(ret.to_sym)
    elsif enumer.is_a?(Symbol) || enumer.is_a?(String)
      if GameData.const_defined?(enumer.to_sym)
        enumer = GameData.const_get(enumer.to_sym)
        begin
          if ret == "" || !enumer.exists?(ret.to_sym)
            raise _INTL("Undefined value {1} in {2}\r\n{3}", ret, enumer.name, FileLineData.linereport)
          end
        rescue NameError
          raise _INTL("Incorrect value {1} in {2}\r\n{3}", ret, enumer.name, FileLineData.linereport)
        end
        return ret.to_sym
      end
      enumer = Object.const_get(enumer.to_sym)
      begin
        if ret=="" || !enumer.const_defined?(ret)
          raise _INTL("Undefined value {1} in {2}\r\n{3}",ret,enumer.name,FileLineData.linereport)
        end
      rescue NameError
        raise _INTL("Incorrect value {1} in {2}\r\n{3}",ret,enumer.name,FileLineData.linereport)
      end
      return enumer.const_get(ret.to_sym)
    elsif enumer.is_a?(Array)
      idx = findIndex(enumer) { |item| ret==item }
      if idx<0
        raise _INTL("Undefined value {1} (expected one of: {2})\r\n{3}",ret,enumer.inspect,FileLineData.linereport)
      end
      return idx
    elsif enumer.is_a?(Hash)
      value = enumer[ret]
      if value==nil
        raise _INTL("Undefined value {1} (expected one of: {2})\r\n{3}",ret,enumer.keys.inspect,FileLineData.linereport)
      end
      return value
    end
    raise _INTL("Enumeration not defined\r\n{1}",FileLineData.linereport)
  end

  def checkEnumFieldOrNil(ret,enumer)
    if enumer.is_a?(Module)
      return nil if ret=="" || !(enumer.const_defined?(ret) rescue false)
      return enumer.const_get(ret.to_sym)
    elsif enumer.is_a?(Symbol) || enumer.is_a?(String)
      if GameData.const_defined?(enumer.to_sym)
        enumer = GameData.const_get(enumer.to_sym)
        return nil if ret == "" || !enumer.exists?(ret.to_sym)
        return ret.to_sym
      end
      enumer = Object.const_get(enumer.to_sym)
      return nil if ret=="" || !(enumer.const_defined?(ret) rescue false)
      return enumer.const_get(ret.to_sym)
    elsif enumer.is_a?(Array)
      idx = findIndex(enumer) { |item| ret==item }
      return nil if idx<0
      return idx
    elsif enumer.is_a?(Hash)
      return enumer[ret]
    end
    return nil
  end

  #=============================================================================
  # Convert a string to values using a schema
  #=============================================================================
  def pbGetCsvRecord(rec,lineno,schema)
    record = []
    repeat = false
    start = 0
    if schema[1][0,1]=="*"
      repeat = true
      start = 1
    end
    begin
      for i in start...schema[1].length
        chr = schema[1][i,1]
        case chr
        when "i"   # Integer
          record.push(csvInt!(rec,lineno))
        when "I"   # Optional integer
          field = csvfield!(rec)
          if field==""
            record.push(nil)
          elsif !field[/^\-?\d+$/]
            raise _INTL("Field {1} is not an integer\r\n{2}",field,FileLineData.linereport)
          else
            record.push(field.to_i)
          end
        when "u"   # Positive integer or zero
          record.push(csvPosInt!(rec,lineno))
        when "U"   # Optional positive integer or zero
          field = csvfield!(rec)
          if field==""
            record.push(nil)
          elsif !field[/^\d+$/]
            raise _INTL("Field '{1}' must be 0 or greater\r\n{2}",field,FileLineData.linereport)
          else
            record.push(field.to_i)
          end
        when "v"   # Positive integer
          field = csvPosInt!(rec,lineno)
          raise _INTL("Field '{1}' must be greater than 0\r\n{2}",field,FileLineData.linereport) if field==0
          record.push(field)
        when "V"   # Optional positive integer
          field = csvfield!(rec)
          if field==""
            record.push(nil)
          elsif !field[/^\d+$/]
            raise _INTL("Field '{1}' must be greater than 0\r\n{2}",field,FileLineData.linereport)
          elsif field.to_i==0
            raise _INTL("Field '{1}' must be greater than 0\r\n{2}",field,FileLineData.linereport)
          else
            record.push(field.to_i)
          end
        when "x"   # Hexadecimal number
          field = csvfield!(rec)
          if !field[/^[A-Fa-f0-9]+$/]
            raise _INTL("Field '{1}' is not a hexadecimal number\r\n{2}",field,FileLineData.linereport)
          end
          record.push(field.hex)
        when "X"   # Optional hexadecimal number
          field = csvfield!(rec)
          if field==""
            record.push(nil)
          elsif !field[/^[A-Fa-f0-9]+$/]
            raise _INTL("Field '{1}' is not a hexadecimal number\r\n{2}",field,FileLineData.linereport)
          else
            record.push(field.hex)
          end
        when "f"   # Floating point number
          record.push(csvFloat!(rec,lineno))
        when "F"   # Optional floating point number
          field = csvfield!(rec)
          if field==""
            record.push(nil)
          elsif !field[/^\-?^\d*\.?\d*$/]
            raise _INTL("Field {1} is not a floating point number\r\n{2}",field,FileLineData.linereport)
          else
            record.push(field.to_f)
          end
        when "b"   # Boolean
          record.push(csvBoolean!(rec,lineno))
        when "B"   # Optional Boolean
          field = csvfield!(rec)
          if field==""
            record.push(nil)
          elsif field[/^1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Tt]|[Yy]$/]
            record.push(true)
          else
            record.push(false)
          end
        when "n"   # Name
          field = csvfield!(rec)
          if !field[/^(?![0-9])\w+$/]
            raise _INTL("Field '{1}' must contain only letters, digits, and\r\nunderscores and can't begin with a number.\r\n{2}",field,FileLineData.linereport)
          end
          record.push(field)
        when "N"   # Optional name
          field = csvfield!(rec)
          if field==""
            record.push(nil)
          elsif !field[/^(?![0-9])\w+$/]
            raise _INTL("Field '{1}' must contain only letters, digits, and\r\nunderscores and can't begin with a number.\r\n{2}",field,FileLineData.linereport)
          else
            record.push(field)
          end
        when "s"   # String
          record.push(csvfield!(rec))
        when "S"   # Optional string
          field = csvfield!(rec)
          record.push((field=="") ? nil : field)
        when "q"   # Unformatted text
          record.push(rec)
          rec = ""
        when "Q"   # Optional unformatted text
          if !rec || rec==""
            record.push(nil)
          else
            record.push(rec)
            rec = ""
          end
        when "e"   # Enumerable
          record.push(csvEnumField!(rec,schema[2+i-start],"",FileLineData.linereport))
        when "E"   # Optional enumerable
          field = csvfield!(rec)
          record.push(checkEnumFieldOrNil(field,schema[2+i-start]))
        when "y"   # Enumerable or integer
          field = csvfield!(rec)
          record.push(csvEnumFieldOrInt!(field,schema[2+i-start],"",FileLineData.linereport))
        when "Y"   # Optional enumerable or integer
          field = csvfield!(rec)
          if field==""
            record.push(nil)
          elsif field[/^\-?\d+$/]
            record.push(field.to_i)
          else
            record.push(checkEnumFieldOrNil(field,schema[2+i-start]))
          end
        end
      end
      break if repeat && rec==""
    end while repeat
    return (schema[1].length==1) ? record[0] : record
  end

  #=============================================================================
  # Check whether a number fits in a given numerical range (all unused)
  #=============================================================================
  def pbCheckByte(x,valuename)
    if x<0 || x>255
      raise _INTL("The value \"{1}\" must be from 0 through 255 (00-FF in hex), got a value of {2}\r\n{3}",
        valuename,x,FileLineData.linereport)
    end
  end

  def pbCheckSignedByte(x,valuename)
    if x<-128 || x>127
      raise _INTL("The value \"{1}\" must be from -128 through 127, got a value of {2}\r\n{3}",
        valuename,x,FileLineData.linereport)
    end
  end

  def pbCheckWord(x,valuename)
    if x<0 || x>65535
      raise _INTL("The value \"{1}\" must be from 0 through 65535 (0000-FFFF in hex), got a value of {2}\r\n{3}",
        valuename,x,FileLineData.linereport)
    end
  end

  def pbCheckSignedWord(x,valuename)
    if x<-32768 || x>32767
      raise _INTL("The value \"{1}\" must be from -32768 through 32767, got a value of {2}\r\n{3}",
        valuename,x,FileLineData.linereport)
    end
  end

  #=============================================================================
  # Parse string into a likely constant name and return its ID number (if any).
  # Last ditch attempt to figure out whether a constant is defined.
  #=============================================================================
  def pbGetConst(mod,item,err)
    isDef = false
    begin
      mod = Object.const_get(mod) if mod.is_a?(Symbol)
      isDef = mod.const_defined?(item.to_sym)
    rescue
      raise sprintf(err,item)
    end
    raise sprintf(err,item) if !isDef
    return mod.const_get(item.to_sym)
  end

  def parseItem(item)
    clonitem = item.upcase
    clonitem.sub!(/^\s*/, "")
    clonitem.sub!(/\s*$/, "")
    itm = GameData::Item.try_get(clonitem)
    if !itm
      raise _INTL("Undefined item constant name: {1}\r\nName must consist only of letters, numbers and\r\nunderscores, and can't begin with a number.\r\nMake sure the item is defined in\r\nPBS/items.txt.\r\n{2}", item, FileLineData.linereport)
    end
    return itm.id
  end

  def parseSpecies(item)
    clonitem = item.upcase
    clonitem.gsub!(/^[\s\n]*/,"")
    clonitem.gsub!(/[\s\n]*$/,"")
    clonitem = "NIDORANmA" if clonitem=="NIDORANMA"
    clonitem = "NIDORANfE" if clonitem=="NIDORANFE"
    return pbGetConst(PBSpecies,clonitem,_INTL("Undefined species constant name: [%s]\r\nName must consist only of letters, numbers, and\r\nunderscores and can't begin with a number.\r\nMake sure the name is defined in\r\nPBS/pokemon.txt.\r\n{1}",FileLineData.linereport))
  end

  def parseMove(move, skip_unknown = false)
    clonmove = move.upcase
    clonmove.sub!(/^\s*/, "")
    clonmove.sub!(/\s*$/, "")
    mov = GameData::Move.try_get(clonmove)
    if !mov
      return nil if skip_unknown
      raise _INTL("Undefined move constant name: {1}\r\nName must consist only of letters, numbers and\r\nunderscores, and can't begin with a number.\r\nMake sure the move is defined in\r\nPBS/moves.txt.\r\n{2}", move, FileLineData.linereport)
    end
    return mov.id
  end

  # Unused
  def parseNature(item)
    clonitem = item.upcase
    clonitem.sub!(/^\s*/,"")
    clonitem.sub!(/\s*$/,"")
    return pbGetConst(PBNatures,clonitem,_INTL("Undefined nature constant name: %s\r\nName must consist only of letters, numbers, and\r\nunderscores and can't begin with a number.\r\nMake sure the name is defined in\r\nthe script section PBNatures.\r\n{1}",FileLineData.linereport))
  end

  # Unused
  def parseTrainer(type)
    clontype = type.clone
    clontype.sub!(/^\s*/, "")
    clontype.sub!(/\s*$/, "")
    typ = GameData::TrainerType.try_get(clontype)
    if !typ
      raise _INTL("Undefined Trainer type constant name: {1}\r\nName must consist only of letters, numbers and\r\nunderscores, and can't begin with a number.\r\nMake sure the trainer type is defined in\r\ntrainertypes.txt.\r\n{2}", type, FileLineData.linereport)
    end
    return typ.id
  end

  #=============================================================================
  # Compile all data
  #=============================================================================
  def compile_all(mustCompile)
    FileLineData.clear
    if (!$INEDITOR || LANGUAGES.length < 2) && safeExists?("Data/messages.dat")
      MessageTypes.loadMessageFile("Data/messages.dat")
    end
    if mustCompile
      yield(_INTL("Compiling type data"))
      compile_types                  # No dependencies
      yield(_INTL("Compiling town map data"))
      compile_town_map               # No dependencies
      yield(_INTL("Compiling map connection data"))
      compile_connections            # No dependencies
      yield(_INTL("Compiling ability data"))
      compile_abilities              # No dependencies
      yield(_INTL("Compiling move data"))
      compile_moves                  # Depends on Type
      yield(_INTL("Compiling item data"))
      compile_items                  # Depends on Move
      yield(_INTL("Compiling berry plant data"))
      compile_berry_plants           # Depends on Item
      yield(_INTL("Compiling Pokémon data"))
      compile_pokemon                # Depends on Move, Item, Type, Ability
      yield(_INTL("Compiling Pokémon forms data"))
      compile_pokemon_forms          # Depends on PBSpecies, Move, Item, Type, Ability
      yield(_INTL("Compiling machine data"))
      compile_move_compatibilities   # Depends on PBSpecies, Move
      yield(_INTL("Compiling Trainer type data"))
      compile_trainer_types          # No dependencies
      yield(_INTL("Compiling Trainer data"))
      compile_trainers               # Depends on PBSpecies, Item, Move
      yield(_INTL("Compiling phone data"))
      compile_phone
      yield(_INTL("Compiling metadata"))
      compile_metadata               # Depends on TrainerType
      yield(_INTL("Compiling battle Trainer data"))
      compile_trainer_lists          # Depends on TrainerType
      yield(_INTL("Compiling encounter data"))
      compile_encounters             # Depends on PBSpecies
      yield(_INTL("Compiling shadow moveset data"))
      compile_shadow_movesets        # Depends on PBSpecies, Move
      yield(_INTL("Compiling animations"))
      compile_animations
      yield(_INTL("Converting events"))
      compile_trainer_events(mustCompile)
      yield(_INTL("Saving messages"))
      pbSetTextMessages
      MessageTypes.saveMessages
    end
    pbSetWindowText(nil)
  end

  def main
    return if !$DEBUG
    begin
      dataFiles = [
         "berry_plants.dat",
         "encounters.dat",
         "form2species.dat",
         "items.dat",
         "map_connections.dat",
         "metadata.dat",
         "moves.dat",
         "phone.dat",
         "regional_dexes.dat",
         "shadow_movesets.dat",
         "species.dat",
         "species_eggmoves.dat",
         "species_evolutions.dat",
         "species_metrics.dat",
         "species_movesets.dat",
         "tm.dat",
         "town_map.dat",
         "trainer_lists.dat",
         "trainer_types.dat",
         "trainers.dat",
         "types.dat",
         "Constants.rxdata"
      ]
      textFiles = [
         "abilities.txt",
         "berryplants.txt",
         "connections.txt",
         "encounters.txt",
         "items.txt",
         "metadata.txt",
         "moves.txt",
         "phone.txt",
         "pokemon.txt",
         "pokemonforms.txt",
         "shadowmoves.txt",
         "tm.txt",
         "townmap.txt",
         "trainerlists.txt",
         "trainers.txt",
         "trainertypes.txt",
         "types.txt"
      ]
      latestDataTime = 0
      latestTextTime = 0
      mustCompile = false
      # Should recompile if new maps were imported
      mustCompile |= import_new_maps
      # If no PBS file, create one and fill it, then recompile
      if !safeIsDirectory?("PBS")
        Dir.mkdir("PBS") rescue nil
        pbSaveAllData
        mustCompile = true
      end
      # Should recompile if holding Ctrl
      Input.update
      mustCompile = true if Input.press?(Input::CTRL)
      # Delete old data files in preparation for recompiling
      if mustCompile
        for i in 0...dataFiles.length
          begin
            File.delete("Data/#{dataFiles[i]}")
          rescue SystemCallError
          end
        end
      end
      # Recompile all data
      compile_all(mustCompile) { |msg| pbSetWindowText(msg) }
    rescue Exception
      e = $!
      raise e if "#{e.class}"=="Reset" || e.is_a?(Reset) || e.is_a?(SystemExit)
      pbPrintException(e)
      for i in 0...dataFiles.length
        begin
          File.delete("Data/#{dataFiles[i]}")
        rescue SystemCallError
        end
      end
      raise Reset.new if e.is_a?(Hangup)
      loop do
        Graphics.update
      end
    end
  end
end
