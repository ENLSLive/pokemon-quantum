def pbEnterText(helptext,minlength,maxlength,initialText="",mode=0,pokemon=nil,nofadeout=false)
  ret=""
  if $PokemonSystem.input==1 # Classic Input
	pbFadeOutIn(99999,nofadeout){
	   sscene=PokemonEntryScene2.new
	   sscreen=PokemonEntry.new(sscene)
	   ret=sscreen.pbStartScreen(helptext,minlength,maxlength,initialText,mode,pokemon)
	}
  elsif $PokemonSystem.input==nil || $PokemonSystem.input==0 # Keyboard Input
	pbFadeOutIn(99999,nofadeout){
	   sscene=PokemonEntryScene.new
	   sscreen=PokemonEntry.new(sscene)
	   ret=sscreen.pbStartScreen(helptext,minlength,maxlength,initialText,mode,pokemon)
	}
  end
  return ret
end