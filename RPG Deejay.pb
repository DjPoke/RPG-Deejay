; ====================================================================================================
; RPG Deejay, Freeware open source par retro-bruno (c) 2018-2020
; ====================================================================================================

; Nombre maximum de sons ou de dossiers de sons dans la liste de gauche
#maxSounds = 1000 

; ====================================================================================================
CompilerIf #PB_Compiler_OS = #PB_OS_Windows 
  ; Charger la libraire MCI-mp3, qui n'est compatible qu'avec Windows
  IncludeFile "MCI-mp3.pbi"
CompilerEndIf
; ====================================================================================================

; encodeurs/décodeur
UseOGGSoundDecoder()
UseFLACSoundDecoder()
UsePNGImageDecoder()

; initialisation des bibliothèques
If InitSound() = 0
  MessageRequester("Erreur", "Impossible d'initialiser la bibliothèque sonore !", #PB_MessageRequester_Error)
  End
EndIf

; slash ou antislash ?
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  #Sep = "\"
CompilerElse
  #Sep = "/"
CompilerEndIf

; récupérer le répertoire de l'application
Global dir$ = GetCurrentDirectory()
CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
  If FileSize(dir$ + "RPG Deejay.app") = -1
    SetCurrentDirectory("../../")
  EndIf  
  dir$ = GetCurrentDirectory()
CompilerEndIf


; constantes
Enumeration
  ; fenêtres, et menu
  #window = 1
  #webWindow = 2
  #helpWindow = 3
  #menu = 1
  ; soundTree, stop button et web gadget
  #soundTree = 7
  #stopButton = 8
  #webMusicGadget = 9
  ;
  #maxGadgets = 20  
  ; playlists
  #bgMusic = 1
  #bgAmbience = 2
  #bgRandomAmbienceList = 3
  #webMusics = 4
  #oneshotSfx = 5
  #loopSfx = 6
  ; titles offsets
  #titleOffset = 100 ; s'ajoute au numéro de player pour obtenir son gadget "titre"
  #bgMusicTitleOffset = 101
  #bgAmbienceTitleOffset = 102
  #bgRandomAmbienceListTitleOffset = 103
  #webMusicsTitleOffset = 104
  #oneshotSfxTitleOffset = 105
  #loopSfxTitleOffset = 106
  ; play buttons offsets
  #playButtonOffset = 200 ; s'ajoute au numéro de player pour obtenir son bouton "play"
  #bgMusicPlayButtonOffset = 201
  #bgAmbiencePlayButtonOffset = 202
  #bgRandomAmbienceListPlayButtonOffset = 203
  #webMusicsPlayButtonOffset = 204
  #oneshotSfxPlayButtonOffset = 205
  #loopSfxPlayButtonOffset = 206
  ; stop buttons offsets
  #stopButtonOffset = 300 ; s'ajoute au numéro de player pour obtenir son bouton "stop"
  #bgMusicStopButtonOffset = 301
  #bgAmbienceStopButtonOffset = 302
  #bgRandomAmbienceListStopButtonOffset = 303
  #webMusicsStopButtonOffset = 304
  #oneshotSfxStopButtonOffset = 305
  #loopSfxStopButtonOffset = 306
  ; infos offsets
  #infoOffset = 400 ; s'ajoute au numéro de player pour obtenir les infos relatives aux fichiers musicaux
  #bgMusicInfoOffset = 401
  #bgAmbienceInfoOffset = 402
  #bgRandomAmbienceListInfoOffset = 403
  #webMusicsInfoOffset = 404
  #oneshotSfxInfoOffset = 405
  #loopSfxInfoOffset = 406
  ; volumes offsets
  #volumeOffset = 500 ; s'ajoute au numéro de player pour obtenir le curseur de volume
  #bgMusicVolumeOffset = 501
  #bgAmbienceVolumeOffset = 502
  #bgRandomAmbienceListVolumeOffset = 503
  #webMusicsVolumeOffset = 504
  #oneshotSfxVolumeOffset = 505
  #loopSfxVolumeOffset = 506
  
  ; flags
  #isLooping = 1 ; le player est en mode boucle / exclusif
  #playFullList = 2 ; le player joue toute la liste de sons linéairement
  #playRandomFullList = 4 ; le player joue toute la liste de sons aléatoirement
  #webGadget = 8          ; le player va jouer une musique via une URL internet
                          ;
                          ; ====================================================================================================
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    #isMp3 = 16    ; le player joue un mp3
  CompilerEndIf
  ; ====================================================================================================
  ;
  #dossier = 1 ; Icone de dossier
  #son = 2     ; Icone de dossier
               ;
  #maxVolume = 70
  #maxTracks = 10000 ; nombre de sons maximum dans chaque liste
                     ;
  #fadeDelay = 50
  
EndEnumeration

; taille de la fenêtre
Global winWidth = 800 ; dimensions de la fenêtre, par défaut
Global winHeight = 600

; declarations
Declare CreatePlayer(gadget, x, y, width, height, title$, bgcol, options = 0)
Declare StopSounds()
Declare New()
Declare.s GetListViewName(gadget)
Declare Load(project.s = "")
Declare Save()
Declare.f Max(a.f, b.f)
Declare.f Min(a.f, b.f)
Declare error(err$)
Declare.i LoadCustomSound(ext$, snd)
Declare.i PlayCustomSound(snd, flags, volume, gadget, track)
Declare.i GetCustomSoundPlaying(snd)
Declare SetVolumeCustomSound(snd, volume)
Declare FreeCustomSound(snd)
Declare ScaleWindow()
Declare InsertProjectFilename(m1$)

; tableaux et variables
Global Dim soundPath$(#maxSounds) ; chemins complets des sons et des dossiers de sons
Global Dim soundIsPath(#maxSounds); #True si le chemin est celui d'un dossier

Global Dim playerGadgetOptions(#maxGadgets)
Global Dim playerGadgetSoundsCount(#maxGadgets)
Global Dim playerGadgetVolume(#maxGadgets, #maxTracks)
Global Dim playerGadgetExtension.s(4)
Global Dim playerGadgetPlaying(4)
Global Dim soundInstance(4)
Global Dim soundInstanceGadget(4)
Global Dim soundInstanceTrack(4)
Global Dim playerGadgetInfoString.s(#maxGadgets, #maxTracks)

Global changed
Global fadeMusicOn
Global fadeVolume
Global soundOptions
Global treeNumSoundToPlay, treeNumSoundToPlayLoopSfx, treeNumSoundToPlayOneShotSfx
Global eSourceBGMusicGadget
Global eTargetBGMusicGadget
Global oneshotSoundFlag
Global trackAmbienceSound, trackLoopSound, trackOneShotSound

; numéros de sons sans instances,
; pour chaque type de piste
Global soundTypeList = #maxSounds + 1
Global soundTypeAmbience = #maxSounds + 2
Global soundTypeLoopSfx = #maxSounds + 3
Global soundTypeOneShotSfx = #maxSounds + 4
Global typeList = 1
Global typeAmbience = 2
Global typeLoopSfx = 3
Global typeOneShotSfx = 4

; images par défaut
LoadImage(#dossier, dir$ + "icones" + #Sep + "dossier.png")
LoadImage(#son, dir$ + "icones" + #Sep + "son.png")


#version$ = "0.9.9.2b"

; ouverture de la fenêtre
If OpenWindow(#window, 0, 0, winWidth, winHeight + MenuHeight(), "RPG Deejay " + #version$, #PB_Window_SystemMenu|#PB_Window_TitleBar|#PB_Window_SizeGadget|#PB_Window_ScreenCentered|#PB_Window_MinimizeGadget|#PB_Window_MaximizeGadget|#PB_Window_SizeGadget) = 0
  error("Impossible d'ouvrir la fenêtre du programme !")
EndIf

CreateStatusBar(1, WindowID(#window))
AddStatusBarField(110)
AddStatusBarField(#PB_Ignore)

winWidth = WindowWidth(#window, #PB_Window_InnerCoordinate)
winHeight = WindowHeight(#window, #PB_Window_InnerCoordinate) - StatusBarHeight(1)

If CreateMenu(#menu, WindowID(#window))
  MenuTitle("Fichier")
  MenuItem(1, "Nouveau" + Chr(9) + "Ctrl+N")
  MenuBar()
  MenuItem(2, "Ouvrir playlist" + Chr(9) + "Ctrl+O")
  MenuItem(3, "Enregistrer playlist sous..." + Chr(9) + " Ctrl+S")
  MenuBar()
  MenuItem(5, "Importer un fichier" + Chr(9) + "Ctrl+I")
  MenuItem(6, "Importer un dossier" + Chr(9) + "Ctrl+D")
  MenuItem(7, "Ajouter une URL" + Chr(9) + "Ctrl+U")    
  MenuBar()
  OpenSubMenu("Projets récents")
  MenuItem(1001, "")
  MenuItem(1002, "")
  MenuItem(1003, "")
  MenuItem(1004, "")
  MenuItem(1005, "")
  MenuItem(1006, "")
  MenuItem(1007, "")
  MenuItem(1008, "")
  MenuItem(1009, "")
  MenuItem(1010, "")
  MenuBar()
  MenuItem(1011, "Effacer la liste")
  CloseSubMenu()
  MenuBar()
  MenuItem(9, "Quitter" + Chr(9) + "Ctrl+Q")
  MenuTitle("Edition")
  MenuItem(11, "Supprimer la sélection" + Chr(9) + "Suppr")
  MenuTitle("?")
  MenuItem(21, "Aide" + Chr(9) + "F1")
  MenuItem(22, "A propos...")
EndIf

; charger les préférences si elles existent
If OpenPreferences(dir$ + "config.ini")
  For i = 1 To 10
    SetMenuItemText(#menu, i + 1000, "")
  Next
  j = 1
  For i = 1 To 10
    p$ = ReadPreferenceString("Projet " + Str(i), "")
    If p$ <> ""
      If FileSize(p$) > 0
        SetMenuItemText(#menu, j + 1000, p$)
        j + 1
      EndIf
    EndIf
  Next
  ClosePreferences()
EndIf

; les sauvegarder quoi qu'il en soit
If CreatePreferences(dir$ + "config.ini")
  For i = 1 To 10
    WritePreferenceString("Projet " + Str(i), GetMenuItemText(#menu, i + 1000))
  Next
  ClosePreferences()
EndIf

; ajout des gadgets à la fenêtre
ButtonGadget(#stopButton, 0, 0, Int(winWidth / 4), 25, "Stopper tout")
TreeGadget(#soundTree, 0, 25, Int(winWidth / 4), winHeight - GadgetHeight(#stopButton) + 3 - StatusBarHeight(1))

wh = WindowHeight(#window, #PB_Window_InnerCoordinate) - MenuHeight() - 1 - StatusBarHeight(1)

CreatePlayer(#bgMusic, (Int(winWidth / 4) * 1) + 1, 0, Int(winWidth / 4), Int(wh / 2), "Musiques d'ambiance", RGB(255, 220, 220), #isLooping)
CreatePlayer(#bgAmbience, (Int(winWidth / 4) * 1) + 1, Int(wh / 2) + 1, Int(winWidth / 4), Int(wh / 2), "Sons d'ambiance", RGB(255, 220, 220), #isLooping)
CreatePlayer(#bgRandomAmbienceList, (Int(winWidth / 4) * 2) + 1, 0, Int(winWidth / 4), Int(wh / 2), "Playlist aléatoire", RGB(255, 220, 220), #isLooping|#playRandomFullList)
CreatePlayer(#webMusics, (Int(winWidth / 4) * 2) + 1, Int(wh / 2) + 1, Int(winWidth / 4), Int(wh / 2), "Musiques internet", RGB(255, 255, 220), #webGadget)
CreatePlayer(#oneshotSfx, (Int(winWidth / 4) * 3) + 1, 0, Int(winWidth / 4), Int(wh / 2), "Sons oneshot", RGB(220, 255, 220))
CreatePlayer(#loopSfx, (Int(winWidth / 4) * 3) + 1, Int(wh / 2) + 1, Int(winWidth / 4), Int(wh / 2), "Sons en boucle", RGB(220, 220, 255), #isLooping)

; repertoires de sons par defaut
AddGadgetItem(#soundTree, -1, "Liste des sons", ImageID(#dossier), 0)

; affichage correct de la fenêtre sous Windows
; ====================================================================================================
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  UpdateWindow_(WindowID(#window))
CompilerEndIf
; ====================================================================================================

winWidth = WindowWidth(#window, #PB_Window_InnerCoordinate)
winHeight = WindowHeight(#window, #PB_Window_InnerCoordinate)

WindowBounds(#window, winWidth, winHeight, #PB_Default, #PB_Default)

; effacer les tooltips
GadgetToolTip(#bgMusic, "")
GadgetToolTip(#bgAmbience, "")
GadgetToolTip(#bgRandomAmbienceList, "")
GadgetToolTip(#oneshotSfx, "")
GadgetToolTip(#loopSfx, "")
GadgetToolTip(#webMusics, "")

; autoriser les dragndrops
EnableGadgetDrop(#bgMusic, #PB_Drop_Text, #PB_Drag_Copy)
EnableGadgetDrop(#bgAmbience, #PB_Drop_Text, #PB_Drag_Copy)
EnableGadgetDrop(#bgRandomAmbienceList, #PB_Drop_Text, #PB_Drag_Copy)
EnableGadgetDrop(#oneshotSfx, #PB_Drop_Text, #PB_Drag_Copy)
EnableGadgetDrop(#loopSfx, #PB_Drop_Text, #PB_Drag_Copy)

AddKeyboardShortcut(#Window, #PB_Shortcut_Control | #PB_Shortcut_N, 1)
AddKeyboardShortcut(#Window, #PB_Shortcut_Control | #PB_Shortcut_O, 2)
AddKeyboardShortcut(#Window, #PB_Shortcut_Control | #PB_Shortcut_S, 3)
AddKeyboardShortcut(#Window, #PB_Shortcut_Control | #PB_Shortcut_I, 5)
AddKeyboardShortcut(#Window, #PB_Shortcut_Control | #PB_Shortcut_D, 6)
AddKeyboardShortcut(#Window, #PB_Shortcut_Control | #PB_Shortcut_U, 7)
AddKeyboardShortcut(#Window, #PB_Shortcut_Command | #PB_Shortcut_Q, 9)
AddKeyboardShortcut(#Window, #PB_Shortcut_Delete, 11)
AddKeyboardShortcut(#Window, #PB_Shortcut_Return, 12)

AddKeyboardShortcut(#Window, #PB_Shortcut_Escape, 101)
AddKeyboardShortcut(#Window, #PB_Shortcut_End, 102)

AddKeyboardShortcut(#Window, #PB_Shortcut_F1, 21)

; initialiser les variables et gadgets
New()

; timer d'execution de certaines routines
AddWindowTimer(#window, 2, 10)

; boucle principale
Repeat
  
  ev = WindowEvent()
  
  Select ev
    Case #PB_Event_CloseWindow
      ew = EventWindow()
      If ew = #window
        Break ; aller en fin de programme
      ElseIf ew = #webWindow
        CloseWindow(#webWindow)
        SetGadgetColor(#webMusicsTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))  
        DisableGadget(#webMusicsInfoOffset, #False)
      EndIf
    Case #PB_Event_SizeWindow, #PB_Event_MaximizeWindow
      winWidth = WindowWidth(#window, #PB_Window_InnerCoordinate)
      winHeight = WindowHeight(#window, #PB_Window_InnerCoordinate)
      ScaleWindow()
      
      ; événements des menus
    Case #PB_Event_Menu
      em = EventMenu()
      CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
        If em = #PB_Menu_Quit
          Break ; aller en fin de programme
        EndIf
      CompilerEndIf
      Select em
        Case 1
          If changed = #False Or (changed = #True And MessageRequester("Attention", "L'ensemble du projet courant sera perdu ! Voulez-vous continuer ?", #PB_MessageRequester_Warning|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes)
            New()
          EndIf
        Case 2
          Load()
        Case 3
          Save()
        Case 5
          ; ====================================================================================================
          CompilerIf #PB_Compiler_OS = #PB_OS_Windows
            file$ = OpenFileRequester("Importer un son", GetUserDirectory(#PB_Directory_Musics), "Fichier audio|*.*|Fichier ogg|*.ogg|Fichier mp3|*.mp3|Fichier flac|*.flac|Fichier wav|*.wav", 0, #PB_Requester_MultiSelection)
            ; ====================================================================================================
          CompilerElse
            file$ = OpenFileRequester("Importer un son", GetUserDirectory(#PB_Directory_Musics), "Fichier audio|*.*|Fichier ogg|*.ogg|Fichier flac|*.flac|Fichier wav|*.wav", 0, #PB_Requester_MultiSelection)
          CompilerEndIf
          ; ====================================================================================================
          If file$ <> ""
            changed = #True
            While file$
              flag = #False
              For i = 1 To CountGadgetItems(#soundTree)
                If LCase(file$) = LCase(soundPath$(i)) And soundIsPath(i) = #False
                  flag = #True
                  Break
                EndIf
              Next
              If flag = #False And CountGadgetItems(#soundTree) < #maxSounds
                e$ = LCase(GetExtensionPart(file$))
                ; ====================================================================================================
                CompilerIf #PB_Compiler_OS = #PB_OS_Windows
                  If e$ = "ogg" Or e$ = "flac" Or e$ = "wav" Or e$ = "mp3"
                    AddGadgetItem(#soundTree, -1, GetFilePart(file$), ImageID(#son), 1)
                    SetGadgetItemState(#soundTree, 0, #PB_Tree_Expanded)
                    soundPath$(CountGadgetItems(#soundTree)) = file$
                    soundIsPath(CountGadgetItems(#soundTree)) = #False
                  Else
                    MessageRequester("Attention", "Impossible de charger le fichier !", #PB_MessageRequester_Warning)
                  EndIf
                  ; ====================================================================================================
                CompilerElse
                  If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
                    AddGadgetItem(#soundTree, -1, GetFilePart(file$), ImageID(#son), 1)
                    SetGadgetItemState(#soundTree, 0, #PB_Tree_Expanded)
                    soundPath$(CountGadgetItems(#soundTree)) = file$
                    soundIsPath(CountGadgetItems(#soundTree)) = #False
                  Else
                    MessageRequester("Attention", "Impossible de charger le fichier !", #PB_MessageRequester_Warning)
                  EndIf
                CompilerEndIf
                ; ====================================================================================================
              ElseIf flag = #False
                MessageRequester("Attention", "Trop de sons (" + Str(#maxSounds) + " maximum)", #PB_MessageRequester_Warning)
                Break
              EndIf
              file$ = NextSelectedFileName()
            Wend
          EndIf
        Case 6
          dir$ = PathRequester("Importer un dossier de sons", GetUserDirectory(#PB_Directory_Musics))
          
          If dir$ <> ""
            changed = #True  
          EndIf
          
          flag = #False
          If ExamineDirectory(0, dir$, "*.*")
            While NextDirectoryEntry(0)
              If DirectoryEntryType(0) = #PB_DirectoryEntry_File
                e$ = GetExtensionPart(DirectoryEntryName(0))
                ; ====================================================================================================
                CompilerIf #PB_Compiler_OS = #PB_OS_Windows
                  If e$ = "ogg" Or e$ = "flac" Or e$ = "wav" Or e$ = "mp3"
                    flag = #True
                    Break
                  EndIf
                  ; ====================================================================================================
                CompilerElse
                  If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
                    flag = #True
                    Break
                  EndIf
                CompilerEndIf
                ; ====================================================================================================
              ElseIf DirectoryEntryType(0) = #PB_DirectoryEntry_Directory
                dir2$ = dir$ + DirectoryEntryName(0) + #Sep
                If ExamineDirectory(1, dir2$, "*.*")
                  While NextDirectoryEntry(1)
                    If DirectoryEntryType(1) = #PB_DirectoryEntry_File
                      file$ = DirectoryEntryName(1)
                      If file$ <> "." And file$ <> ".."
                        e$ = GetExtensionPart(file$)
                        ; ====================================================================================================
                        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
                          If e$ = "ogg" Or e$ = "flac" Or e$ = "wav" Or e$ = "mp3"
                            flag = #True
                            Break
                          EndIf
                          ; ====================================================================================================
                        CompilerElse
                          If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
                            flag = #True
                            Break
                          EndIf
                        CompilerEndIf
                        ; ====================================================================================================
                      EndIf
                    EndIf
                  Wend
                  FinishDirectory(1)
                  If flag = #True : Break : EndIf
                EndIf
              EndIf
            Wend
            FinishDirectory(0)
          EndIf
          
          If dir$ <> "" And flag = #True
            flag = #False
            For i = 1 To CountGadgetItems(#soundTree)
              If LCase(dir$) = LCase(soundPath$(i)) And soundIsPath(i) = #True
                flag = #True
                Break
              EndIf
            Next
            If flag = #False And CountGadgetItems(#soundTree) < #maxSounds
              soundPath$(CountGadgetItems(#soundTree) + 1) = dir$
              soundIsPath(CountGadgetItems(#soundTree) + 1) = #True
              dir$ = ReverseString(dir$)
              dir$ = StringField(dir$, 2, #Sep)
              dir$ = ReverseString(dir$)
              AddGadgetItem(#soundTree, -1, dir$, ImageID(#dossier), 1)
              SetGadgetItemState(#soundTree, 0, #PB_Tree_Expanded)
              dir$ = soundPath$(CountGadgetItems(#soundTree))
              
              If ExamineDirectory(0, dir$, "*.*")
                While NextDirectoryEntry(0)
                  If DirectoryEntryType(0) = #PB_DirectoryEntry_File
                    file$ = DirectoryEntryName(0)
                    flag = #False
                    For i = 1 To CountGadgetItems(#soundTree)
                      If LCase(file$) = LCase(soundPath$(i)) And soundIsPath(i) = #False
                        flag = #True
                        Break
                      EndIf
                    Next
                    If flag = #False And CountGadgetItems(#soundTree) < #maxSounds
                      e$ = LCase(GetExtensionPart(file$))
                      ; ====================================================================================================
                      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
                        If e$ = "ogg" Or e$ = "flac" Or e$ = "wav" Or e$ = "mp3"
                          AddGadgetItem(#soundTree, -1, GetFilePart(file$), ImageID(#son), 2)
                          soundPath$(CountGadgetItems(#soundTree)) = dir$ + file$
                          soundIsPath(CountGadgetItems(#soundTree)) = #False
                        EndIf
                        ; ====================================================================================================
                      CompilerElse
                        If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
                          AddGadgetItem(#soundTree, -1, GetFilePart(file$), ImageID(#son), 2)
                          soundPath$(CountGadgetItems(#soundTree)) = dir$ + file$
                          soundIsPath(CountGadgetItems(#soundTree)) = #False
                        EndIf
                      CompilerEndIf
                      ; ====================================================================================================
                    ElseIf flag = #False
                      MessageRequester("Attention", "Trop de sons (" + Str(#maxSounds) + " maximum)", #PB_MessageRequester_Warning)
                      Break
                    EndIf
                  ElseIf DirectoryEntryType(0) = #PB_DirectoryEntry_Directory
                    If DirectoryEntryName(0) <> "." And DirectoryEntryName(0) <> ".."
                      dir2$ = dir$ + DirectoryEntryName(0) + #Sep
                      soundPath$(CountGadgetItems(#soundTree) + 1) = dir2$
                      soundIsPath(CountGadgetItems(#soundTree) + 1) = #True
                      dir2$ = ReverseString(dir2$)
                      dir2$ = StringField(dir2$, 2, #Sep)
                      dir2$ = ReverseString(dir2$)
                      AddGadgetItem(#soundTree, -1, dir2$, ImageID(#dossier), 2)
                      SetGadgetItemState(#soundTree, 0, #PB_Tree_Expanded)
                      dir2$ = soundPath$(CountGadgetItems(#soundTree))
                      If ExamineDirectory(1, dir2$, "*.*")
                        While NextDirectoryEntry(1)
                          If DirectoryEntryType(1) = #PB_DirectoryEntry_File
                            file$ = DirectoryEntryName(1)
                            flag = #False
                            For i = 1 To CountGadgetItems(#soundTree)
                              If LCase(file$) = LCase(soundPath$(i)) And soundIsPath(i) = #False
                                flag = #True
                                Break
                              EndIf
                            Next
                            If flag = #False And CountGadgetItems(#soundTree) < #maxSounds
                              e$ = LCase(GetExtensionPart(file$))
                              ; ====================================================================================================
                              CompilerIf #PB_Compiler_OS = #PB_OS_Windows
                                If e$ = "ogg" Or e$ = "flac" Or e$ = "wav" Or e$ = "mp3"
                                  AddGadgetItem(#soundTree, -1, GetFilePart(file$), ImageID(#son), 3)
                                  soundPath$(CountGadgetItems(#soundTree)) = dir2$ + file$
                                  soundIsPath(CountGadgetItems(#soundTree)) = #False
                                EndIf
                                ; ====================================================================================================
                              CompilerElse
                                If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
                                  AddGadgetItem(#soundTree, -1, GetFilePart(file$), ImageID(#son), 3)
                                  soundPath$(CountGadgetItems(#soundTree)) = dir2$ + file$
                                  soundIsPath(CountGadgetItems(#soundTree)) = #False
                                EndIf
                              CompilerEndIf  
                              ; ====================================================================================================
                            ElseIf flag = #False
                              MessageRequester("Attention", "Trop de sons (" + Str(#maxSounds) + " maximum)", #PB_MessageRequester_Warning)
                              Break
                            EndIf
                          EndIf
                        Wend
                        FinishDirectory(1)
                      EndIf
                    EndIf
                  EndIf
                Wend
              EndIf
            ElseIf flag = #False
              MessageRequester("Attention", "Trop de sons (" + Str(#maxSounds) + " maximum)", #PB_MessageRequester_Warning)
              Break
            EndIf
          EndIf
        Case 7
          url$ = InputRequester("Ajout de musiques par URL", "Veuillez saisir ou coller l'URL de la ou des musiques", "https://www.youtube.com/")
          If url$ <> ""
            AddGadgetItem(#webMusics, -1, url$)
          EndIf
        Case 9
          ew = EventWindow()
          If ew = #window
            Break ; aller en fin de programme
          EndIf
        Case 11
          If MessageRequester("Attention", "Le son va être arrêté, et les musiques et sons sélectionnés seront supprimés des listes. Confirmez-vous ?", #PB_MessageRequester_Warning|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
            For i = CountGadgetItems(#bgMusic) - 1 To 0 Step -1
              If GetGadgetItemState(#bgMusic, i)
                SetGadgetState(#bgMusicVolumeOffset, #maxVolume)
                DisableGadget(#bgMusicVolumeOffset, #True)
                playerGadgetPlaying(typeAmbience) = #False
                For j = i To CountGadgetItems(#bgMusic) - 2
                  playerGadgetInfoString(#bgMusic, j + 1) = playerGadgetInfoString(#bgMusic, j + 2)
                  playerGadgetVolume(#bgMusic, j + 1) = playerGadgetVolume(#bgMusic, j + 2)
                Next
                playerGadgetInfoString(#bgMusic, CountGadgetItems(#bgMusic)) = ""
                RemoveGadgetItem(#bgMusic, i)
                SetGadgetText(#bgMusicInfoOffset, "")
                playerGadgetSoundsCount(#bgMusic) = CountGadgetItems(#bgMusic)
              EndIf
            Next
            For i = CountGadgetItems(#bgAmbience) - 1 To 0 Step -1
              If GetGadgetItemState(#bgAmbience, i)
                SetGadgetState(#bgAmbienceVolumeOffset, #maxVolume)
                DisableGadget(#bgAmbienceVolumeOffset, #True)
                playerGadgetPlaying(typeAmbience) = #False
                For j = i To CountGadgetItems(#bgAmbience) - 2
                  playerGadgetInfoString(#bgAmbience, j + 1) = playerGadgetInfoString(#bgAmbience, j + 2)
                  playerGadgetVolume(#bgAmbience, j + 1) = playerGadgetVolume(#bgAmbience, j + 2)
                Next
                playerGadgetInfoString(#bgAmbience, CountGadgetItems(#bgAmbience)) = ""
                RemoveGadgetItem(#bgAmbience, i)
                SetGadgetText(#bgAmbienceInfoOffset, "")
                playerGadgetSoundsCount(#bgAmbience) = CountGadgetItems(#bgAmbience)
              EndIf
            Next
            For i = CountGadgetItems(#bgRandomAmbienceList) - 1 To 0 Step -1
              If GetGadgetItemState(#bgRandomAmbienceList, i)
                SetGadgetState(#bgRandomAmbienceListVolumeOffset, #maxVolume)
                DisableGadget(#bgRandomAmbienceListVolumeOffset, #True)
                playerGadgetPlaying(typeAmbience) = #False
                For j = i To CountGadgetItems(#bgRandomAmbienceList) - 2
                  playerGadgetInfoString(#bgRandomAmbienceList, j + 1) = playerGadgetInfoString(#bgRandomAmbienceList, j + 2)
                  playerGadgetVolume(#bgRandomAmbienceList, j + 1) = playerGadgetVolume(#bgRandomAmbienceList, j + 2)
                Next
                playerGadgetInfoString(#bgRandomAmbienceList, CountGadgetItems(#bgRandomAmbienceList)) = ""
                RemoveGadgetItem(#bgRandomAmbienceList, i)
                SetGadgetText(#bgRandomAmbienceListInfoOffset, "")
                playerGadgetSoundsCount(#bgRandomAmbienceList) = CountGadgetItems(#bgRandomAmbienceList)
              EndIf
            Next
            For i = CountGadgetItems(#oneshotSfx) - 1 To 0 Step -1
              If GetGadgetItemState(#oneshotSfx, i)
                SetGadgetState(#oneshotSfxVolumeOffset, #maxVolume)
                DisableGadget(#oneshotSfxVolumeOffset, #True)
                playerGadgetPlaying(typeOneShotSfx) = #False
                For j = i To CountGadgetItems(#oneshotSfx) - 2
                  playerGadgetInfoString(#oneshotSfx, j + 1) = playerGadgetInfoString(#oneshotSfx, j + 2)
                  playerGadgetVolume(#oneshotSfx, j + 1) = playerGadgetVolume(#oneshotSfx, j + 2)
                Next
                playerGadgetInfoString(#oneshotSfx, CountGadgetItems(#oneshotSfx)) = ""
                RemoveGadgetItem(#oneshotSfx, i)
                SetGadgetText(#oneshotSfxInfoOffset, "")
                playerGadgetSoundsCount(#oneshotSfx) = CountGadgetItems(#oneshotSfx)
              EndIf
            Next
            For i = CountGadgetItems(#loopSfx) - 1 To 0 Step -1
              If GetGadgetItemState(#loopSfx, i)
                SetGadgetState(#loopSfxVolumeOffset, #maxVolume)
                DisableGadget(#loopSfxVolumeOffset, #True)
                playerGadgetPlaying(typeLoopSfx) = #False
                For j = i To CountGadgetItems(#loopSfx) - 2
                  playerGadgetInfoString(#loopSfx, j + 1) = playerGadgetInfoString(#loopSfx, j + 2)
                  playerGadgetVolume(#loopSfx, j + 1) = playerGadgetVolume(#loopSfx, j + 2)
                Next
                playerGadgetInfoString(#loopSfx, CountGadgetItems(#loopSfx)) = ""
                RemoveGadgetItem(#loopSfx, i)
                SetGadgetText(#loopSfxInfoOffset, "")
                playerGadgetSoundsCount(#loopSfx) = CountGadgetItems(#loopSfx)
              EndIf
            Next
            For i = CountGadgetItems(#webMusics) - 1 To 0 Step -1
              If GetGadgetItemState(#webMusics, i)
                For j = i To CountGadgetItems(#webMusics) - 1
                  playerGadgetInfoString(#webMusics, j + 1) = playerGadgetInfoString(#webMusics, j + 2)
                  playerGadgetVolume(#webMusics, j + 1) = playerGadgetVolume(#webMusics, j + 2)
                Next
                playerGadgetInfoString(#webMusics, CountGadgetItems(#webMusics)) = ""
                RemoveGadgetItem(#webMusics, i)
                SetGadgetText(#webMusicsInfoOffset, "")
                playerGadgetSoundsCount(#webMusics) = CountGadgetItems(#webMusics)
              EndIf
            Next
            StopSounds()
          EndIf
        Case 12
          baseGadget = GetActiveGadget()
          If baseGadget > -1
            track = GetGadgetState(baseGadget)
            If track > -1
              PostEvent(#PB_Event_Gadget, #window, baseGadget + #playButtonOffset)
            EndIf
          EndIf
        Case 21
          If OpenWindow(#helpWindow, 0, 0, 800, 600, "Aide", #PB_Window_TitleBar|#PB_Window_MaximizeGadget|#PB_Window_MinimizeGadget|#PB_Window_SystemMenu)
            aideGadget = WebGadget(#PB_Any, 0, 0, 800, 600, dir$ + "Aide" + #Sep + "index.html")
            
            StickyWindow(#helpWindow, #True)
            
            Repeat
              event = WaitWindowEvent()
              
              Select event
                Case #PB_Event_CloseWindow
                  Break
                Case #PB_Event_SizeWindow
                  ResizeGadget(aideGadget, 0, 0, WindowWidth(#helpWindow, #PB_Window_InnerCoordinate), WindowHeight(#helpWindow, #PB_Window_InnerCoordinate))
              EndSelect
              
            ForEver
            
            CloseWindow(#helpWindow)
          EndIf
        Case 22
          MessageRequester("A propos...", "RPG Deejay, programmé par retro-bruno (c) 2018-2020", #PB_MessageRequester_Info)
        Case 101
          StopSounds()
        Case 102
          ; TODO: touche END
        Case 1001 To 1010
          ; appeler un ancien projet depuis le menu
          m1$ = GetMenuItemText(#menu, em)
          If m1$ <> ""
            Load(m1$)
          EndIf
        Case 1011
          ; vider et sauvegarder les préférences
          If CreatePreferences(dir$ + "config.ini")
            For i = 1 To 10
              WritePreferenceString("Projet " + Str(i), "")
              SetMenuItemText(#menu, i + 1000, "")
            Next
            ClosePreferences()
          EndIf
      EndSelect
      ; événements des gadgets
    Case #PB_Event_Gadget
      eGadget = EventGadget()
      baseGadget = eGadget
      eType = EventType()
      Select baseGadget
        Case #bgMusicVolumeOffset To #bgRandomAmbienceListVolumeOffset
          ; le gadget de base prend le numéro du gadget list    
          baseGadget - #volumeOffset
          ; récupérer la piste sélectionnée correspondant à son volume (qui est cliqué)
          track = GetGadgetState(baseGadget) + 1
          If track > CountGadgetItems(baseGadget)
            track = 0
          EndIf
          ; modifier le volume de la piste d'ambiance,
          ; s'il correspond au curseur de volume et à
          ; la piste sélectionnée
          If track > 0 And soundInstanceGadget(typeAmbience) = baseGadget And soundInstanceTrack(typeAmbience) = track
            playerGadgetVolume(baseGadget, track) = GetGadgetState(eGadget) ; on récupère la valeur du volume de son curseur              
            SetVolumeCustomSound(soundTypeAmbience, playerGadgetVolume(baseGadget, track))
          EndIf
        Case #oneshotSfxVolumeOffset          
          ; le gadget de base prend le numéro du gadget list    
          baseGadget - #volumeOffset
          ; changer le volume d'un son en temps réel
          If trackOneShotSound > 0
            If GetCustomSoundPlaying(soundTypeOneShotSfx)
              playerGadgetVolume(baseGadget, trackOneShotSound) = GetGadgetState(eGadget) ; on récupère la valeur du volume de son curseur
              SetVolumeCustomSound(soundTypeOneShotSfx, playerGadgetVolume(baseGadget, trackOneShotSound))
            Else
              playerGadgetVolume(baseGadget, GetGadgetState(baseGadget) + 1) = GetGadgetState(eGadget) ; on récupère la valeur du volume de son curseur
              SetVolumeCustomSound(soundTypeOneShotSfx, playerGadgetVolume(baseGadget, GetGadgetState(baseGadget) + 1))
            EndIf
          Else
              playerGadgetVolume(baseGadget, GetGadgetState(baseGadget) + 1) = GetGadgetState(eGadget) ; on récupère la valeur du volume de son curseur
              SetVolumeCustomSound(soundTypeOneShotSfx, playerGadgetVolume(baseGadget, GetGadgetState(baseGadget) + 1))
          EndIf
        Case #loopSfxVolumeOffset
          baseGadget - #volumeOffset
          ; récupérer un numéro de son manquant
          If trackLoopSound = 0
            trackLoopSound = GetGadgetState(baseGadget) + 1
            If trackLoopSound > CountGadgetItems(baseGadget)
              trackLoopSound = 0
            EndIf
          EndIf
          If trackLoopSound > 0
            If GetCustomSoundPlaying(soundTypeLoopSfx)
              playerGadgetVolume(baseGadget, trackLoopSound) = GetGadgetState(eGadget) ; on récupère la valeur du volume de son curseur
              SetVolumeCustomSound(soundTypeLoopSfx, playerGadgetVolume(baseGadget, trackLoopSound))
            EndIf
          EndIf
        Case #stopButton
          StopSounds()                   
        Case #bgMusicInfoOffset
          If eType = #PB_EventType_Change
            sel = GetGadgetState(#bgMusic)
            If sel > -1 And GetGadgetColor(#bgMusicTitleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
              playerGadgetInfoString(#bgMusic, sel + 1) = GetGadgetText(baseGadget)
            Else
              SetGadgetText(baseGadget, playerGadgetInfoString(#bgMusic, sel + 1))
            EndIf
          EndIf
        Case #bgAmbienceInfoOffset
          If eType = #PB_EventType_Change
            sel = GetGadgetState(#bgAmbience)
            If sel > -1 And GetGadgetColor(#bgAmbienceTitleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
              playerGadgetInfoString(#bgAmbience, sel + 1) = GetGadgetText(baseGadget)
            Else
              SetGadgetText(baseGadget, playerGadgetInfoString(#bgAmbience, sel + 1))
            EndIf
          EndIf
        Case #bgRandomAmbienceListInfoOffset
          If eType = #PB_EventType_Change
            sel = GetGadgetState(#bgRandomAmbienceList)
            If sel > -1 And GetGadgetColor(#bgRandomAmbienceListTitleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
              playerGadgetInfoString(#bgRandomAmbienceList, sel + 1) = GetGadgetText(baseGadget)
            Else
              SetGadgetText(baseGadget, playerGadgetInfoString(#bgRandomAmbienceList, sel + 1))
            EndIf
          EndIf
        Case #oneshotSfxInfoOffset
          If eType = #PB_EventType_Change
            sel = GetGadgetState(#oneshotSfx)
            If sel > -1 And GetGadgetColor(#oneshotSfxTitleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
              playerGadgetInfoString(#oneshotSfx, sel + 1) = GetGadgetText(baseGadget)
            Else
              SetGadgetText(baseGadget, playerGadgetInfoString(#oneshotSfx, sel + 1))
            EndIf
          EndIf
        Case #loopSfxInfoOffset
          If eType = #PB_EventType_Change
            sel = GetGadgetState(#loopSfx)
            If sel > -1 And GetGadgetColor(#loopSfxTitleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
              playerGadgetInfoString(#loopSfx, sel + 1) = GetGadgetText(baseGadget)
            Else
              SetGadgetText(baseGadget, playerGadgetInfoString(#loopSfx, sel + 1))
            EndIf
          EndIf
        Case #webMusicsInfoOffset
          If eType = #PB_EventType_Change
            sel = GetGadgetState(#webMusics)
            If sel > -1 And GetGadgetColor(#webMusicsTitleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
              playerGadgetInfoString(#webMusics, sel + 1) = GetGadgetText(baseGadget)
            Else
              SetGadgetText(baseGadget, playerGadgetInfoString(#webMusics, sel + 1))
            EndIf
          EndIf
        Case #soundTree
          eType = EventType()
          treeNumSound = GetGadgetState(#soundTree)
          level = GetGadgetItemAttribute(#soundTree, treeNumSound, #PB_Tree_SubLevel)
          If eType = #PB_EventType_DragStart
            Select level
              Case 1,2,3
                treeNumSound + 1
                DragText(GetGadgetText(#soundTree))
              Default
                level = 0
                treeNumSound = 0
            EndSelect
          ElseIf eType = #PB_EventType_LeftDoubleClick
            If treeNumSound > 0
              treeNumSound + 1
              If soundIsPath(treeNumSound) = #False
                FreeCustomSound(soundTypeList)
                If LoadCustomSound(soundPath$(treeNumSound), soundTypeList) = 0 : error("Impossible de charger le fichier sonore !") : EndIf
                ; on affiche le nom de piste en tooltip
                GadgetToolTip(eGadget, "En cours de jeu : " + Chr(34) + GetFilePart(soundPath$(treeNumSoundToPlay)) + Chr(34))
                PlayCustomSound(soundTypeList, 0, #maxVolume, 0, 0)
              EndIf
            EndIf
          ElseIf eType = #PB_EventType_RightClick
            If IsSound(soundTypeList)
              StopSound(soundTypeList)
              FreeSound(soundTypeList)
            EndIf
            ; ====================================================================================================
            CompilerIf #PB_Compiler_OS = #PB_OS_Windows
              If IsMp3(soundTypeList)
                mp3_stop(soundTypeList)
                mp3_free2(soundTypeList)
              EndIf
            CompilerEndIf
            ; ====================================================================================================
          EndIf
        Case #bgMusic To #bgRandomAmbienceList, #oneshotSfx, #loopSfx
          baseGadget = EventGadget()
          ;
          If baseGadget = #bgMusic Or baseGadget = #bgAmbience Or baseGadget = #bgRandomAmbienceList
            snd = soundTypeAmbience
          ElseIf baseGadget = #oneshotSfx
            snd = soundTypeOneShotSfx
          ElseIf baseGadget = #loopSfx
            snd = soundTypeLoopSfx
          EndIf
          ;
          If eType = #PB_EventType_LeftDoubleClick
            ; une piste est sélectionnée
            If GetGadgetState(baseGadget) > -1
              PostEvent(#PB_Event_Gadget, #window, baseGadget + #playButtonOffset)
            EndIf
          ElseIf eType = #PB_EventType_LeftClick
            ; désactiver temporairement les infos
            ; et les volumes
            If i <> #oneshotSfx And i <> #loopSfx
              For i = #bgMusic To #bgRandomAmbienceList
                DisableGadget(i + #infoOffset, #True)
                DisableGadget(i + #volumeOffset, #True)
              Next
            EndIf
            ; récupérer la piste sélectionnée actuellement
            track = GetGadgetState(baseGadget) + 1
            If track > CountGadgetItems(baseGadget)
              track = 0
            EndIf
            ; et le son lui correspondant, qui doit être recherché
            selSoundToPlay = 0
            ; rechercher le son en cours de jeu
            If track > 0
              f$ = GetGadgetItemText(baseGadget, track - 1)
              For i = 1 To CountGadgetItems(#soundTree)
                If soundIsPath(i) = #False
                  If GetFilePart(soundPath$(i)) = f$
                    selSoundToPlay = i
                    Break
                  EndIf
                EndIf
              Next
            EndIf
            ; instance du son visé
            inst.i ; initialisation des variables
            snd.i
            If baseGadget = #bgMusic Or baseGadget = #bgAmbience Or baseGadget = #bgRandomAmbienceList
              snd = soundTypeAmbience
            ElseIf baseGadget = #oneshotSfx
              snd = soundTypeOneShotSfx
            ElseIf baseGadget = #loopSfx
              snd = soundTypeLoopSfx
            EndIf
            inst = soundInstance(snd - #maxSounds)
            ; mettre à jour le volume de la piste sélectionnée
            If track > 0 And snd > 0
              SetGadgetState(baseGadget + #volumeOffset, playerGadgetVolume(baseGadget, track))
              If soundInstanceGadget(snd - #maxSounds) = baseGadget And soundInstanceTrack(snd - #maxSounds) = track
                SetVolumeCustomSound(snd, playerGadgetVolume(baseGadget, track))
              EndIf
            EndIf
            ; si le gadget cliqué fait partie de ceux qui gèrent l'audio d'ambiance, alors...
            If baseGadget = #bgMusic Or baseGadget = #bgAmbience Or baseGadget = #bgRandomAmbienceList
              ; si un numéro de musique est déjà défini, et que l'on vient de sélectionner une piste, probablement autre, alors...
              If selSoundToPlay > 0 And track > 0
                SetGadgetState(baseGadget + #volumeOffset, playerGadgetVolume(baseGadget, track))
                If soundInstanceGadget(snd - #maxSounds) = baseGadget And soundInstanceTrack(snd - #maxSounds) = track
                  DisableGadget(baseGadget + #volumeOffset, #False)
                Else
                  DisableGadget(baseGadget + #volumeOffset, #True)
                EndIf
              EndIf
              If baseGadget <> #bgMusic : SetGadgetState(#bgMusic, -1) : EndIf
              If baseGadget <> #bgAmbience : SetGadgetState(#bgAmbience, -1) : EndIf
              If baseGadget <> #bgRandomAmbienceList : SetGadgetState(#bgRandomAmbienceList, -1) : EndIf
              If GetGadgetState(baseGadget) = -1
                DisableGadget(#bgMusicInfoOffset, #True)
                DisableGadget(#bgAmbienceInfoOffset, #True)
                DisableGadget(#bgRandomAmbienceListInfoOffset, #True)
              EndIf
            ElseIf baseGadget = #oneshotSfx
              If GetGadgetState(baseGadget) > -1
                DisableGadget(baseGadget + #volumeOffset, #False)
              EndIf
            EndIf
            If GetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
              If GetGadgetState(baseGadget) > -1
                DisableGadget(baseGadget + #infoOffset, #False)
                SetGadgetText(baseGadget + #infoOffset, playerGadgetInfoString(baseGadget, track)) 
              EndIf
            EndIf
          EndIf
        Case #bgMusicPlayButtonOffset To #bgRandomAmbienceListPlayButtonOffset, #oneshotSfxPlayButtonOffset, #loopSfxPlayButtonOffset
          baseGadget - #playButtonOffset
          gState = GetGadgetState(baseGadget)
          track = gState + 1
          ; mise à jour du gadget qui va être désactivé
          ; et de celui qui va être activé
          ;
          ; le gadget de destination, dans tous les cas, devient celui dont on vient de lancer la lecture
          eTargetBGMusicGadget = baseGadget
          ; si aucun gadget source n'existe pour l'instant,
          If eSourceBGMusicGadget = -1
            ; le gadget source devient celui dont on vient de lancer la lecture
            eSourceBGMusicGadget = eTargetBGMusicGadget
          EndIf
                    
          ; il y a eu Doubleclick ou un Play
          If gState > -1
            ;
            f$ = GetGadgetItemText(baseGadget, gState)
            For i = 1 To CountGadgetItems(#soundTree)
              If soundIsPath(i) = #False
                If GetFilePart(soundPath$(i)) = f$
                  options = playerGadgetOptions(baseGadget)
                  ; musique ou son qui boucle, et que l'on joue au double clic, ou avec le bouton play. Pas de playlist qui se répète !
                  If (options & #isLooping) And (options & #playFullList) = 0 And (options & #playRandomFullList) = 0
                    ; si ce sont des musiques uniquement, et non des sons d'ambiance...
                    If baseGadget <> #loopSfx
                      ; essayer de jouer la nouvelle musique
                      sndPlaying = GetCustomSoundPlaying(soundTypeAmbience)
                      ; faut-il programmer le fadeout sur la piste jouée en cours ?
                      If sndPlaying = #True
                        ; le fadeout est-il déjà déclanché ?
                        If fadeMusicOn = #False
                          fadeVolume = playerGadgetVolume(eSourceBGMusicGadget, trackAmbienceSound)
                          trackAmbienceSound = track
                          soundOptions = options
                          treeNumSoundToPlay = i
                          ; désactive les gadgets d'ambiance, pour ne pas cliquer
                          ; sur d'autres musiques pendant le fadeout, ainsi que
                          ; leurs volumes
                          For j = #bgMusic To #bgRandomAmbienceList
                            DisableGadget(j, #True)
                            DisableGadget(j + #infoOffset, #True)
                            DisableGadget(j + #volumeOffset, #True)
                          Next
                          ; désactive le nom de la musique de destination dans ses infos
                          DisableGadget(eTargetBGMusicGadget + #infoOffset, #True)
                          fadeMusicOn = #True
                          AddWindowTimer(#window, 1, #fadeDelay)
                        EndIf
                        ; pas de fadeout, et aucun son d'ambiance en cours de jeu
                      Else
                        ; désactiver les listes de musiques (continues ou aléatoires)
                        ; et leurs texte d'infos
                        For j = 1 To #maxGadgets
                          If IsGadget(j)
                            If (playerGadgetOptions(j) & #playFullList) Or (playerGadgetOptions(j) & #playRandomFullList)
                              SetGadgetState(j, -1)
                              DisableGadget(j + #infoOffset, #True)
                            EndIf
                          EndIf
                        Next
                        If fadeMusicOn = #False
                          fadeVolume = 0
                          trackAmbienceSound = track
                          soundOptions = options
                          treeNumSoundToPlay = i
                          If eSourceBGMusicGadget > -1
                            SetGadgetState(eSourceBGMusicGadget, -1)
                            DisableGadget(eSourceBGMusicGadget + #infoOffset, #True)
                          EndIf
                          SetGadgetState(eTargetBGMusicGadget, track - 1)
                          DisableGadget(eTargetBGMusicGadget, #True)
                          DisableGadget(eTargetBGMusicGadget + #infoOffset, #True)
                          playerGadgetVolume(eTargetBGMusicGadget, track) = GetGadgetState(eTargetBGMusicGadget + #volumeOffset) ; on récupère la valeur du volume de son curseur              
                          
                          If baseGadget = #bgMusic Or baseGadget = #bgAmbience Or baseGadget = #bgRandomAmbienceList
                            If GetCustomSoundPlaying(soundTypeAmbience)
                              SetVolumeCustomSound(soundTypeAmbience, playerGadgetVolume(eTargetBGMusicGadget, track))
                            EndIf
                          ElseIf baseGadget = #oneshotSfx
                            If GetCustomSoundPlaying(soundTypeOneShotSfx)
                              SetVolumeCustomSound(soundTypeOneShotSfx, playerGadgetVolume(eTargetBGMusicGadget, track))
                            EndIf
                          ElseIf baseGadget = #loopSfx
                            If GetCustomSoundPlaying(soundTypeLoopSfx)
                              SetVolumeCustomSound(soundTypeLoopSfx, playerGadgetVolume(eTargetBGMusicGadget, track))
                            EndIf
                          EndIf
                          ; aller dans la fonction de fadeout pour rechercher et lancer le nouveau son à jouer
                          fadeMusicOn = #True
                          AddWindowTimer(#window, 1, #fadeDelay)
                        EndIf
                      EndIf
                    Else
                      ; récupérer le numéro de son dans la liste de gauche
                      treeNumSoundToPlayLoopSfx = i
                      ; un son joue en boucle ?
                      FreeCustomSound(soundTypeLoopSfx)
                      ; jouer un nouveau son ogg, flac, wav ou mp3
                      If LoadCustomSound(soundPath$(treeNumSoundToPlayLoopSfx), soundTypeLoopSfx) = 0 : error("Impossible de charger le fichier sonore !") : EndIf
                      ; on affiche le nom de piste en tooltip
                      GadgetToolTip(#loopSfx, "En cours de jeu : " + Chr(34) + GetFilePart(soundPath$(treeNumSoundToPlayLoopSfx)) + Chr(34))
                      PlayCustomSound(soundTypeLoopSfx, #PB_Sound_Loop, playerGadgetVolume(baseGadget, track), baseGadget, track)
                      DisableGadget(#loopSfxInfoOffset, #True)
                      DisableGadget(#loopSfxVolumeOffset, #False)
                      SetGadgetColor(#loopSfxTitleOffset, #PB_Gadget_BackColor, RGB(64, 192, 64))
                      SetGadgetText(#loopSfxInfoOffset, playerGadgetInfoString(#loopSfx, GetGadgetState(#loopSfx) + 1))
                    EndIf
                  ; playlist qui joue en boucle, avec ou sans randomisation
                  ElseIf ((options & #playFullList) Or (options & #playRandomFullList))
                    ; randomisation avec le bouton play, si aucune piste n'est sélectionnée
                    If track = 0 And (options & #playRandomFullList)
                      track = Random(CountGadgetItems(baseGadget), 1)
                    EndIf
                    ; récupérer le numéro de son à jouer
                    treeNumSoundToPlay = i
                    trackAmbienceSound = track
                    ; s'il y a une piste à jouer, alors...
                    If track > 0
                      ; désactiver les autres pistes sélectionnées
                      For j = #bgMusic To #loopSfx
                        SetGadgetState(j, -1)
                      Next
                      ; activer le gadget liste et la piste
                      SetActiveGadget(baseGadget)
                      SetGadgetState(baseGadget, track - 1)
                      ; repositionnement du curseur du volume
                      DisableGadget(baseGadget + #volumeOffset, #False)
                      SetGadgetState(baseGadget + #volumeOffset, playerGadgetVolume(baseGadget, track))
                      ; joue de l'ogg
                      FreeCustomSound(soundTypeAmbience)
                      If LoadCustomSound(soundPath$(treeNumSoundToPlay), soundTypeAmbience) = 0 : error("Impossible de charger le fichier sonore !") : EndIf
                      ; on affiche le nom de piste en tooltip
                      GadgetToolTip(baseGadget, "En cours de jeu : " + Chr(34) + GetFilePart(soundPath$(treeNumSoundToPlay)) + Chr(34))
                      ; on joue le son avec son volume, la boucle étant gérée ailleurs dans le code
                      PlayCustomSound(soundTypeAmbience, 0, playerGadgetVolume(baseGadget, track), baseGadget, track)
                      ; activer l'édition des infos
                      SetGadgetText(baseGadget + #infoOffset, playerGadgetInfoString(baseGadget, track))
                      DisableGadget(baseGadget + #infoOffset, #False)
                      ; changer le nom de la piste dans la statusbar
                      StatusBarText(1, 1, GetListViewName(baseGadget) + playerGadgetInfoString(baseGadget, track))
                      ;
                      SetGadgetColor(#bgMusicTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
                      SetGadgetColor(#bgAmbienceTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
                      SetGadgetColor(#bgRandomAmbienceListTitleOffset, #PB_Gadget_BackColor, RGB(64, 192, 64))
                      ;
                      eSourceBGMusicGadget = baseGadget
                    EndIf
                    ; son qui ne boucle pas, qui se joue au double clic ou au bouton play
                  ElseIf ~(options)
                    ; jouer les sons ogg ou mp3
                    FreeCustomSound(soundTypeOneShotSfx)
                    ; récupérer le numéro de son de la liste, et de piste à jouer
                    treeNumSoundToPlayOneShotSfx = i
                    trackOneShotSound = track
                    If LoadCustomSound(soundPath$(treeNumSoundToPlayOneShotSfx), soundTypeOneShotSfx) = 0 : error("Impossible de charger le fichier sonore !") : EndIf
                    ; on affiche le nom de piste en tooltip
                    GadgetToolTip(#oneshotSfx, "Vient de jouer : " + Chr(34) + GetFilePart(soundPath$(treeNumSoundToPlayOneShotSfx)) + Chr(34))
                    ; on joue le son oneshot
                    PlayCustomSound(soundTypeOneShotSfx, 0, playerGadgetVolume(baseGadget, trackOneShotSound), baseGadget, trackOneShotSound)
                    If GetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
                      SetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 192, 64))
                    EndIf
                    DisableGadget(baseGadget + #infoOffset, #True)
                    DisableGadget(baseGadget + #volumeOffset, #False)
                    SetGadgetText(baseGadget + #infoOffset, playerGadgetInfoString(baseGadget, trackOneShotSound))
                    If oneshotSoundFlag = #True
                      RemoveWindowTimer(#window, 3)
                    EndIf
                    oneshotSoundFlag = #True
                    AddWindowTimer(#window, 3, 50)
                    ; quitter la boucle
                    Break
                  EndIf
                EndIf
              EndIf
            Next
          ElseIf baseGadget = #bgRandomAmbienceList
            If CountGadgetItems(baseGadget) > 0
              ; récupérer la piste
              track = Random(CountGadgetItems(baseGadget), 1)
              ; désactiver les autres pistes sélectionnées
              For j = #bgMusic To #loopSfx
                SetGadgetState(j, -1)
              Next
              ; activer le gadget liste et la piste
              SetActiveGadget(baseGadget)
              SetGadgetState(baseGadget, track - 1)
              ;
              f$ = GetGadgetItemText(baseGadget, track - 1)
              For i = 1 To CountGadgetItems(#soundTree)
                If soundIsPath(i) = #False
                  If GetFilePart(soundPath$(i)) = f$
                    options = playerGadgetOptions(baseGadget)
                    If (options & #playRandomFullList)
                      treeNumSoundToPlay = i
                      FreeCustomSound(soundTypeAmbience)
                      If LoadCustomSound(soundPath$(treeNumSoundToPlay), soundTypeAmbience) = 0 : error("Impossible de charger le fichier sonore !") : EndIf
                      SetGadgetState(baseGadget, track - 1)
                      ; on affiche le nom de piste en tooltip
                      GadgetToolTip(baseGadget, "En cours de jeu : " + Chr(34) + GetFilePart(soundPath$(treeNumSoundToPlay)) + Chr(34))
                      PlayCustomSound(soundTypeAmbience, 0, playerGadgetVolume(baseGadget, track), baseGadget, track)
                      SetGadgetState(baseGadget + #volumeOffset, playerGadgetVolume(baseGadget, track))
                      DisableGadget(baseGadget + #volumeOffset, #False)
                      DisableGadget(baseGadget + #infoOffset, #True)
                      SetGadgetText(baseGadget + #infoOffset, playerGadgetInfoString(baseGadget, track))
                      SetGadgetColor(#bgMusicTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
                      SetGadgetColor(#bgAmbienceTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
                      SetGadgetColor(#bgRandomAmbienceListTitleOffset, #PB_Gadget_BackColor, RGB(64, 192, 64))
                      ; changer le nom de la piste dans la statusbar
                      StatusBarText(1, 1, GetListViewName(baseGadget) + playerGadgetInfoString(baseGadget, track))
                      Break
                    EndIf
                  EndIf
                EndIf
              Next
            EndIf
          EndIf
        Case #bgMusicStopButtonOffset, #bgAmbienceStopButtonOffset, #bgRandomAmbienceListStopButtonOffset
          baseGadget - #stopButtonOffset
          track = GetGadgetState(baseGadget) + 1
          ; vérifier si un son d'ambiance est actif
          flag = #False
          CompilerIf #PB_Compiler_OS = #PB_OS_Windows
            If IsMp3(soundTypeAmbience)
              flag = #True
            EndIf
          CompilerEndIf          
          If IsSound(soundTypeAmbience)
            flag = #True
          EndIf            
          If flag And eSourceBGMusicGadget = baseGadget And fadeMusicOn = #False            
            ; effacer le tooltip
            GadgetToolTip(baseGadget, "")
            FreeCustomSound(soundTypeAmbience)
            SetGadgetState(eSourceBGMusicGadget, -1)
            DisableGadget(eSourceBGMusicGadget + #infoOffset, #True)
            SetGadgetColor(eSourceBGMusicGadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
            ; supprimer le nom de la piste dans la statusbar
            StatusBarText(1, 1, "Aucune")
            fadeMusicOn = #False
            fadeVolume = playerGadgetVolume(gadget, track)
            soundOptions = 0
            treeNumSoundToPlay = 0
          EndIf
          DisableGadget(baseGadget + #volumeOffset, #True)
        Case #oneshotSfxStopButtonOffset, #loopSfxStopButtonOffset
          baseGadget - #stopButtonOffset
          For i = 1 To CountGadgetItems(baseGadget)
            tree.i
            num.i
            If baseGadget = #loopSfx
              tree = treeNumSoundToPlayLoopSfx
              snd = typeLoopSfx
              inst = soundInstance(snd)
            ElseIf baseGadget = #oneshotSfx
              tree = treeNumSoundToPlayOneShotSfx
              snd = typeOneShotSfx
              inst = soundInstance(snd)
            EndIf
            e$ = GetExtensionPart(soundPath$(tree))
            CompilerIf #PB_Compiler_OS = #PB_OS_Windows
              If e$ = "ogg" Or e$ = "flac" Or e$ = "wav" Or e$ = "mp3"
                FreeCustomSound(snd + #maxSounds)
                SetGadgetState(baseGadget, -1)
                DisableGadget(baseGadget + #infoOffset, #True)
                SetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
                Break
              EndIf
            CompilerElse
              If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
                FreeCustomSound(snd + #maxSounds)
                SetGadgetState(baseGadget, -1)
                DisableGadget(baseGadget + #infoOffset, #True)
                SetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
                Break
              EndIf
            CompilerEndIf
          Next
          DisableGadget(baseGadget + #volumeOffset, #True)
        Case #webMusics
          eType = EventType()
          If eType = #PB_EventType_LeftDoubleClick
            DisableGadget(baseGadget + #infoOffset, #True)
            If CountGadgetItems(baseGadget) > 0
              url$ = GetGadgetText(baseGadget)
              If IsWindow(#webWindow)
                CloseWindow(#webWindow)
                SetGadgetColor(#webMusicsTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
              EndIf
              If OpenWindow(#webWindow, 0, 0, 800, 600, "Musiques sur internet", #PB_Window_SystemMenu|#PB_Window_TitleBar|#PB_Window_ScreenCentered|#PB_Window_MinimizeGadget|#PB_Window_SizeGadget)
                WebGadget(#webMusicGadget, 0, 0, 800, 600, url$)
                SetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 192, 64))
                SetGadgetText(#webMusicsInfoOffset, playerGadgetInfoString(#webMusics, GetGadgetState(#webMusics) + 1))
              EndIf
            EndIf
          ElseIf eType = #PB_EventType_LeftClick
            If GetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
              DisableGadget(baseGadget + #infoOffset, #False)
              SetGadgetText(#webMusicsInfoOffset, playerGadgetInfoString(#webMusics, GetGadgetState(#webMusics) + 1))
            EndIf
          EndIf
        Case #webMusicsPlayButtonOffset
          baseGadget - #playButtonOffset
          DisableGadget(baseGadget + #infoOffset, #True)
          If CountGadgetItems(baseGadget) > 0
            url$ = GetGadgetText(baseGadget)
            If IsWindow(#webWindow)
              CloseWindow(#webWindow)
              SetGadgetColor(#webMusicsTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
            EndIf
            If OpenWindow(#webWindow, 0, 0, 800, 600, "Musiques sur internet", #PB_Window_SystemMenu|#PB_Window_TitleBar|#PB_Window_ScreenCentered|#PB_Window_MinimizeGadget|#PB_Window_SizeGadget)
              WebGadget(#webMusicGadget, 0, 0, 800, 600, url$)
              SetGadgetColor(#webMusicsTitleOffset, #PB_Gadget_BackColor, RGB(64, 192, 64))
              SetGadgetText(#webMusicsInfoOffset, playerGadgetInfoString(#webMusics, GetGadgetState(#webMusics) + 1))
            EndIf
          EndIf
        Case #webMusicsStopButtonOffset
          If IsWindow(#webWindow)
            CloseWindow(#webWindow)
            SetGadgetColor(#webMusicsTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
            DisableGadget(#webMusicsInfoOffset, #False)
          EndIf
      EndSelect      
    Case #PB_Event_GadgetDrop
      If EventDropType() = #PB_Drop_Text
        baseGadget = EventGadget()
        Select baseGadget
          Case #bgMusic, #bgAmbience, #bgRandomAmbienceList, #oneshotSfx, #loopSfx
            If playerGadgetSoundsCount(baseGadget) < #maxTracks
              If soundIsPath(treeNumSound) = #False
                AddGadgetItem(baseGadget, -1, EventDropText())
                playerGadgetInfoString(baseGadget, CountGadgetItems(baseGadget)) = GetFilePart(EventDropText(), #PB_FileSystem_NoExtension)
                playerGadgetVolume(baseGadget, CountGadgetItems(baseGadget)) = #maxVolume
                If GetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
                  SetGadgetText(baseGadget + #infoOffset, "")
                EndIf
                playerGadgetSoundsCount(baseGadget) = CountGadgetItems(baseGadget)
              Else
                For i = 1 To CountGadgetItems(#soundTree)
                  If GetGadgetItemText(#soundTree, i - 1) = EventDropText() And soundIsPath(i) = #True
                    treeNumSound = i + 1
                    Break
                  EndIf
                Next
                While treeNumSound <= CountGadgetItems(#soundTree)
                  If soundIsPath(treeNumSound) = #False
                    AddGadgetItem(baseGadget, -1, GetGadgetItemText(#soundTree, treeNumSound - 1))
                    playerGadgetInfoString(baseGadget, CountGadgetItems(baseGadget)) = GetFilePart(GetGadgetItemText(#soundTree, treeNumSound - 1), #PB_FileSystem_NoExtension)
                    playerGadgetVolume(baseGadget, CountGadgetItems(baseGadget)) = #maxVolume
                    If GetGadgetColor(baseGadget + #titleOffset, #PB_Gadget_BackColor) <> RGB(64, 192, 64)
                      SetGadgetText(baseGadget + #infoOffset, "")
                    EndIf
                    playerGadgetSoundsCount(baseGadget) = CountGadgetItems(baseGadget)
                  Else
                    Break
                  EndIf
                  treeNumSound + 1
                Wend
              EndIf
            EndIf
        EndSelect
      EndIf
    Case #PB_Event_Timer
      et = EventTimer()
      If et = 1
        ; fade out de la musique ou du son d'ambiance
        fadeVolume - 1
        ; le volume descend
        If fadeVolume >= 0
          SetVolumeCustomSound(soundTypeAmbience, fadeVolume)
          SetGadgetState(eSourceBGMusicGadget + #volumeOffset, fadeVolume)
          ; le volume était à zéro
        ElseIf fadeVolume = -1
          fadeVolume = 0
          fadeMusicOn = #False
          RemoveWindowTimer(#window, 1)
          ; réactiver les listes de musiques et de sons d'ambiance
          For j = #bgMusic To #bgRandomAmbienceList
            DisableGadget(j, #False)
          Next
          ;
          If eSourceBGMusicGadget > -1
            DisableGadget(eSourceBGMusicGadget + #volumeOffset, #True)
          EndIf
          ;
          DisableGadget(eTargetBGMusicGadget + #volumeOffset, #False)
          ;
          If GetGadgetState(eTargetBGMusicGadget) > -1
            DisableGadget(eTargetBGMusicGadget + #infoOffset, #False)
          EndIf
          ;
          FreeCustomSound(soundTypeAmbience)
          ; musiques ou sons qui bouclent, sans que la playlist ne s'écoule
          If (soundOptions & #isLooping) And (soundOptions & #playFullList) = 0 And (soundOptions & #playRandomFullList) = 0
            If LoadCustomSound(soundPath$(treeNumSoundToPlay), soundTypeAmbience) = 0 : error("Impossible de charger le fichier sonore !") : EndIf
            ; on met en place le volume de la piste lue
            SetGadgetState(eTargetBGMusicGadget + #volumeOffset, playerGadgetVolume(eTargetBGMusicGadget, GetGadgetState(eTargetBGMusicGadget) + 1))
            ; on affiche le nom de piste en tooltip
            GadgetToolTip(eTargetBGMusicGadget, "En cours de jeu : " + Chr(34) + GetFilePart(soundPath$(treeNumSoundToPlay)) + Chr(34))
            ; on joue le son d'ambiance
            PlayCustomSound(soundTypeAmbience, #PB_Sound_Loop, playerGadgetVolume(eTargetBGMusicGadget, GetGadgetState(eTargetBGMusicGadget) + 1), eTargetBGMusicGadget, GetGadgetState(eTargetBGMusicGadget) + 1)
            eSourceBGMusicGadget = eTargetBGMusicGadget
            SetGadgetColor(#bgMusicTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
            SetGadgetColor(#bgAmbienceTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
            SetGadgetColor(#bgRandomAmbienceListTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
            SetGadgetColor(eSourceBGMusicGadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 192, 64))
            SetGadgetText(eSourceBGMusicGadget + #infoOffset, playerGadgetInfoString(eSourceBGMusicGadget, track))
            ; changer le nom de la piste dans la statusbar
            StatusBarText(1, 1, GetListViewName(eSourceBGMusicGadget) + playerGadgetInfoString(eSourceBGMusicGadget, track))
          EndIf
        EndIf
      ElseIf et = 2 And fadeMusicOn = #False
        ; vérifier si un son d'ambiance est actif
        flag = #False
        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
          If IsMp3(soundTypeAmbience)
            flag = #True
          EndIf
        CompilerEndIf          
        If IsSound(soundTypeAmbience)
          flag = #True
        EndIf            
        ; Faire boucler sur plusieurs morceaux, au hasard ou linéairement
        For i = 1 To #maxGadgets
          If IsGadget(i) And flag
            If (playerGadgetOptions(i) & #playFullList)
              If GetCustomSoundPlaying(soundTypeAmbience) = #False And playerGadgetPlaying(typeAmbience) = #False
                FreeCustomSound(soundTypeAmbience)
                j = GetGadgetState(i)
                If j > CountGadgetItems(i) - 1 : j = 0 : EndIf
                SetGadgetState(i, j)
                DisableGadget(i + #infoOffset, #True)
                SetGadgetText(i + #infoOffset, playerGadgetInfoString(i, j + 1))
                SetGadgetState(i + #volumeOffset, playerGadgetVolume(i, j + 1))
                DisableGadget(i + #volumeOffset, #False)
                f$ = GetGadgetItemText(i, GetGadgetState(i))
                For j = 1 To CountGadgetItems(#soundTree)
                  If soundIsPath(j) = #False
                    If GetFilePart(soundPath$(j)) = f$
                      If LoadCustomSound(soundPath$(j), soundTypeAmbience) = 0 : error("Impossible de charger le fichier sonore !") : EndIf
                      ; on affiche le nom de piste en tooltip
                      GadgetToolTip(i, "En cours de jeu : " + Chr(34) + GetFilePart(soundPath$(j)) + Chr(34))
                      ;
                      PlayCustomSound(soundTypeAmbience, 0, playerGadgetVolume(i, GetGadgetState(i) + 1), i, GetGadgetState(i) + 1)
                      eSourceBGMusicGadget = i
                      treeNumSoundToPlay = j
                      trackAmbienceSound = GetGadgetState(i) + 1
                      Break
                    EndIf
                  EndIf
                Next
              EndIf
            ElseIf (playerGadgetOptions(i) & #playRandomFullList)
              If GetCustomSoundPlaying(soundTypeAmbience) = #False And playerGadgetPlaying(typeAmbience) = #False
                FreeCustomSound(soundTypeAmbience)
                If CountGadgetItems(i) > 0
                  j = Random(CountGadgetItems(i) - 1, 0)
                  SetGadgetState(i, j)
                  DisableGadget(i + #infoOffset, #True)
                  SetGadgetText(i + #infoOffset, playerGadgetInfoString(i, j + 1))
                  SetGadgetState(i + #volumeOffset, playerGadgetVolume(i, j + 1))
                  DisableGadget(i + #volumeOffset, #False)
                  f$ = GetGadgetItemText(i, GetGadgetState(i))
                  For j = 1 To CountGadgetItems(#soundTree)
                    If soundIsPath(j) = #False
                      If GetFilePart(soundPath$(j)) = f$
                        If LoadCustomSound(soundPath$(j), soundTypeAmbience) = 0 : error("Impossible de charger le fichier sonore !") : EndIf
                        ; on affiche le nom de piste en tooltip
                        GadgetToolTip(i, "En cours de jeu : " + Chr(34) + GetFilePart(soundPath$(j)) + Chr(34))
                        ;
                        PlayCustomSound(soundTypeAmbience, 0, playerGadgetVolume(i, GetGadgetState(i) + 1), i, GetGadgetState(i) + 1)
                        eSourceBGMusicGadget = i
                        treeNumSoundToPlay = j
                        trackAmbienceSound = GetGadgetState(i) + 1
                        Break
                      EndIf
                    EndIf
                  Next
                EndIf
              EndIf
            EndIf
          EndIf
        Next
      ElseIf et = 3
        ; eteindre le playerGadget oneshot
        If oneshotSoundFlag = #True
          e$ = GetExtensionPart(soundPath$(treeNumSoundToPlayOneShotSfx))
          If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
            If IsSound(soundTypeOneShotSfx)
              If SoundStatus(soundTypeOneShotSfx, soundInstance(typeOneShotSfx)) = #PB_Sound_Stopped
                oneshotSoundFlag = #False
                soundInstanceGadget(soundTypeOneShotSfx - #maxSounds) = 0
                soundInstanceTrack(soundTypeOneShotSfx - #maxSounds) = 0
                SetGadgetColor(#oneshotSfxTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
              EndIf
            EndIf
          Else
            ; ====================================================================================================
            CompilerIf #PB_Compiler_OS = #PB_OS_Windows
              If IsMp3(soundTypeOneShotSfx)
                If mp3_getstatus(soundTypeOneShotSfx) = #MP3_Stopped
                  oneshotSoundFlag = #False
                  soundInstanceGadget(soundTypeOneShotSfx - #maxSounds) = 0
                  soundInstanceTrack(soundTypeOneShotSfx - #maxSounds) = 0
                  SetGadgetColor(#oneshotSfxTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
                EndIf
              EndIf
            CompilerEndIf
            ; ====================================================================================================
          EndIf
        EndIf
      EndIf
  EndSelect
  
  Delay(2)
  
ForEver


; fin du programme
CloseWindow(#window)
End


; ====================================================================================================
; procedures
; ====================================================================================================

; ====================================================================================================
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Procedure CreatePlayer(gadget, x, y, width, height, title$, bgcol, options = 0)
    playerGadgetOptions(gadget) = options
    ListViewGadget(gadget, x, y + 40, width - 30, height - 40)
    SetGadgetColor(gadget, #PB_Gadget_BackColor, bgcol)
    SetGadgetColor(gadget, #PB_Gadget_FrontColor, RGB(0, 0, 0))
    ButtonGadget(gadget + #playButtonOffset, x + width - 80, y - 1, 40, 22, "PLAY", #PB_Button_Default)
    ButtonGadget(gadget + #stopButtonOffset, x + width - 40 - 1, y - 1, 40, 22, "STOP", #PB_Button_Default)
    StringGadget(gadget + #infoOffset, x, y + 20, width, 20, "", #PB_String_BorderLess)
    DisableGadget(gadget + #infoOffset, #True)
    TextGadget(gadget + #titleOffset, x, y, width - 80, 20, title$, #PB_Text_Center)
    SetGadgetColor(gadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
    SetGadgetColor(gadget + #titleOffset, #PB_Gadget_FrontColor, RGB(255, 255, 255))
    TrackBarGadget(gadget + #volumeOffset, x + width - 30, y + 40, 30, height - 40, 0, 100, #PB_TrackBar_Vertical)
    SetGadgetState(gadget + #volumeOffset, #maxVolume)
    DisableGadget(gadget + #volumeOffset, #True)
  EndProcedure
  Procedure ResizePlayer(gadget, x, y, width, height)
    ResizeGadget(gadget, x, y + 40, width - 30, height - 40)
    ResizeGadget(gadget + #playButtonOffset, x + width - 80, y - 1, 40, 22)
    ResizeGadget(gadget + #stopButtonOffset, x + width - 40 - 1, y - 1, 40, 22)
    ResizeGadget(gadget + #infoOffset, x, y + 20, width, 20)
    ResizeGadget(gadget + #titleOffset, x, y, width - 80, 20)
    ResizeGadget(gadget + #volumeOffset, x + width - 30, y + 40, 30, height - 40)
  EndProcedure
  ; ====================================================================================================
CompilerElseIf  #PB_Compiler_OS = #PB_OS_MacOS
  Procedure CreatePlayer(gadget, x, y, width, height, title$, bgcol, options = 0)
    playerGadgetOptions(gadget) = options
    ListViewGadget(gadget, x, y + 50, width - 30, height - 51)
    SetGadgetColor(gadget, #PB_Gadget_BackColor, bgcol)
    SetGadgetColor(gadget, #PB_Gadget_FrontColor, RGB(0, 0, 0))
    ButtonGadget(gadget + #playButtonOffset, x + width - 100 - 2, y - 2, 55, 30, "PLAY", #PB_Button_Default)
    ButtonGadget(gadget + #stopButtonOffset, x + width - 50 - 2, y - 2, 55, 30, "STOP", #PB_Button_Default)
    StringGadget(gadget + #infoOffset, x, y + 26, width, 25, "", #PB_String_BorderLess)
    DisableGadget(gadget + #infoOffset, #True)
    TextGadget(gadget + #titleOffset, x, y, width - 100, 25, title$, #PB_Text_Center)
    SetGadgetColor(gadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
    SetGadgetColor(gadget + #titleOffset, #PB_Gadget_FrontColor, RGB(255, 255, 255))
    TrackBarGadget(gadget + #volumeOffset, x + width - 30, y + 50, 30, height - 51, 0, 100, #PB_TrackBar_Vertical)
    SetGadgetState(gadget + #volumeOffset, #maxVolume)
    DisableGadget(gadget + #volumeOffset, #True)
  EndProcedure
  Procedure ResizePlayer(gadget, x, y, width, height)
    ResizeGadget(gadget, x, y + 50, width - 30, height - 51)
    ResizeGadget(gadget + #playButtonOffset, x + width - 100 - 2, y - 2, 55, 30)
    ResizeGadget(gadget + #stopButtonOffset, x + width - 50 - 2, y - 2, 55, 30)
    ResizeGadget(gadget + #infoOffset, x, y + 26, width, 25)
    ResizeGadget(gadget + #titleOffset, x, y, width - 100, 25)
    ResizeGadget(gadget + #volumeOffset, x + width - 30, y + 50, 30, height - 51)
  EndProcedure
  ; ====================================================================================================
CompilerElseIf  #PB_Compiler_OS = #PB_OS_Linux
  Procedure CreatePlayer(gadget, x, y, width, height, title$, bgcol, options = 0)
    playerGadgetOptions(gadget) = options
    ListViewGadget(gadget, x, y + 54, width - 30, height - 51)
    SetGadgetColor(gadget, #PB_Gadget_BackColor, bgcol)
    SetGadgetColor(gadget, #PB_Gadget_FrontColor, RGB(0, 0, 0))
    ButtonGadget(gadget + #playButtonOffset, x + width - 100, y - 1, 28, 25, "PLAY", #PB_Button_Default)
    ButtonGadget(gadget + #stopButtonOffset, x + width - 50 - 3, y - 1, 28, 25, "STOP", #PB_Button_Default)
    StringGadget(gadget + #infoOffset, x - 2, y + 27, width, 28, "", #PB_String_BorderLess)
    DisableGadget(gadget + #infoOffset, #True)
    TextGadget(gadget + #titleOffset, x, y + 1, width - 100, 27, title$, #PB_Text_Center)
    SetGadgetColor(gadget + #titleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
    SetGadgetColor(gadget + #titleOffset, #PB_Gadget_FrontColor, RGB(255, 255, 255))
    TrackBarGadget(gadget + #volumeOffset, x + width - 30, y + 54, 30, height - 55, 0, 100, #PB_TrackBar_Vertical)
    SetGadgetState(gadget + #volumeOffset, #maxVolume)
    DisableGadget(gadget + #volumeOffset, #True)
  EndProcedure
  Procedure ResizePlayer(gadget, x, y, width, height)
    ResizeGadget(gadget, x, y + 54, width - 30, height - 51)
    ResizeGadget(gadget + #playButtonOffset, x + width - 100, y - 1, 28, 25)
    ResizeGadget(gadget + #stopButtonOffset, x + width - 50 - 3, y - 1, 28, 25)
    ResizeGadget(gadget + #infoOffset, x - 2, y + 27, width, 28)
    ResizeGadget(gadget + #titleOffset, x, y + 1, width - 100, 27)
    ResizeGadget(gadget + #volumeOffset, x + width - 30, y + 54, 30, height - 55)
  EndProcedure
CompilerEndIf
; ====================================================================================================

Procedure StopSounds()
  ; effacer les tooltips
  GadgetToolTip(#bgMusic, "")
  GadgetToolTip(#bgAmbience, "")
  GadgetToolTip(#bgRandomAmbienceList, "")
  GadgetToolTip(#oneshotSfx, "")
  GadgetToolTip(#loopSfx, "")
  GadgetToolTip(#webMusics, "")
  
  For i = 0 To (3 * #maxSounds)
    If IsSound(i)
      StopSound(i)
      FreeSound(i)
    EndIf
    ; ====================================================================================================
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      If IsMp3(i)
        mp3_stop(i)
        mp3_free2(i)
      EndIf
    CompilerEndIf
    ; ====================================================================================================
  Next
  
  ; fermer la fenêtre de la liste web
  If IsWindow(#webWindow)
    CloseWindow(#webWindow)
  EndIf
    
  ; stopper les boucles en cours de jeu
  For i = 1 To 4
    soundInstance(i) = 0
  Next
  
  ; désactiver le fadeout et le jeu de la piste suivante
  fadeMusicOn = #False
  RemoveWindowTimer(#window, 1)
  
  ; désactiver les titres des listes
  SetGadgetColor(#bgMusicTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
  SetGadgetColor(#bgAmbienceTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))  
  SetGadgetColor(#bgRandomAmbienceListTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
  SetGadgetColor(#oneshotSfxTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
  SetGadgetColor(#loopSfxTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
  SetGadgetColor(#webMusicsTitleOffset, #PB_Gadget_BackColor, RGB(64, 64, 192))
  
  ; désactiver les infos des listes
  DisableGadget(#bgMusicInfoOffset, #True)
  DisableGadget(#bgAmbienceInfoOffset, #True)
  DisableGadget(#bgRandomAmbienceListInfoOffset, #True)
  DisableGadget(#oneshotSfxInfoOffset, #True)
  DisableGadget(#loopSfxInfoOffset, #True)
  DisableGadget(#webMusicsInfoOffset, #True)
  
  ; désélectionner les listes
  SetGadgetState(#bgMusic, -1)
  SetGadgetState(#bgAmbience, -1)
  SetGadgetState(#bgRandomAmbienceList, -1)
  SetGadgetState(#oneshotSfx, -1)
  SetGadgetState(#loopSfx, -1)
  SetGadgetState(#webMusics, -1)
  
  ; et les réactiver
  DisableGadget(#bgMusic, #False)
  DisableGadget(#bgAmbience, #False)
  DisableGadget(#bgRandomAmbienceList, #False)
  DisableGadget(#oneshotSfx, #False)
  DisableGadget(#loopSfx, #False)
  DisableGadget(#webMusics, #False)
  
EndProcedure

; procédure d'initialisation (ou de réinitialisation) du programme
Procedure New()
  
  StopSound(#PB_All)
  
  SetGadgetText(#bgMusicInfoOffset, "")
  SetGadgetText(#bgAmbienceInfoOffset, "")
  SetGadgetText(#bgRandomAmbienceListInfoOffset, "")
  SetGadgetText(#oneshotSfxInfoOffset, "")
  SetGadgetText(#loopSfxInfoOffset, "")
  SetGadgetText(#webMusicsInfoOffset, "")
  
  For i = 1 To CountGadgetItems(#bgMusic)
    playerGadgetInfoString(#bgMusic, i) = ""
    playerGadgetSoundsCount(#bgMusic) = 0
  Next
  
  For i = 1 To CountGadgetItems(#bgAmbience)
    playerGadgetInfoString(#bgAmbience, i) = ""
    playerGadgetSoundsCount(#bgAmbience) = 0
  Next
  
  For i = 1 To CountGadgetItems(#bgRandomAmbienceList)
    playerGadgetInfoString(#bgRandomAmbienceList, i) = ""
    playerGadgetSoundsCount(#bgRandomAmbienceList) = 0
  Next
  
  For i = 1 To CountGadgetItems(#oneshotSfx)
    playerGadgetInfoString(#oneshotSfx, i) = ""
    playerGadgetSoundsCount(#oneshotSfx) = 0
  Next
  
  For i = 1 To CountGadgetItems(#loopSfx)
    playerGadgetInfoString(#loopSfx, i) = ""
    playerGadgetSoundsCount(#loopSfx) = 0
  Next
  
  For i = 1 To CountGadgetItems(#webMusics)
    playerGadgetInfoString(#webMusics, i) = ""
  Next
  
  ClearGadgetItems(#bgMusic)
  ClearGadgetItems(#bgAmbience)
  ClearGadgetItems(#bgRandomAmbienceList)
  ClearGadgetItems(#oneshotSfx)
  ClearGadgetItems(#loopSfx)
  ClearGadgetItems(#webMusics)
  
  StopSounds()
  
  If IsSound(soundTypeList)
    StopSound(soundTypeList)
    FreeSound(soundTypeList)
  EndIf
  
  ; ====================================================================================================
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If IsMp3(soundTypeList)
      mp3_stop(soundTypeList)
      mp3_free2(soundTypeList)
    EndIf
  CompilerEndIf
  ; ====================================================================================================
  
  For i = 1 To CountGadgetItems(#soundTree)
    soundIsPath(i) = #False
    soundPath$(i) = ""
  Next
  
  ClearGadgetItems(#soundTree)
  AddGadgetItem(#soundTree, -1, "Liste des sons", ImageID(#dossier), 0)
  
  StatusBarText(1, 0, "Ambiance jouée :")
  StatusBarText(1, 1, "Aucune")
  
  changed = #False
  fadeMusicOn = #False
  fadeVolume = 0
  soundOptions = 0
  treeNumSoundToPlay = 0
  eSourceBGMusicGadget = -1
  eTargetBGMusicGadget = -1
  oneshotSoundFlag = #False
  
  For i = #bgMusic To #loopSfx
    For j = 1 To #maxTracks
      playerGadgetVolume(i, j) = #maxVolume
      SetGadgetState(i + #volumeOffset, playerGadgetVolume(i, j))
      DisableGadget(i + #volumeOffset, #True)
    Next
  Next
  
EndProcedure

Procedure.s GetFirstFolder(dir$)
  
  dir$ = ReverseString(dir$)
  dir$ = StringField(dir$, 2, #Sep)
  dir$ = ReverseString(dir$)
  
  ProcedureReturn dir$
  
EndProcedure

; procédure pour récupérer le nom du gadget listview
Procedure.s GetListViewName(gadget)
  
  Select gadget
    Case #bgMusic
      ProcedureReturn "(Musiques d'ambiance) "
    Case #bgAmbience
      ProcedureReturn "(Sons d'ambiance) "
    Case #bgRandomAmbienceList
      ProcedureReturn "(Playlist aléatoire) "
  EndSelect
  
EndProcedure

; procédure de chargement de playlist
Procedure Load(project.s = "")
  
  If project = ""
    fichier$ = OpenFileRequester("Ouvrir une playlist...", GetUserDirectory(#PB_Directory_Musics), "Fichier JPL *.jpl|*.jpl", 0)    
  ElseIf FileSize(project) > 0
    fichier$ = project
  Else
    fichier$ = ""
  EndIf
  
  If fichier$ <> ""
    
    If FileSize(fichier$) > 0 And GetExtensionPart(fichier$) = "jpl"
      
      If changed = #False Or (changed = #True And MessageRequester("Attention", "L'ensemble du projet courant sera perdu ! Voulez-vous continuer ?", #PB_MessageRequester_Warning|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes)
        
        New()
        
        changed = #True
        
        ; Chargement de l'arbre des sons
        If ReadFile(1, fichier$)
          
          PLcount = Val(ReadString(1))
          
          For i = 2 To PLcount
            
            soundPath$(i) = ReadString(1)
            soundIsPath(i) = Val(ReadString(1))
            pos = Val(ReadString(1))
            
            If soundIsPath(i) = #True
              ; si le répertoire du fichier Playlist n'existe pas...
              If FileSize(soundPath$(i)) = -1
                If #Sep = "\"
                  errSep$ = "/"
                Else
                  errSep$ = "\"
                EndIf
                soundPath$(i) = ReplaceString(soundPath$(i), errSep$, #Sep)
                sp$ = soundPath$(i)
                soundPath$(i) = GetPathPart(fichier$) + StringField(soundPath$(i), CountString(soundPath$(i), #Sep), #Sep) + #Sep + StringField(soundPath$(i), CountString(soundPath$(i), #Sep) + 1, #Sep)
                If FileSize(soundPath$(i)) <> -2
                  soundPath$(i) = sp$
                  soundPath$(i) = GetPathPart(fichier$) + StringField(soundPath$(i), CountString(soundPath$(i), #Sep) + 1, #Sep)
                  If FileSize(soundPath$(i)) <> -2
                    error("Impossible d'ouvrir le fichier Playlist !")
                    End  
                  EndIf
                EndIf
              EndIf
              ;
              AddGadgetItem(#soundTree, -1, GetFirstFolder(soundPath$(i)), ImageID(#dossier), pos)
            Else
              ; si le fichier Playlist n'existe pas...
              If FileSize(soundPath$(i)) = -1
                If #Sep = "\"
                  errSep$ = "/"
                Else
                  errSep$ = "\"
                EndIf
                soundPath$(i) = ReplaceString(soundPath$(i), errSep$, #Sep)
                sp$ = soundPath$(i)
                soundPath$(i) = GetPathPart(fichier$) + StringField(soundPath$(i), CountString(soundPath$(i), #Sep), #Sep) + #Sep + StringField(soundPath$(i), CountString(soundPath$(i), #Sep) + 1, #Sep)
                If FileSize(soundPath$(i)) <= 0
                  soundPath$(i) = sp$
                  soundPath$(i) = GetPathPart(fichier$) + StringField(soundPath$(i), CountString(soundPath$(i), #Sep) + 1, #Sep)
                  Debug(soundPath$(i))
                  If FileSize(soundPath$(i)) <= 0
                    error("Impossible d'ouvrir le fichier Playlist !")
                    End  
                  EndIf
                EndIf
              EndIf
              ;
              AddGadgetItem(#soundTree, -1, GetFilePart(soundPath$(i)), ImageID(#son), pos)
            EndIf
            
          Next
          
          SetGadgetItemState(#soundTree, 0, #PB_Tree_Expanded)
          
          For i = 1 To 6
            
            count = Val(ReadString(1))
            
            Select i
              Case 1
                gadget = #bgMusic
              Case 2
                gadget = #bgAmbience
              Case 3
                gadget = #bgRandomAmbienceList
              Case 4
                gadget = #oneshotSfx
              Case 5
                gadget = #loopSfx
              Case 6
                gadget = #webGadget
            EndSelect
            
            For j = 1 To count
              
              AddGadgetItem(gadget, j - 1, ReadString(1))
              playerGadgetInfoString(gadget, j) = ReadString(1)
              playerGadgetVolume(gadget, j) = Val(ReadString(1))
              
            Next
            
          Next
          
          CloseFile(1)
          
          InsertProjectFilename(fichier$)
          
        EndIf
        
        
      EndIf
      
    EndIf
    
  EndIf

EndProcedure

; procédure de sauvegarde de playlist
Procedure Save()
  
  fichier$ = SaveFileRequester("Enregistrer une playlist...", GetUserDirectory(#PB_Directory_Musics), "Fichier JPL *.jpl|*.jpl", 0)
  
  If fichier$ <> ""
    
    fichier$ = GetPathPart(fichier$) + GetFilePart(fichier$, #PB_FileSystem_NoExtension) + ".jpl"
    
    InsertProjectFilename(fichier$)
    
    If FileSize(fichier$) > 0
      
      If MessageRequester("Attention", "Le fichier existe déjà ! Voulez-vous le remplacer ?", #PB_MessageRequester_Warning|#PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
        
        ; sauvegarde de l'arbre des sons
        If CreateFile(1, fichier$)
          
          PLcount = CountGadgetItems(#soundTree)
          
          WriteStringN(1, Str(PLcount))
          
          For i = 2 To PLcount
            
            WriteStringN(1, soundPath$(i))
            WriteStringN(1, Str(soundIsPath(i)))
            WriteStringN(1, Str(GetGadgetItemAttribute(#soundTree, i - 1, #PB_Tree_SubLevel)))
            
          Next
          
          For i = 1 To 6
            
            Select i
              Case 1
                gadget = #bgMusic
              Case 2
                gadget = #bgAmbience
              Case 3
                gadget = #bgRandomAmbienceList
              Case 4
                gadget = #oneshotSfx
              Case 5
                gadget = #loopSfx
              Case 6
                gadget = #webGadget
            EndSelect
            
            count = CountGadgetItems(gadget)
            
            WriteStringN(1, Str(count))
            
            For j = 1 To count
              
              WriteStringN(1, GetGadgetItemText(gadget, j - 1))
              WriteStringN(1, playerGadgetInfoString(gadget, j))
              WriteStringN(1, Str(playerGadgetVolume(gadget, j)))
              
            Next
            
          Next
          
          CloseFile(1)
          
        EndIf
        
      EndIf
      
    ElseIf FileSize(fichier$) = -1
      
      ; sauvegarde de l'arbre des sons
      If CreateFile(1, fichier$)
        
        PLcount = CountGadgetItems(#soundTree)
        
        WriteStringN(1, Str(PLcount))
        
        For i = 2 To PLcount
          
          WriteStringN(1, soundPath$(i))
          WriteStringN(1, Str(soundIsPath(i)))
          WriteStringN(1, Str(GetGadgetItemAttribute(#soundTree, i - 1, #PB_Tree_SubLevel)))
          
        Next
        
        For i = 1 To 6
          
          Select i
            Case 1
              gadget = #bgMusic
            Case 2
              gadget = #bgAmbience
            Case 3
              gadget = #bgRandomAmbienceList
            Case 4
              gadget = #oneshotSfx
            Case 5
              gadget = #loopSfx
            Case 6
              gadget = #webGadget
          EndSelect
          
          count = CountGadgetItems(gadget)
          
          WriteStringN(1, Str(count))
          
          For j = 1 To count
            
            WriteStringN(1, GetGadgetItemText(gadget, j - 1))
            WriteStringN(1, playerGadgetInfoString(gadget, j))
            WriteStringN(1, Str(playerGadgetVolume(gadget, j)))
            
          Next
          
        Next
        
        CloseFile(1)
        
      EndIf
      
    EndIf
    
  EndIf
  
EndProcedure

Procedure.f Max(a.f, b.f)
  If a > b : ProcedureReturn a : EndIf
  ProcedureReturn b
EndProcedure

Procedure.f Min(a.f, b.f)
  If a < b : ProcedureReturn a : EndIf
  ProcedureReturn b
EndProcedure

Procedure error(err$)
  ; ====================================================================================================
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If mp3LoadErrorCode <> 277
      MessageRequester("Erreur", err$, #PB_MessageRequester_Error)
    Else
      MessageRequester("Erreur", err$ + " Le fichier mp3 ne peut être lu car il contient des Tags de droits d'auteur !", #PB_MessageRequester_Error)
    EndIf
    ; ====================================================================================================
  CompilerElse
    MessageRequester("Erreur", err$, #PB_MessageRequester_Error)
  CompilerEndIf
  ; ====================================================================================================
EndProcedure

; Remplacement des fonctions de chargement audio
Procedure.i LoadCustomSound(file$, snd)
  
  playerGadgetExtension(snd - #maxSounds) = GetExtensionPart(file$)
  
  playerGadgetPlaying(snd - #maxSounds) = #False
  
  e$ = playerGadgetExtension(snd - #maxSounds)
  If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
    If FileSize(file$) > 0
      ProcedureReturn LoadSound(snd, file$)
    Else
      error("Impossible de charger le son : " + file$)
    EndIf
  Else  
    ; ====================================================================================================
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      If FileSize(file$) > 0
        ProcedureReturn mp3_load(snd, file$)
      Else
        error("Impossible de charger le son : " + file$)
      EndIf
      ; ====================================================================================================
    CompilerElse
      ProcedureReturn 0
    CompilerEndIf
    ; ====================================================================================================
  EndIf
  
EndProcedure

; Remplacement des fonctions de lecture audio
Procedure.i PlayCustomSound(snd, flags, volume, gadget, track)
  
  If playerGadgetExtension(snd - #maxSounds) <> "mp3"
    soundInstance(snd - #maxSounds) = PlaySound(snd, flags | #PB_Sound_MultiChannel, volume)
    soundInstanceGadget(snd - #maxSounds) = gadget
    soundInstanceTrack(snd - #maxSounds) = track
    ProcedureReturn soundInstance(snd - #maxSounds)
  Else  
    ; ====================================================================================================
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      soundInstance(snd - #maxSounds) = mp3_play(snd, flags, volume)
      soundInstanceGadget(snd - #maxSounds) = gadget
      soundInstanceTrack(snd - #maxSounds) = track
      ProcedureReturn soundInstance(snd - #maxSounds)
    CompilerEndIf
    ; ====================================================================================================
  EndIf
  
  playerGadgetPlaying(snd - #maxSounds) = #True
  
EndProcedure

Procedure.i GetCustomSoundPlaying(snd)
  
  inst = soundInstance(snd - #maxSounds)
  
  e$ = playerGadgetExtension(snd - #maxSounds)
  If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
    If IsSound(snd)
      If SoundStatus(snd, inst) = #PB_Sound_Playing
        ProcedureReturn #True
      Else
        ProcedureReturn #False
      EndIf
    EndIf
  Else
    ; ====================================================================================================
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      If IsMp3(snd)
        If mp3_getstatus(snd) = #MP3_Playing
          ProcedureReturn #True
        Else
          ProcedureReturn #False
        EndIf
      EndIf
      ; ====================================================================================================
    CompilerElse
      ProcedureReturn #False
    CompilerEndIf
    ; ====================================================================================================
  EndIf
  
EndProcedure

; Remplacement de fonctions de changement de volume audio
Procedure SetVolumeCustomSound(snd, volume)
  
  inst = soundInstance(snd - #maxSounds)
  
  e$ = playerGadgetExtension(snd - #maxSounds)
  If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
    If IsSound(snd)
      If SoundStatus(snd, inst) = #PB_Sound_Playing
        SoundVolume(snd, volume, inst)
      EndIf
    EndIf 
  Else
    ; ====================================================================================================
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      If IsMp3(snd)
        If mp3_getstatus(snd) = #MP3_Playing
          mp3_setvolume(snd, volume)
        EndIf
      EndIf
      ; ====================================================================================================
    CompilerElse
      ProcedureReturn 0
    CompilerEndIf
    ; ====================================================================================================
  EndIf
  
EndProcedure

; Remplacement des fonctions de suppression des sons chargés
Procedure FreeCustomSound(snd)
  
  playerGadgetPlaying(snd - #maxSounds) = #False
  
  inst = soundInstance(snd - #maxSounds)
  
  e$ = playerGadgetExtension(snd - #maxSounds)
  If e$ = "ogg" Or e$ = "flac" Or e$ = "wav"
    If IsSound(snd)
      If SoundStatus(snd, inst) = #PB_Sound_Playing
        StopSound(snd)
      EndIf
      FreeSound(snd)
      soundInstance(snd - #maxSounds) = 0
      soundInstanceGadget(snd - #maxSounds) = 0
      soundInstanceTrack(snd - #maxSounds) = 0
    EndIf
  Else  
    ; ====================================================================================================
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      If IsMp3(snd)
        If mp3_getstatus(snd) = #MP3_Playing
          mp3_stop(snd)
        EndIf
      EndIf
      mp3_free2(snd)
      soundInstance(snd - #maxSounds) = 0
      soundInstanceGadget(snd - #maxSounds) = 0
      soundInstanceTrack(snd - #maxSounds) = 0
      ; ====================================================================================================
    CompilerElse
      ProcedureReturn 0
    CompilerEndIf
    ; ====================================================================================================
  EndIf
  
EndProcedure

Procedure ScaleWindow()
  
  ; redimensionner les gadgets selon la fenêtre
  ResizeGadget(#stopButton, 0, 0, Int(winWidth / 4), 25)
  ResizeGadget(#soundTree, 0, 25, Int(winWidth / 4), winHeight - StatusBarHeight(1) - GadgetHeight(#stopButton) + 3 - StatusBarHeight(1))
  
  wh = winHeight - MenuHeight() - 1 - StatusBarHeight(1)
  
  ResizePlayer(#bgMusic, (Int(winWidth / 4) * 1) + 1, 0, Int(winWidth / 4), Int(wh / 2))
  ResizePlayer(#bgAmbience, (Int(winWidth / 4) * 1) + 1, Int(wh / 2) + 1, Int(winWidth / 4), Int(wh / 2))
  ResizePlayer(#bgRandomAmbienceList, (Int(winWidth / 4) * 2) + 1, 0, Int(winWidth / 4), Int(wh / 2))
  ResizePlayer(#webMusics, (Int(winWidth / 4) * 2) + 1, Int(wh / 2) + 1, Int(winWidth / 4), Int(wh / 2))
  ResizePlayer(#oneshotSfx, (Int(winWidth / 4) * 3) + 1, 0, Int(winWidth / 4), Int(wh / 2))
  ResizePlayer(#loopSfx, (Int(winWidth / 4) * 3) + 1, Int(wh / 2) + 1, Int(winWidth / 4), Int(wh / 2))
  
  ; ====================================================================================================
  ; affichage correct de la fenêtre sous Windows
  ; ====================================================================================================
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    UpdateWindow_(WindowID(#window))
  CompilerEndIf
  ; ====================================================================================================
  
EndProcedure

Procedure InsertProjectFilename(m1$)
  
  ; rechercher l'élément dans la liste
  em = 0
  For i = 1001 To 1010
    If m1$ = GetMenuItemText(#menu, i)
      em = i
      Break
    EndIf
  Next
  
  ; s'il s'agit de l'insertion d'un nouvel élément
  If em = 0
    ; décaler toute la liste vers le bas
    For i = 1009 To 1001 Step -1
      SetMenuItemText(#menu, i + 1, GetMenuItemText(#menu, i))
    Next
    ; insérer le menu en 1ère place
    SetMenuItemText(#menu, 1001, m1$)
  ; si l'élément inséré existe déjà dans la liste
  Else
    ; décaler une partie de la liste vers le bas
    For i = em - 1 To 1001 Step -1
      SetMenuItemText(#menu, i + 1, GetMenuItemText(#menu, i))
    Next
    ; insérer le menu en 1ère place
    SetMenuItemText(#menu, 1001, m1$)
  EndIf
    
  ; sauvegarder les préférences
  If CreatePreferences(dir$ + "config.ini")
    For i = 1 To 10
      WritePreferenceString("Projet " + Str(i), GetMenuItemText(#menu, i + 1000))
    Next
    ClosePreferences()
  EndIf
  
EndProcedure
; IDE Options = PureBasic 5.73 LTS (Windows - x64)
; CursorPosition = 1440
; FirstLine = 1420
; Folding = ---------
; EnableXP
; UseIcon = icones\icon.ico
; Executable = RPG Deejay.exe