﻿script "revInspector"
constant kPropertyInspectorPrefix = "revPropertyInspector"
on preOpenStack
   inspectorMessagesRegister
end preOpenStack

on inspectorMessagesRegister
   revIDESubscribe "ideSelectedObjectChanged"
   revIDESubscribe "ideResumeStack"
   revIDESubscribe "ideNewStack"
   revIDESubscribe "ideInspectObjects"
   revIDESubscribe "ideCloseStack"
   revIDESubscribe "ideNameChanged"
end inspectorMessagesRegister

on inspectorMessagesDeRegister
   revIDEUnsubscribe "ideSelectedObjectChanged"
   revIDEUnsubscribe "ideResumeStack"
   revIDEUnsubscribe "ideInspectObjects"
   revIDEUnsubscribe "ideNewStack"
   revIDEUnsubscribe "ideCloseStack"
   revIDEUnsubscribe "ideNameChanged"
end inspectorMessagesDeRegister 

on inspectorCloseAll
   ## Unsubscribe from all messges
   inspectorMessagesDeRegister
   revIDEStopInspecting
end inspectorCloseAll

#####################
#### PI FUNCTIONS #####
#####################

on inspectorTreeMenuDisplay
   local tObjects, tStack, tDefaultStack, tControls, tNumControls, tCheck
   local tControlsArray, tList, tControlsList, tCards, tNumCards, tOpenStacks, tStacks, tProfiles1
   local tCurrentProfile, tProfiles2, tHandlers, tSendMessageList, tLockInspector, tFocusedObject
   
   global gREVShowStacks

   put the cSelectedObjects of me into tObjects
   revSetGeometryObject tObjects
   put revTargetStack(line 1 of tObjects) into tStack
   put the defaultStack into tDefaultStack
   
   # Create the button that we're going to popup on this stack
   set the defaultstack to me
   lock messages
   if there is a button "inspectMenu" of me then delete button "inspectMenu" of me
   create button "inspectMenu"
   set the style of button "inspectMenu" of me to "menu"
   set the menumode of button "inspectMenu" of me to "popup"
   set the visible of button "inspectMenu" of me to false
   set the script of button "inspectMenu" of me to "on menuPick pItem;send" && quote & "menuPick pItem" & quote && "to this stack; end menuPick"
   unlock messages
   
   # Generate the inspect 
   set the defaultStack to tStack
   put "Inspect" & cr into tControls
   put the num of controls into tNumControls
   if tNumControls > 1000 then 
      put tab & "(Too many controls to display" && "[" & tNumControls & "]" after tControls
   else
      repeat with i = 1 to tNumControls
         if the long id control i is among the lines of tObjects 
         then put "!c" into tCheck
         else put "!n" into tCheck
         put tCheck & tab & menuitemEscape(the name of control i, false) && "[" & i & "]" & cr after tControls
      end repeat
      delete last char of tControls
      set the itemDel to tab
      sort lines of tControls numeric by item 2 of each
      
      if the number of lines in tControls > 20 then
         repeat for each line l in tControls -- sort into individual object types
            put tab & tab & l & cr after tControlsArray[word 2 of l]
         end repeat
         put keys(tControlsArray) into tList
         sort lines of tList
         repeat for each line l in tList
            delete last char of tControlsArray[l] -- trailing return in each element
            put tab & l & "s" & cr & tControlsArray[l] & cr after tControlsList
         end repeat
         delete char 1 to 5 of tControlsList
      end if
   end if
   
   put empty into tCards
   put the num of cards in this stack into tNumCards
   repeat with i = 1 to tNumCards
      if the long id of cd i is among the lines of tObjects
      then put "!c" into tCheck
      else put "!n" into tCheck
      put tCheck & tab & tab & menuitemEscape(the short name of card i, false) && "[" & i & "]" & cr after tCards
   end repeat
   delete last char of tCards
   sort lines of tCards by item 2 of each
   
   put tab & "Card" & cr before tCards
   
   set the defaultStack to tDefaultStack
   
   if gREVShowStacks then put the openStacks into tOpenStacks
   else put revFilterStacksList(the openStacks) into tOpenStacks
   put empty into tStacks
   repeat for each line l in tOpenStacks
      if the long id of stack l is among the lines of tObjects
      then put "!c" into tCheck
      else put "!n" into tCheck
      put tCheck & tab & tab & menuitemEscape(l, false) & cr after tStacks
   end repeat
   delete last char of tStacks
   sort lines of tStacks by item 2 of each
   if tStacks is empty then put "(" & tab & "Stack" into tStacks
   else put tab & "Stack" & cr before tStacks
   
   if the num of lines in tObjects = 1 then
      put the cREVGeneral["handlerList"] of tObjects into tHandlers
      if the cSort of stack "revPreferences" then sort lines of tHandlers
      if the num of words in line 1 of tHandlers is 0 then
         put "(Send Message" into tSendMessageList
      else
         put "Send Message" & cr into tSendMessageList
         repeat for each line l in tHandlers
            put tab & l & cr after tSendMessageList
         end repeat
         delete last char of tSendMessageList
      end if
   else put "(Send Message" into tSendMessageList
   
   if the cLocked of me is true then
      put "!cLock Inspector" into tLockInspector
   else 
      put "!nLock Inspector" into tLockInspector
   end if
   
   if the number of lines in tControls > 20 then 
      replace cr with cr & tab & tab in tCards
      replace cr with cr & tab & tab in tStacks
      set the text of button "inspectMenu" of this stack to tControlsList & tab & "-" & cr & tCards \
            & cr & tab & "-" & cr & tStacks & cr & "-" \
            & cr & "-" & cr & "Edit Script" & cr & tSendMessageList
   else
      set the text of button "inspectMenu" of this stack to tControls & cr & tab & "-" & cr & tCards \
            & cr & tab & "-" & cr & tStacks & cr & "-" \
            & cr & "-" & cr & "Edit Script" & cr & tSendMessageList
   end if
   
   popup button "inspectMenu" of this stack at the mouseloc
end inspectorTreeMenuDisplay

on menuPick pWhich
   local tFocusedObject, tObjects, tStack
   put the long id of the focusedObject into tFocusedObject
   if word 1 of tFocusedObject is "field" \
         and revIDEStackOfObject(tFocusedObject) is the short name of this stack
   then send "closeField" to tFocusedObject
   
   put the cSelectedObjects of me into tObjects
   put revIDEStackOfObject(line 1 of tObjects) into tStack
   set the itemDel to "|"
   switch item 1 of pWhich
      case "Inspect"
         switch item 2 of pWhich
            case "Card"
               local tNum
               put char 2 to -2 of word -1 of item -1 of pWhich into tNum
               try
                  if the mode of stack tStack is 0 \
                        or the num of this cd of stack tStack is not tNum
                  then go cd tNum of stack tStack
                  revIDEInspectObjects the long id of cd tNum of stack tStack
               catch tError
                  answer error "There was an error selecting" && the name of cd tNum of stack tStack
               end try
               break
            case "Stack"
               local tNewStack
               put word 1 to -1 of item -1 of pWhich into tNewStack
               try
                  revIDEInspectObjects the long id of stack tNewStack
               catch tError
                  answer error "There was an error selecting stack" && tNewStack
               end try
               break
            default
               put char 2 to -2 of word -1 of item -1 of pWhich into tNum
               try
                  if the mode of stack tStack is 0
                  then go stack tStack        
                  revIDEInspectObjects the long id of control tNum of this cd of stack tStack
               catch tError
                  answer error "There was an error selecting" \
                        && the name of control tNum of this cd of stack tStack
               end try
               break
         end switch
         break
      case "Send Message"
         revIDESendMessageToObject item 2 of pWhich, tObjects
         break
      case "Edit Script"
         revIDEEditScriptOfObjects tObjects 
         break
   end switch
end menuPick

private function menuitemEscape pItem, pFirst
   -- MW-2011-04-08: [[ Bug 9496 ]] Make sure we escape '!!' properly.
   replace "!" with "!!" in pItem
   replace "&" with "&&" in pItem
   replace "(" with "((" in pItem
   return pItem
end menuitemEscape

local sInspectorsA, sInspectorMax
private function inspectorList
   return sInspectorsA
end inspectorList

private on addInspectorToList pInspectorNumber
   put pInspectorNumber into sInspectorsA[pInspectorNumber]
   put max(pInspectorNumber, sInspectorMax) into sInspectorMax
end addInspectorToList

private on removeInspectorFromList pInspectorNumber
   delete variable sInspectorsA[pInspectorNumber]
   if pInspectorNumber is sInspectorMax then
      put max(sInspectorsA) into sInspectorMax
   end if
end removeInspectorFromList

private on deleteInspector pInspectorNumber
   delete stack (kPropertyInspectorPrefix && pInspectorNumber)
   removeInspectorFromList pInspectorNumber
end deleteInspector

local sInspectedObjectsA
on ideInspectObjects pObjects
   # Get the selected objects
   local tSelectedObjects
   if pObjects is not empty then
      put pObjects into tSelectedObjects
   else
      put revIDESelectedObjects() into tSelectedObjects
   end if
   
   local tStackName, tIndex, tTargetInspector, tKeys
   put the keys of inspectorList() into tKeys
   sort tKeys ascending numeric
   repeat for each line tKey in tKeys
      put kPropertyInspectorPrefix && tKey into tStackName
      if the cLocked of stack tStackName is true then next repeat
      
      if tTargetInspector is empty then
         put tStackName into tTargetInspector
         put tKey into tIndex
      else
         # Delete any unlocked inspectors other than the target
         deleteInspector tKey
      end if
   end repeat
   
   lock screen 
   lock messages
   # If all the inspectors are locked, or there aren't any, create a new one.
   if tTargetInspector is empty then
      local tNewInspectorName
      put sInspectorMax + 1 into tIndex
      put inspectorStackName(tIndex) into tNewInspectorName
      clone invisible stack "revInspectorTemplate"
      set the name of it to tNewInspectorName
      set the behavior of stack tNewInspectorName to the long id of this me
      put tNewInspectorName into tTargetInspector
      addInspectorToList tIndex
   end if
   -- Only reposition if we are opening a new editor
   if the mode of stack tTargetInspector is 0 then
      inspectorPositionPalette tIndex, tSelectedObjects
   end if
   unlock messages
   
   set the cSelectedObjects of stack tTargetInspector to tSelectedObjects
   
   lock messages
   palette stack tTargetInspector
   unlock messages
   unlock screen
end ideInspectObjects

function inspectorStackName pIndex
   return kPropertyInspectorPrefix && pIndex
end inspectorStackName

constant kNewInspectorOffset = 20
on inspectorPositionPalette pIndex, pSelObj
   local tStackName
   put inspectorStackName(pIndex) into tStackName
   local tRect
   put revIDEGetPreference("palette_rect_" & tStackName) into tRect
   
   if __isRect(tRect) then
      set the topleft of stack tStackName to item 1 to 2 of tRect
      exit inspectorPositionPalette
   end if
   
   local tPrevInspector
   put inspectorStackName(pIndex - 1) into tPrevInspector
   -- if we have an open inspector, just offset the new one by 10 pixels
   if there is a stack tPrevInspector and the mode of stack tPrevInspector is not 0 then
      set the topleft of stack tStackName to \
            the left of stack tPrevInspector + kNewInspectorOffset, the top of stack tPrevInspector + kNewInspectorOffset
   else
      local tScreenWidth
      put item 3 of the screenrect - item 1 of the screenrect into tScreenWidth
      set the top of stack tStackName to the top of the topstack            
      # AL-2015-09-09: [[ Bug 15745 ]] Try and place PI to left of stack if it doesn't fit on the right
      if the right of the topstack + kNewInspectorOffset + the width of stack tStackName < tScreenWidth then
         set the left of stack tStackName to the right of the topstack + kNewInspectorOffset
      else if the left of the topstack - kNewInspectorOffset - the width of stack tStackName > 0 then
         set the right of stack tStackName to the left of the topstack - kNewInspectorOffset
      else
         set the left of stack tStackName to the right of the topstack + kNewInspectorOffset
      end if
      
      if intersect(the long id of stack tStackName, revIDEStackOfObject(line 1 of pSelObj)) then
         revIDEPositionPaletteDefault tStackName
      end if
   end if
end inspectorPositionPalette


on ideResumeStack
   ideSelectedObjectChanged
end ideResumeStack

on ideNewStack
   ideSelectedObjectChanged
end ideNewStack

on ideCloseStack
   ideSelectedObjectChanged
end ideCloseStack

on ideNameChanged
   ideSelectedObjectChanged
end ideNameChanged

# Sent by the IDE when the selection changed
on ideSelectedObjectChanged
   local tObjects
   put revIDESelectedObjects() into tObjects
   
   local tStack
   put revIDEStackOfObject(line 1 of tObjects) into tStack
   
   # If the object is on an inspector stack, lock it
   if the short name of tStack begins with kPropertyInspectorPrefix then
      if the cLocked of tStack is not true then
         dispatch "lockInspector" to tStack
      end if
   end if
   
   local tStackName
   repeat for each key tKey in inspectorList()
      put kPropertyInspectorPrefix && tKey into tStackName
      if the cLocked of stack tStackName is false and the mode of stack tStackName is not 0 then
         ideInspectObjects tObjects
         exit repeat
      end if
   end repeat
end ideSelectedObjectChanged

function inspectorForObject pObject
   local tStackName
   repeat for each key tKey in inspectorList()
      put kPropertyInspectorPrefix && tKey into tStackName
      if the mode of stack tStackName is not 0 \ 
            and pObject is among the lines of the cSelectedObjects of stack tStackName then
         return tStackName
      end if
   end repeat
   return empty
end inspectorForObject

function absoluteRectOfObject pObjectData
   local tInspector
   put inspectorForObject(pObjectData["object"]) into tInspector
   local tRect
   put the rect of group pObjectData["group"] of stack tInspector into tRect

   # Make sure left of group is left of stack
   put 0 into item 1 of tRect
   
   return revIDERelativeRectToAbsolute(tRect, the long id of stack tInspector)
end absoluteRectOfObject

on highlightObject pObjectData
   lock screen
   local tTargetInspector
   put the long id of stack inspectorForObject(pObjectData["object"]) into tTargetInspector
   dispatch "hiliteFrameItem" to tTargetInspector with pObjectData["section"]
   dispatch "navSelected" to tTargetInspector with pObjectData["section"]
   unlock screen
end highlightObject
