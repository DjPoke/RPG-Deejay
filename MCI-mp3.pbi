; German forum: http://robsite.de/php/pureboard/viewtopic.php?t=2786&highlight=
; Author: GPI
; Date: 09. November 2003

;Info: MCI-MP3-Commands
Enumeration 0
      #MP3_Unknown
      #MP3_Stopped
      #MP3_Playing
      #MP3_Paused
EndEnumeration

;Example

Enumeration 1
      #gadget_File
      #Gadget_VolumeTxt
      #Gadget_Volume
      #Gadget_SpeedTxt
      #Gadget_Speed
      #Gadget_PositionTxt
      #Gadget_Position
      #Gadget_Load
      #Gadget_Play
      #Gadget_Stop
      #Gadget_Pause
      #Gadget_Resume
EndEnumeration
    
Global Dim IsMp3((3 * #maxSounds) + 1)
    
Global mp3LoadErrorCode.i

Declare  mp3_getstatus(nb)
Declare  mp3_load(nb,file.s)
Declare  mp3_play(nb, flags, volume)
Declare  mp3_playstart(nb)
Declare  mp3_playpart(nb,start,endpos)
Declare  mp3_pause(nb)
Declare  mp3_resume(nb)
Declare  mp3_stop(nb)
Declare  mp3_free2(nb)
Declare  mp3_setvolume(nb,volume)
Declare  mp3_getvolume(nb)
Declare  mp3_setspeed(nb,tempo)
Declare  mp3_getspeed(nb)
Declare  mp3_getlength(nb)
Declare  mp3_getposition(nb)
Declare  mp3_seek(nb,pos)
Declare.s mp3_timestring(time)


;- Procedures Zone
Procedure MP3_GetStatus(Nb)
      Result=#MP3_Unknown
      a$=Space(#MAX_PATH)
      i=mciSendString_("status MP3_"+Str(Nb)+" mode",@a$,#MAX_PATH,0)
      If i=0
            Select a$
            Case "stopped":Result=#MP3_Stopped
            Case "playing":Result=#MP3_Playing
            Case "paused":Result=#MP3_Paused
            EndSelect
      EndIf
      ProcedureReturn Result
EndProcedure
Procedure MP3_Load(Nb,file.s)
      i=mciSendString_("OPEN "+Chr(34)+file+Chr(34)+" Type MPEGVIDEO ALIAS MP3_"+Str(Nb),0,0,0)
      If i=0
            IsMp3(Nb) = 1
            ProcedureReturn #True
      Else
            mp3LoadErrorCode = i
            IsMp3(Nb) = 0
            ProcedureReturn #False
      EndIf
EndProcedure
Procedure MP3_Play(Nb, flags, volume)
      If flags & #PB_Sound_Loop = #PB_Sound_Loop
        i=mciSendString_("play MP3_"+Str(Nb) + " repeat",0,0,0)
      Else
        i=mciSendString_("play MP3_"+Str(Nb),0,0,0)
      EndIf
      MP3_SetVolume(Nb, volume)
      ProcedureReturn i
EndProcedure
Procedure MP3_PlayStart(Nb)
      i=mciSendString_("play MP3_"+Str(Nb)+" from "+Str(0),0,0,0)
      ProcedureReturn i
EndProcedure
Procedure MP3_PlayPart(Nb,Start,endPos)
      i=mciSendString_("play MP3_"+Str(Nb)+" from "+Str(Start)+" to "+Str(endPos),0,0,0)
      ProcedureReturn i
EndProcedure
Procedure MP3_Pause(Nb)
      i=mciSendString_("pause MP3_"+Str(Nb),0,0,0)
      ProcedureReturn i
EndProcedure
Procedure MP3_Resume(Nb)
      i=mciSendString_("resume MP3_"+Str(Nb),0,0,0)
      ProcedureReturn i
EndProcedure
Procedure MP3_Stop(Nb)
      i=mciSendString_("stop MP3_"+Str(Nb),0,0,0)
      ProcedureReturn i
EndProcedure
Procedure mp3_Free2(Nb)
      i=mciSendString_("close MP3_"+Str(Nb),0,0,0)
      IsMp3(Nb) = 0
      ProcedureReturn i
EndProcedure
Procedure MP3_SetVolume(Nb,volume)
      i=mciSendString_("SetAudio MP3_"+Str(Nb)+" volume to "+Str(volume*10),0,0,0)
      ProcedureReturn i
EndProcedure
Procedure MP3_GetVolume(Nb)
      a$=Space(#MAX_PATH)
      i=mciSendString_("status MP3_"+Str(Nb)+" volume",@a$,#MAX_PATH,0)
      ProcedureReturn (Val(a$) / 10)
EndProcedure


Procedure MP3_SetSpeed(Nb,Tempo)
      i=mciSendString_("set MP3_"+Str(Nb)+" Speed "+Str(Tempo),0,0,0)
      ProcedureReturn i
EndProcedure
Procedure MP3_GetSpeed(Nb)
      a$=Space(#MAX_PATH)
      i=mciSendString_("status MP3_"+Str(Nb)+" Speed",@a$,#MAX_PATH,0)
      ProcedureReturn Val(a$)
EndProcedure
Procedure MP3_GetLength(Nb)
      a$=Space(#MAX_PATH)
      i=mciSendString_("status MP3_"+Str(Nb)+" length",@a$,#MAX_PATH,0)
      ProcedureReturn Val(a$)
EndProcedure
Procedure MP3_GetPosition(Nb)
      a$=Space(#MAX_PATH)
      i=mciSendString_("status MP3_"+Str(Nb)+" position",@a$,#MAX_PATH,0)
      ProcedureReturn Val(a$)
EndProcedure
Procedure MP3_Seek(Nb,pos)
      i=mciSendString_("Seek MP3_"+Str(Nb)+" to "+Str(pos),0,0,0)
      ProcedureReturn i
EndProcedure
Procedure.s MP3_TimeString(time)
      time/1000
      sek=time%60:time/60
      min=time%60:time/60
      ProcedureReturn RSet(Str(time),2,"0")+":"+RSet(Str(min),2,"0")+":"+RSet(Str(sek),2,"0")
EndProcedure
Procedure SetVol(x)
      SetGadgetText(#Gadget_VolumeTxt,"Volume:"+Str(x))
      SetGadgetState(#Gadget_Volume,x)
EndProcedure
Procedure SetSpeed(x)
      SetGadgetText(#Gadget_SpeedTxt,"Speed:"+Str(x))
      SetGadgetState(#Gadget_Speed,x)
EndProcedure
Procedure SetPosition(x,max)
      SetGadgetText(#Gadget_PositionTxt,"Position:"+MP3_TimeString(x)+" : "+MP3_TimeString(max))
      If max>0
            SetGadgetState(#Gadget_Position,x*1000/max)
      Else
            SetGadgetState(#Gadget_Position,0)
      EndIf
EndProcedure

; Epb
; IDE Options = PureBasic 5.71 LTS (Windows - x86)
; CursorPosition = 30
; FirstLine = 12
; Folding = ----
; EnableXP
; Executable = RPG Deejay.exe