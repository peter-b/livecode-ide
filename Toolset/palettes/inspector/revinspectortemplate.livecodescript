﻿script "revInspectorTemplate"
local sSelectedObjects
local sInspectorLock
on preOpenStack
   put false into sInspectorLock
   put revIDESelectedObjects() into sSelectedObjects
   revIDESubscribe "idePropertyChanged",sSelectedObjects
   inspectorTitleUpdate
    
   # Set the inspector behaviour
   dispatch "setAsBehavior" to revIDEInspectorBehavior() with the long id of me
end preOpenStack

on openStack   
   lock screen
   
   # Register of IDE messages
   revIDESubscribe "idePreferenceChanged:idePropertyInspector_labels"
   
   # Get a list of the properties and groups we'll be displaying
   set the inspectorData of me to revIDEPropertiesInfo(sSelectedObjects)
   unlock screen
end openStack

on closeStack
   ## Unsubscribe from all messages
   revIDEUnsubscribe "idePreferenceChanged:idePropertyInspector_labels"
   
   # Unlock
   put false into sInspectorLock
end closeStack

on resizeStack
   resizeInspector
end resizeStack

#####################
#### PI PROPERTIES #####
#####################

setProp cSelectedObjects pSelectedObjects
   if pSelectedObjects is sSelectedObjects then 
      exit cSelectedObjects
   end if
   
   if the cLocked of me then
      exit cSelectedObjects
   end if
   
   # Unsubscribe the the objects previously 
   revIDEUnsubscribe "idePropertyChanged","",sSelectedObjects
   
   if pSelectedObjects is empty then 
      inspectorClear
      exit cSelectedObjects
   end if
   
   lock screen
   revIDESubscribe "idePropertyChanged", pSelectedObjects
   put pSelectedObjects into sSelectedObjects
   
   # Get a list of the properties and groups we'll be displaying
   set the inspectorData of me to revIDEPropertiesInfo(sSelectedObjects)
   inspectorTitleUpdate
   unlock screen
end cSelectedObjects

getProp cSelectedObjects
   return sSelectedObjects
end cSelectedObjects

setProp cLocked pState
   if pState is false then
      put false into sInspectorLock
      send "ideSelectedObjectChanged" to stack "revInspector" in 0 millisecs
   else
      put true into sInspectorLock
   end if
end cLocked

getProp cLocked
   return sInspectorLock
end cLocked

#####################
#### PI FUNCTIONS #####
#####################

on inspectorLock pState
   set the cLocked of me to pState
end inspectorLock

on lockInspector
   if the cLocked of me is false then
      dispatch "actionSelected" to me with "inspectorLock"
   end if
end lockInspector

on idePropertyChanged
   lock screen
   inspectorFill
   inspectorTitleUpdate
   unlock screen
end idePropertyChanged

on inspectorTreeMenuDisplay
   local tObjects, tStack, tDefaultStack
   local tHandlers, tSendMessageList, tLockInspector, tFocusedObject
   put sSelectedObjects into tObjects
   
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
   
   local tInspect
   put "Inspect" & cr into tInspect
   
   put revIDEObjectSelectionMenu(tObjects, "") after tInspect
   
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
   
   if the cREVLinked of this stack is not empty
   then put "!cLock Inspector" into tLockInspector
   else put "!nLock Inspector" into tLockInspector
   
   set the text of button "inspectMenu" of this stack to tInspect & cr & "-" \
         & cr & "Edit Script" & cr & tSendMessageList
   
   popup button "inspectMenu" of this stack at the mouseloc
   
   set the defaultStack to tDefaultStack
end inspectorTreeMenuDisplay

on menuPick pWhich
   local tFocusedObject, tObjects, tStack
   put the long id of the focusedObject into tFocusedObject
   if word 1 of tFocusedObject is "field" \
         and revIDEStackOfObject(tFocusedObject) is the short name of this stack
   then send "closeField" to tFocusedObject
   
   put sSelectedObjects into tObjects
   put revIDEStackOfObject(line 1 of tObjects) into tStack
   set the itemDel to "|"
   switch item 1 of pWhich
      case "Inspect"
         revIDEInspectObjects the last item of pWhich
         break
      case "Send Message"
         revIDESendMessageToObject item 2 of pWhich, tObjects
         break
      case "Edit Script"
         revIDEEditScriptOfObjects tObjects 
         break
   end switch
end menuPick

private on inspectorTitleUpdate
   if sSelectedObjects is empty then 
      set the title of me to "No object selected"
   else if the number of lines of sSelectedObjects is 1 then
      if exists(sSelectedObjects) then
         set the title of me to the name of sSelectedObjects && "(id"&& the id of sSelectedObjects&")"
      end if
   else
      set the title of me to "Multiple objects"
   end if
end inspectorTitleUpdate

#####################
##### MESSAGES #####
#####################

# Sent by an editor when a property value is being changed
on editorValueChanged pProperty, pValue, pLockUpdates
   revIDEPropertySet sSelectedObjects, pProperty, pValue
end editorValueChanged

function editorStoredValue pProperty
   return revIDEPropertyRetrieveStored(sSelectedObjects, pProperty)
end editorStoredValue

on editorStoreValue pProperty, pValue
   revIDEPropertyStore sSelectedObjects, pProperty, pValue
end editorStoreValue

on idePreferenceChanged pPreference
   local tValue
   put revIDEGetPreference(pPreference) into tValue
   switch pPreference
      case "idePropertyInspector_labels"
         global gRevLanguageNames
         put tValue into gRevLanguageNames
         set the cLanguageNames of cd 1 of stack "revPreferences" to tValue
         inspectorChanged
         break
   end switch
end idePreferenceChanged
   

# Sent by the IDE when a property has changed
on revIDEPropertyChanged
   # Get values for properties in given group
   
   # Set values for all editors
   
   # Layout
end revIDEPropertyChanged

getProp displayData
   return revIDEPropertiesOfSection(sSelectedObjects, inspectorSectionGetName())
end displayData

getProp viewColumns [pSection]
   return 1
end viewColumns

getProp showSubSections [pSection]
   return false
end showSubSections

function inspectorSectionIcon pSection
   return revIDEPropertySectionNameToIconName(pSection)
end inspectorSectionIcon

# Add to header actions/preferences
on inspectorAddActions
   addFrameItem "inspectorTarget", "header", "action", "Select object to inspect", "bullseye", "bullseye", "inspectorTreeMenuDisplay", the long id of me 
   addFrameItem "inspectorLock","header", "toggle", "Lock Inspector", "unlock", "lock","inspectorLock", the long id of me
   addFrameItem "idePropertyInspector_labels", "header", "preference", "Property Labels", "enum","false:Description of option,true:Name of LiveCode property", "inspectorPropLabelsPrefChanged", the long id of me
end inspectorAddActions

on inspectorPropLabelsPrefChanged pPref, pValue
   revIDESetPreference pPref, pValue
end inspectorPropLabelsPrefChanged

getProp showMultiPropLabels
   return false
end showMultiPropLabels
