
; PoE1 build panels and per-zone splits for the Exile UI Act-Tracker.
BuildGuide_Init()
{
    global vars, BuildGuide, db
    FileCreateDir, build-guide
    BuildGuide := {directory: "build-guide", tab: 6, stage: 1, profile: "", run: ""
        , preferenceFile: "ini\leveling tracker.ini"}
    BuildGuide.leveling := LLK_IniRead(BuildGuide.preferenceFile, "Overlay", "campanha", 1)
    BuildGuide_LoadCached()
    Menu, Tray, Add, Abrir painel, BuildGuide_Open
    Menu, Tray, Default, Abrir painel
    Menu, Tray, Add, Atalhos (Ctrl+L), BuildGuide_ToggleHelp
    if !vars.poe_version
    {
        if !IsObject(db.leveltracker)
            DB_Load("leveltracker")
        SetTimer, BuildGuide_Tick, 250
    }
}


BuildGuide_ImportDialog()
{
    global BGSource
    Gui, BGImporter: Destroy
    Gui, BGImporter: New, +AlwaysOnTop +ToolWindow, NerdMítico Jr. | Importar PoB
    BuildGuide_Theme("BGImporter")
    Gui, BGImporter: Font, s16 w700 cEBC461
    Gui, BGImporter: Add, Text, w480, Importar build
    Gui, BGImporter: Font, s10 w400 cF2EAF9
    Gui, BGImporter: Add, Text, w480, Cole o link pobb.in ou o código exportado do Path of Building.
    Gui, BGImporter: Add, Edit, w480 r3 vBGSource
    Gui, BGImporter: Add, Button, w112 Default gBGImportCode, Importar
    Gui, BGImporter: Add, Button, x+8 w155 gBGImportFile, Escolher XML
    Gui, BGImporter: Show
}

BGImportCode()
{
    GuiControlGet, source, BGImporter:, BGSource
    if Trim(source)
        BuildGuide_ImportFrom(source)
}

BGImportFile()
{
    Gui, BGImporter: +OwnDialogs
    FileSelectFile, path, 3,, Abrir exportação PoB, Exportação PoB (*.xml; *.txt; *.pob)
    if ErrorLevel
        return
    FileRead, source, *P65001 %path%
    if !ErrorLevel
        BuildGuide_ImportFrom(source)
}

BuildGuide_ImportFrom(source)
{
    try
        BuildGuide_Import(source)
    catch error
    {
        MsgBox, 48, Importação do PoB, % error.Message
        return
    }
    Gui, BGImporter: Destroy
    BuildGuide_ChooseTab(1)
}

BGOpenPreferences()
{
    BuildGuide_ChooseTab(7)
}

BGImporterGuiClose:
BGImporterGuiEscape:
Gui, BGImporter: Destroy
return

BuildGuide_Decode(source)
{
    source := Trim(source, " " . Chr(9) . Chr(10) . Chr(13) . Chr(0xFEFF))
    if RegExMatch(source, "i)^(?:https://)?(?:www\.)?pobb\.in/([a-z0-9_-]{4,100})(?:/raw)?/?(?:[?#].*)?$", url)
    {
        try
        {
            request := ComObjCreate("WinHttp.WinHttpRequest.5.1")
            request.SetTimeouts(5000, 5000, 5000, 10000)
            request.Open("GET", "https://pobb.in/" url1 "/raw", false)
            request.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36")
            request.Send()
            if (request.Status != 200)
                throw Exception("HTTP " request.Status)
            source := Trim(request.ResponseText, " " . Chr(9) . Chr(10) . Chr(13))
        }
        catch error
            throw Exception("Falha ao abrir o pobb.in. Importe o XML ou o código do PoB. (" error.Message ")")
    }
    if (StrLen(source) > 10485760)
        throw Exception("Exportação maior que 10 MB.")
    if (SubStr(source, 1, 1) = "<")
        return source

    source := RegExReplace(source, "\s")
    if !RegExMatch(source, "^[a-zA-Z0-9+/_-]+={0,2}$")
        throw Exception("Link ou código de exportação inválido.")
    source := StrReplace(StrReplace(source, "-", "+"), "_", "/")
    while Mod(StrLen(source), 4)
        source .= "="
    length := Base64Dec(source, compressed)
    size := length ? zlib_Decompress(decoded, compressed, length, 10485760) : 0
    if !size
        throw Exception("Não foi possível descompactar o código PoB.")
    return StrGet(&decoded, size, "UTF-8")
}

BuildGuide_Parse(xml)
{
    doc := ComObjCreate("Msxml2.DOMDocument.6.0")
    doc.async := false
    doc.resolveExternals := false
    doc.setProperty("ProhibitDTD", true)
    if !doc.loadXML(xml)
        throw Exception("XML inválido na linha " doc.parseError.line ".")
    if (doc.documentElement.nodeName != "PathOfBuilding")
        throw Exception("Use uma exportação do Path of Building de PoE 1.")

    build := doc.selectSingleNode("/PathOfBuilding/Build")
    if !IsObject(build)
        throw Exception("A exportação não contém os dados da build.")
    className := build.getAttribute("className")
    StringLower, className, className
    treeList := doc.selectSingleNode("/PathOfBuilding/Tree")
    activeTree := IsObject(treeList) ? treeList.getAttribute("activeSpec") + 0 : 0
    guide := {class: className, items: {}, trees: [], skills: [], sets: [], stages: [], activeTree: Max(1, activeTree)}
    for node in doc.selectNodes("/PathOfBuilding/Items/Item")
        guide.items[node.getAttribute("id") + 0] := BuildGuide_Item(node.text)
    for node in doc.selectNodes("/PathOfBuilding/Items/ItemSet")
        guide.sets.Push(BuildGuide_ItemSet(node, guide.sets.Count() + 1))
    if !guide.sets.Count()
    {
        node := doc.selectSingleNode("/PathOfBuilding/Items")
        if IsObject(node)
            guide.sets.Push(BuildGuide_ItemSet(node, 1))
    }
    for node in doc.selectNodes("/PathOfBuilding/Tree/Spec")
    {
        sockets := {}
        for socket in node.selectNodes("./Sockets/Socket")
        {
            id := socket.getAttribute("itemId") + 0
            if (id > 0)
                sockets[socket.getAttribute("nodeId") + 0] := id
        }
        title := "" node.getAttribute("title")
        guide.trees.Push({title: title, version: "" node.getAttribute("treeVersion"), sockets: sockets
            , nodes: "" node.getAttribute("nodes"), masteries: BuildGuide_ParseMasteries(node.getAttribute("masteryEffects"))})
    }
    for node in doc.selectNodes("/PathOfBuilding/Skills/SkillSet")
        guide.skills.Push(BuildGuide_SkillSet(node, guide.skills.Count() + 1))
    if !guide.skills.Count()
    {
        node := doc.selectSingleNode("/PathOfBuilding/Skills")
        if IsObject(node)
            guide.skills.Push(BuildGuide_SkillSet(node, 1))
    }

    ; Named skill transitions anchor the timeline. Tree-only builds use their tree stages.
    anchors := guide.skills.Count() > 1 ? guide.skills : guide.trees.Count() > 1 ? guide.trees
        : guide.skills.Count() ? guide.skills : guide.sets
    if !anchors.Count()
        throw Exception("Não há etapas, skills ou equipamentos para mostrar.")
    for index, anchor in anchors
    {
        act := BuildGuide_Act(anchor.title)
        stage := {title: anchor.title ? anchor.title : "Etapa " index, act: act
            , skill: anchors == guide.skills ? index : BuildGuide_Match(anchor.title, act, guide.skills)
            , gear: anchors == guide.sets ? index : BuildGuide_Match(anchor.title, act, guide.sets)
            , tree: anchors == guide.trees ? index : BuildGuide_Match(anchor.title, act, guide.trees)}
        guide.stages.Push(stage)
    }
    return guide
}

BuildGuide_ParseMasteries(value)
{
    result := {}, position := 1
    while (position := RegExMatch(value, "\{(\d+),\s*(\d+)\}", pair, position))
    {
        result[pair1 + 0] := pair2 + 0
        position += StrLen(pair)
    }
    return result
}

BuildGuide_ItemSet(node, index)
{
    title := "" node.getAttribute("title")
    result := {title: title ? title : "Equipamento " index, slots: []}
    for slot in node.selectNodes("./Slot")
    {
        name := "" slot.getAttribute("name")
        id := slot.getAttribute("itemId") + 0
        if (id > 0 && !RegExMatch(name, "i)^(?:AG |Animate Guardian)"))
            result.slots.Push({name: name, id: id})
    }
    return result
}

BuildGuide_SkillSet(node, index)
{
    title := "" node.getAttribute("title")
    result := {title: title ? title : "Gemas " index, groups: []}
    for skill in node.selectNodes("./Skill[not(@enabled='false')]")
    {
        group := {slot: "" skill.getAttribute("slot"), title: "" skill.getAttribute("label"), gems: []}
        for gem in skill.selectNodes("./Gem[not(@enabled='false')]")
        {
            name := "" gem.getAttribute("nameSpec")
            if (name = "")
                continue
            support := InStr(gem.getAttribute("gemId"), "/SupportGem") || RegExMatch(name, "i) Support$")
            count := gem.getAttribute("count")
            group.gems.Push({name: name, support: support, count: count > 0 ? count + 0 : 1})
        }
        if group.gems.Count()
            result.groups.Push(group)
    }
    return result
}

BuildGuide_Item(raw)
{
    lines := StrSplit(Trim(raw, " " . Chr(9) . Chr(10) . Chr(13)), Chr(10), Chr(13))
    rarity := Trim(SubStr(lines[1], 8), " " . Chr(9) . Chr(13))
    named := (rarity = "RARE" || rarity = "UNIQUE" || rarity = "RELIC")
    result := {name: Trim(lines[2]), base: Trim(lines[named ? 3 : 2]), rarity: rarity
        , mods: [], implicits: [], rolls: [], sockets: ""}
    variant := "", implicit := 0, reading := false
    for index, line in lines
    {
        if (index <= (named ? 3 : 2))
            continue
        line := Trim(line)
        if RegExMatch(line, "^Selected Variant: (\d+)", match)
            variant := match1
        if RegExMatch(line, "^Sockets: (.+)", match)
            result.sockets := match1
        if RegExMatch(line, "^Implicits: (\d+)", match)
        {
            implicit := match1 + 0, reading := true
            continue
        }
        if !reading || line = "" || RegExMatch(line, "i)^(Corrupted|Mirrored|Split|Unmodifiable)$")
            continue
        isImplicit := implicit > 0
        if isImplicit
            implicit -= 1
        if RegExMatch(line, "\{variant:([\d,]+)\}", match) && variant != ""
            && !InStr("," match1 ",", "," variant ",")
            continue
        variable := RegExMatch(line, "\{range:") || RegExMatch(line, "\(\d+(?:\.\d+)?-\d")
        clean := RegExReplace(line, "\{[^}]+\}")
        if (Trim(clean) = "")
            continue
        if isImplicit
            result.implicits.Push(clean)
        else
            result.mods.Push(clean)
        if variable && !isImplicit
            result.rolls.Push(clean)
    }
    return result
}

BuildGuide_Act(title)
{
    return RegExMatch(title, "i)\b(?:acts?|atos?)\s*(10|[1-9])\b", match) ? match1 + 0 : 0
}

BuildGuide_StageTag(title, id)
{
    return RegExMatch(title, "\{([\d, ]+)\}", tag) && InStr("," StrReplace(tag1, " ") ",", "," id ",")
}

BuildGuide_Match(title, act, candidates)
{
    if (candidates.Count() = 1)
        return 1
    if RegExMatch(title, "\{(\d+)\}", tag)
        for index, candidate in candidates
            if BuildGuide_StageTag(candidate.title, tag1)
                return index
    clean := Trim(RegExReplace(title, "\{[\d, ]+\}"))
    if (clean != "")
        for index, candidate in candidates
            if (Trim(RegExReplace(candidate.title, "\{[\d, ]+\}")) = clean)
                return index
    if act
        for index, candidate in candidates
            if RegExMatch(candidate.title, "i)\b(?:acts?|atos?)\s*(10|[1-9])(?:\s*[-–]\s*(10|[1-9]))?\b", match)
                && act >= match1 && act <= (match2 ? match2 : match1)
                return index
    return 0
}

BuildGuide_Write(path, contents)
{
    file := FileOpen(path ".tmp", "w", "UTF-8")
    if !IsObject(file)
        throw Exception("Não foi possível gravar " path)
    written := file.Write(contents)
    file.Close()
    if (written < StrPut(contents, "UTF-8") - 1)
        throw Exception("Gravação incompleta em " path)
    FileMove, % path ".tmp", %path%, 1
    if ErrorLevel
        throw Exception("Não foi possível substituir " path)
}

BuildGuide_LoadCached()
{
    global BuildGuide, vars, settings
    profile := settings.leveltracker.profile
    ; The native profile is read in Tick after its settings are initialized.
    BuildGuide.profile := profile, BuildGuide.lastAct := 0
    cache := BuildGuide.directory "\pob-" (profile ? profile : "1") ".xml"
    BuildGuide.guide := "", BuildGuide.stage := 1, BuildGuide.manual := 0, BuildGuide.priorities := {}
    BuildGuide.treeTarget := 0, BuildGuide.levelingKey := ""
    if FileExist(cache)
    {
        FileRead, raw, *P65001 %cache%
        try BuildGuide.guide := BuildGuide_Parse(raw)
    }
    path := BuildGuide.directory "\prioridades-" (profile ? profile : "1") ".json"
    if FileExist(path)
    {
        FileRead, raw, *P65001 %path%
        try BuildGuide.priorities := JSON.Load(raw)
    }
}

BuildGuide_Import(source)
{
    global BuildGuide, vars, settings, db
    xml := BuildGuide_Decode(source)
    guide := BuildGuide_Parse(xml)
    ; Native routing and tree rendering consume the original export envelope.
    code := BuildGuide_Encode(xml)
    profile := settings.leveltracker.profile
    if !IsObject(db.leveltracker)
        DB_Load("leveltracker")
    if !IsObject(Leveltracker_PobImport(code, profile))
        throw Exception("O Act-Tracker não conseguiu importar a build.")
    path := BuildGuide.directory "\pob-" (profile ? profile : "1") ".xml"
    BuildGuide_Write(path, xml)
    Gui, BGEditor: Destroy
    BuildGuide.routeProfile := -1
    BuildGuide.treeTarget := 0, BuildGuide.levelingKey := ""
    BuildGuide.guide := guide, BuildGuide.stage := 1, BuildGuide.manual := 0, BuildGuide.lastAct := 0
    BuildGuide_SetAct(vars.log.act)
    Init_leveltracker()
    Leveltracker_ProgressReset(profile)
}

BuildGuide_Encode(xml)
{
    utf8Length := StrPut(xml, "UTF-8") - 1
    VarSetCapacity(utf8, utf8Length + 1)
    StrPut(xml, &utf8, utf8Length + 1, "UTF-8")
    bound := DllCall("data\zlib1\compressBound", "UInt", utf8Length, "UInt")
    VarSetCapacity(compressed, bound)
    status := DllCall("data\zlib1\compress", "Ptr", &compressed, "UIntP", bound, "Ptr", &utf8, "UInt", utf8Length)
    if status
        throw Exception("Falha ao compactar a exportação PoB.")
    flags := 0x40000001
    DllCall("Crypt32\CryptBinaryToStringW", "Ptr", &compressed, "UInt", bound, "UInt", flags, "Ptr", 0, "UIntP", chars := 0)
    VarSetCapacity(encoded, chars * 2)
    if !DllCall("Crypt32\CryptBinaryToStringW", "Ptr", &compressed, "UInt", bound, "UInt", flags, "Ptr", &encoded, "UIntP", chars)
        throw Exception("Falha ao codificar a exportação PoB.")
    return StrReplace(StrReplace(StrGet(&encoded, "UTF-16"), "+", "-"), "/", "_")
}

BuildGuide_Open()
{
    BuildGuide_DrawPanel(true)
}

BuildGuide_Step(delta)
{
    global BuildGuide
    if !IsObject(BuildGuide.guide)
        return
    BuildGuide.stage := Min(BuildGuide.guide.stages.Count(), Max(1, BuildGuide.stage + delta))
    BuildGuide.manual := 1
}

BuildGuide_ChooseTab(index)
{
    global BuildGuide
    BuildGuide.tab := index
    BuildGuide_Open()
}


BuildGuide_DrawPanel(focus := false)
{
    global BuildGuide, vars, settings, BGStageTitle, BGText, BGTime, BGSection, BGContext
    global BGRouteMode, BGRouteGems, BGRouteOptional, BGRouteBandit, BGProfile
    global BGMark1, BGMark2, BGMark3, BGMark4, BGMark5, BGMark6, BGMark7
    global BGNav1, BGNav2, BGNav3, BGNav4, BGNav5, BGNav6, BGNav7

    global BGPrefModeLabel, BGPrefProfileLabel, BGPrefBanditLabel
    guide := BuildGuide.guide
    stage := IsObject(guide) ? guide.stages[BuildGuide.stage] : ""
    page := BuildGuide.tab
    sections := ["Gemas e links", "Equipamento", "Frascos", "Joias", "Tempos", "Campanha", "Preferências"]
    if !BuildGuide.panel || !DllCall("IsWindow", "Ptr", BuildGuide.panel)
    {
        Gui, BGPanel: New, +AlwaysOnTop +ToolWindow +Hwndpanel, NerdMítico Jr. | PoE Leveling Overlay
        BuildGuide_Theme("BGPanel", panel)
        Gui, BGPanel: Add, Progress, x0 y0 w172 h557 Background1D1429 c1D1429 Disabled, 100
        Gui, BGPanel: Add, Picture, x18 y19 w42 h42, img\GUI\nerdmitico.png
        Gui, BGPanel: Font, s11 w700 cEBC461, Segoe UI
        Gui, BGPanel: Add, Text, x70 y22 w100 h19 BackgroundTrans, NerdMítico Jr.
        Gui, BGPanel: Font, s8 w400 cC6B5D8
        Gui, BGPanel: Add, Text, x70 y43 w100 h17 BackgroundTrans, LEVELING OVERLAY
        for row, index in [6, 1, 2, 3, 4, 5, 7]
        {
            y := 88 + (row - 1) * 43
            Gui, BGPanel: Add, Progress, % "x12 y" y " w148 h36 Background1D1429 c382450 Disabled Hidden vBGMark" index, 100
            Gui, BGPanel: Font, s10 w600 cF2EAF9
            Gui, BGPanel: Add, Text, % "x25 y" y " w123 h36 0x200 BackgroundTrans gBGNavigate vBGNav" index, % sections[index]
        }
        Gui, BGPanel: Font, s9 w600 cEBC461
        Gui, BGPanel: Add, Text, x25 y498 w126 h29 0x200 BackgroundTrans gBGHelp, Ctrl+L  ·  Atalhos
        Gui, BGPanel: Font, s9 w600 cC29BFF
        Gui, BGPanel: Add, Text, x196 y23 w330 h20 vBGContext, PATH OF EXILE 1
        BuildGuide_Action("BGImportAction", "BGImport", "Importar PoB", 606, 18, 136, true)
        BuildGuide_Action("BGStartAction", "BGStartLeveling", "Iniciar leveling", 455, 18, 142, true)
        BuildGuide_Action("BGCompareAction", "BGCompareTree", "Conferir passivas", 366, 474, 146)
        BuildGuide_Action("BGHideLevelingAction", "BGToggleLeveling", "Ocultar overlay", 525, 474, 142)
        Gui, BGPanel: Font, s21 w700 cFAF3FF
        Gui, BGPanel: Add, Text, x195 y47 w550 h43 vBGSection
        Gui, BGPanel: Font, s10 w400 cC6B5D8
        Gui, BGPanel: Add, Text, x196 y94 w546 h36 vBGStageTitle
        Gui, BGPanel: Font, s10 w400 cF2EAF9
        Gui, BGPanel: Add, Edit, x196 y144 w546 h314 ReadOnly -E0x200 vBGText Hwndbody
        DllCall("uxtheme\SetWindowTheme", "Ptr", body, "WStr", "DarkMode_Explorer", "Ptr", 0)
        BuildGuide_Action("BGPrevAction", "BGPrevious", "Anterior", 196, 474, 90, false)
        BuildGuide_Action("BGNextAction", "BGNext", "Próxima", 293, 474, 90, false)
        BuildGuide_Action("BGAutoAction", "BGAuto", "Seguir ato", 390, 474, 112, false)
        BuildGuide_Action("BGEditAction", "BGEdit", "Editar prioridades", 590, 474, 152, false)
        BuildGuide_Action("BGRunAction", "BGRun", "Iniciar / Pausar", 196, 474, 122, false)
        BuildGuide_Action("BGFinishAction", "BGFinish", "Salvar run", 325, 474, 106, false)
        BuildGuide_Action("BGRecordsAction", "BGRecords", "Ver recordes", 438, 474, 118, false)
        Gui, BGPanel: Add, Text, x196 y151 w520 h20 vBGPrefModeLabel, Modo de campanha
        Gui, BGPanel: Add, DropDownList, x196 y177 w255 AltSubmit vBGRouteMode, Início de liga|Segundo personagem
        Gui, BGPanel: Add, Text, x474 y151 w268 h20 vBGPrefProfileLabel, Perfil do PoB
        Gui, BGPanel: Add, DropDownList, x474 y177 w268 AltSubmit vBGProfile gBGSelectProfile, Perfil 1|Perfil 2|Perfil 3|Perfil 4|Perfil 5
        Gui, BGPanel: Add, Checkbox, x196 y228 w530 h24 vBGRouteGems, Incluir missões de gemas
        Gui, BGPanel: Add, Checkbox, x196 y259 w530 h24 vBGRouteOptional, Incluir desvios opcionais
        Gui, BGPanel: Add, Text, x196 y305 w530 h20 vBGPrefBanditLabel, Bandidos do Ato 2
        Gui, BGPanel: Add, DropDownList, x196 y330 w255 AltSubmit vBGRouteBandit, Matar todos|Alira|Kraityn|Oak
        BuildGuide_Action("BGPrefSave", "BGSavePreferences", "Salvar preferências", 196, 474, 155, true)
        Gui, BGPanel: Font, s9 w600 cEBC461
        Gui, BGPanel: Add, Text, x196 y520 w546 h24 vBGTime
        BuildGuide.panel := panel
    }
    Loop, 7
    {
        action := page = A_Index ? "Show" : "Hide"
        GuiControl, BGPanel:%action%, % "BGMark" A_Index
    }
    GuiControl, BGPanel:, BGSection, % sections[page]
    GuiControl, BGPanel:, BGContext, % "PATH OF EXILE 1  /  PERFIL " (BuildGuide.profile ? BuildGuide.profile : 1)

    if (page = 6)
    {
        title := "Rota de campanha · " BuildGuide_RouteMode()
        contents := BuildGuide_RouteText()
    }
    else if (page = 7)
    {
        title := "Ajuste a rota ou compare um XML atualizado do personagem."
        profile := settings.leveltracker.profile
        info := settings.leveltracker["guide" profile].info
        GuiControl, BGPanel:Choose, BGRouteMode, % info.leaguestart ? 1 : 2
        GuiControl, BGPanel:Choose, BGProfile, % profile ? profile : 1
        GuiControl, BGPanel:, BGRouteGems, % info.gems
        GuiControl, BGPanel:, BGRouteOptional, % info.optionals
        bandits := {"none": 1, "alira": 2, "kraityn": 3, "oak": 4}
        GuiControl, BGPanel:Choose, BGRouteBandit, % bandits[info.bandit] ? bandits[info.bandit] : 1
    }
    else if (page = 5)
    {
        title := "Tempo por zona e histórico de campanha"
        contents := BuildGuide_RunDetails()
    }
    else if IsObject(stage)
    {
        title := stage.title "  ·  Etapa " BuildGuide.stage "/" guide.stages.Count()
        title .= BuildGuide.manual ? "  ·  Manual" : "  ·  Automático"
        contents := BuildGuide_Text(guide, stage, page)
    }
    else
    {
        title := "Nenhum PoB importado neste perfil"
        contents := "Clique em Importar PoB para colar um link ou selecionar um XML."
    }
    for _, control in ["BGPrefModeLabel", "BGRouteMode", "BGPrefProfileLabel", "BGProfile"
        , "BGRouteGems", "BGRouteOptional", "BGPrefBanditLabel", "BGRouteBandit", "BGPrefSave"]
        BuildGuide_ControlVisible(control, page = 7)
    GuiControl, BGPanel:, % BuildGuide.actions.BGAutoAction.label, % page = 6 ? "Seguir zona" : "Seguir ato"
    for _, control in ["BGPrevAction", "BGNextAction", "BGAutoAction"]
        BuildGuide_ControlVisible(control, page = 6 || (page <= 4 && IsObject(stage)))
    for _, control in ["BGRunAction", "BGFinishAction", "BGRecordsAction"]
        BuildGuide_ControlVisible(control, page = 5)
    BuildGuide_ControlVisible("BGEditAction", page >= 2 && page <= 4 && IsObject(stage))
    BuildGuide_ControlVisible("BGStartAction", !BuildGuide.leveling || !IsObject(BuildGuide.run)
        || BuildGuide.run.paused || BuildGuide.run.saved)
    BuildGuide_ControlVisible("BGCompareAction", page = 7 && IsObject(guide))
    GuiControl, BGPanel:, % BuildGuide.actions.BGHideLevelingAction.label, % BuildGuide.leveling ? "Ocultar overlay" : "Mostrar overlay"
    BuildGuide_ControlVisible("BGHideLevelingAction", page = 7)
    BuildGuide_ControlVisible("BGText", page != 7)
    GuiControl, BGPanel:, BGStageTitle, %title%
    GuiControl, BGPanel:, BGText, %contents%
    GuiControlGet, body, BGPanel:Hwnd, BGText
    DllCall("SendMessageW", "Ptr", body, "UInt", 0xB1, "Ptr", 0, "Ptr", 0, "Ptr")
    GuiControl, BGPanel:, BGTime, % BuildGuide_TimeText()
    if !DllCall("IsWindowVisible", "Ptr", BuildGuide.panel)
        Gui, BGPanel: Show, % (focus ? "" : "NA ") "w760 h557"
    else if focus
        WinActivate, % "ahk_id " BuildGuide.panel
}

BuildGuide_Action(name, callback, caption, x, y, width, primary := false)
{
    global BuildGuide
    if !IsObject(BuildGuide.actions)
        BuildGuide.actions := {}
    fill := primary ? "EBC461" : "30213F"
    ink := primary ? "1D1429" : "F2EAF9"
    position := "x" x " y" y " w" width " h28"
    Gui, BGPanel: Add, Progress, % position " Background" fill " c" fill " Disabled Hwndsurface", 100
    Gui, BGPanel: Font, % "s9 w600 c" ink, Segoe UI
    Gui, BGPanel: Add, Text, % position " Center 0x200 BackgroundTrans Hwndlabel g" callback, %caption%
    BuildGuide.actions[name] := {label: label, surface: surface}
    Gui, BGPanel: Font, s10 w400 cF2EAF9, Segoe UI
}

BuildGuide_ControlVisible(control, visible)
{
    global BuildGuide
    action := visible ? "Show" : "Hide"
    if IsObject(button := BuildGuide.actions[control])
    {
        GuiControl, BGPanel:%action%, % button.surface
        GuiControl, BGPanel:%action%, % button.label
    }
    else
        GuiControl, BGPanel:%action%, %control%
}

BuildGuide_Theme(name, hwnd := 0)
{
    Gui, %name%: Color, 100C18, 21162E
    Gui, %name%: Font, s10 cF2EAF9, Segoe UI
    Gui, %name%: Margin, 18, 14
    if !hwnd
    {
        Gui, %name%: +LastFound
        hwnd := WinExist()
    }
    mode := 1
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20, "IntP", mode, "UInt", 4)
    static icon
    if !icon
        icon := DllCall("LoadImageW", "Ptr", 0, "WStr", A_ScriptDir "\img\GUI\nerdmitico.ico"
            , "UInt", 1, "Int", 32, "Int", 32, "UInt", 0x10, "Ptr")
    if icon
    {
        DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x80, "Ptr", 0, "Ptr", icon, "Ptr")
        DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x80, "Ptr", 1, "Ptr", icon, "Ptr")
    }
}

BGNavigate()
{
    BuildGuide_ChooseTab(SubStr(A_GuiControl, 6) + 0)
}

BGHelp()
{
    BuildGuide_ToggleHelp()
}

BGSelectProfile()
{
    global BuildGuide, settings
    GuiControlGet, selection, BGPanel:, BGProfile
    profile := selection > 1 ? selection : ""
    if (profile = settings.leveltracker.profile)
        return
    IniWrite, %profile%, ini\leveling tracker.ini, Settings, profile
    Init_leveltracker()
    BuildGuide_LoadCached()
    BuildGuide.routeProfile := -1
    BuildGuide_DrawPanel()
}

BGSavePreferences()
{
    global BuildGuide, settings
    GuiControlGet, mode, BGPanel:, BGRouteMode
    GuiControlGet, gems, BGPanel:, BGRouteGems
    GuiControlGet, optionals, BGPanel:, BGRouteOptional
    GuiControlGet, bandit, BGPanel:, BGRouteBandit
    profile := settings.leveltracker.profile
    path := "ini\leveling guide" profile ".ini"
    IniWrite, % (mode = 1 ? 1 : 0), %path%, Info, leaguestart
    IniWrite, %gems%, %path%, Info, gems
    IniWrite, %optionals%, %path%, Info, optionals
    IniWrite, % ["none", "alira", "kraityn", "oak"][bandit], %path%, Info, bandit
    Init_leveltracker()
    BuildGuide.routeProfile := -1
    BuildGuide_DrawPanel()
}

BuildGuide_RouteMode()
{
    global settings
    return settings.leveltracker["guide" settings.leveltracker.profile].info.leaguestart
        ? "Início de liga" : "Segundo personagem"
}

BuildGuide_LoadRoute()
{
    global BuildGuide, vars, settings, db
    profile := settings.leveltracker.profile
    if (BuildGuide.routeProfile != "" && BuildGuide.routeProfile = (profile ? profile : 1))
        return
    if !IsObject(db.leveltracker)
        DB_Load("leveltracker")
    path := "ini\leveling guide" profile ".ini"
    ini := IniBatchRead(path)
    if !ini.guide.act1
        Leveltracker_GuideEditor("default#" profile)
    Leveltracker_Load()
    BuildGuide.routeProfile := profile ? profile : "1"
    BuildGuide.routeLastArea := "", BuildGuide.levelingKey := ""
}

BuildGuide_RoutePage(index)
{
    global vars, settings
    page := vars.leveltracker.guide.import[index]
    if !IsObject(page) || !Leveltracker("condition", index)
        return ""
    info := settings.leveltracker["guide" settings.leveltracker.profile].info
    result := {index: index, lines: [], destinations: [], target: "", acquisitions: vars.leveltracker.guide.acquisitions[index]}
    for _, line in (page.condition ? page.lines : page)
    {
        if (info.leaguestart && InStr(line, Lang_Trans("lvltracker_format_twink"))
            || !info.leaguestart && InStr(line, Lang_Trans("lvltracker_format_league"))
            || !info.optionals && InStr(line, "optional:"))
            continue
        if !InStr(line, "(hint)")
        {
            directive := RegExReplace(line, "\s*;;.*$")
            pos := 1
            while (pos := RegExMatch(directive, "i)areaid([a-z0-9_]+)", area, pos))
            {
                result.destinations.Push(area1), result.target := area1
                pos += StrLen(area)
            }
        }
        result.lines.Push(line)
    }
    return result.lines.Count() ? result : ""
}

BuildGuide_RouteStep(index, direction := 1)
{
    global vars
    limit := vars.leveltracker.guide.import.Count()
    while (index >= 1 && index <= limit)
    {
        page := BuildGuide_RoutePage(index)
        if IsObject(page)
            return page
        index += direction
    }
    return ""
}

BuildGuide_AreaName(area)
{
    global db, vars
    name := db.leveltracker.areaIDs[area].name
    return name ? name : (area = vars.log.areaID && vars.log.areaname ? vars.log.areaname : area)
}

BuildGuide_RouteText(compact := false)
{
    global BuildGuide, vars
    BuildGuide_LoadRoute()
    guide := vars.leveltracker.guide
    page := BuildGuide_RouteStep(guide.progress + 1)
    if !IsObject(page)
        return "Fim da rota de campanha."
    eol := Chr(13) Chr(10)
    result := "Etapa " page.index " / " guide.import.Count()
    for _, line in page.lines
    {
        if compact && RegExMatch(line, "i)^buy gem:|^\(hint\)_*\s*\Q" Lang_Trans("lvltracker_gemreward") "\E")
            continue
        line := RegExReplace(line, "\s*;;.*$")
        line := BuildGuide_RoutePortuguese(line)
        while RegExMatch(line, "i)areaid([a-z0-9_]+)", area)
            line := StrReplace(line, area, BuildGuide_AreaName(area1))
        line := RegExReplace(line, "i)\(quest:([^)]*)\)", "$1")
        line := RegExReplace(line, "i)\(color:[^)]*\)|[<>]")
        line := RegExReplace(line, "i)^\s*(?:leaguestart|twinkrun):\s*")
        line := StrReplace(line, "_", " ")
        line := Trim(RegExReplace(line, "[ \t]+", " "))
        if line
            result .= eol (compact ? "" : eol) "• " line
    }
    return result
}

BuildGuide_MoveRoute(delta, follow := false)
{
    global BuildGuide, vars, settings
    BuildGuide_LoadRoute()
    guide := vars.leveltracker.guide
    page := BuildGuide_RouteStep(guide.progress + 1)
    index := IsObject(page) ? page.index : guide.import.Count() + 1
    if follow
    {
        area := vars.log.areaID
        next := area = "1_1_1" ? 1 : BuildGuide_LocateRoute(area, index)
    }
    else if (delta > 0 && IsObject(page))
        next := page.index + 1
    else if (delta < 0)
    {
        previous := BuildGuide_RouteStep(index - 1, -1)
        next := previous.index
    }
    if !next
        return false
    BuildGuide_SaveRoute(next)
    return true
}

BuildGuide_SaveRoute(index)
{
    global vars, settings
    path := "ini\leveling guide" settings.leveltracker.profile ".ini"
    vars.leveltracker.guide.progress := index - 1
    IniWrite, % index - 1, %path%, Progress, pages
}

BuildGuide_LocateRoute(area, nearIndex)
{
    global vars
    if (area = "")
        return 0
    best := 0, distance := vars.leveltracker.guide.import.Count() + 2
    for index, _ in vars.leveltracker.guide.import
    {
        page := BuildGuide_RoutePage(index)
        if !IsObject(page) || !LLK_HasVal(page.destinations, area)
            continue
        destination := page.target = area ? index + 1 : index
        if (Abs(destination - nearIndex) < distance)
            best := destination, distance := Abs(destination - nearIndex)
    }
    return best
}

BuildGuide_UpdateRoute()
{
    global BuildGuide, vars
    if (BuildGuide.routeProfile = "" || BuildGuide.routeProfile = -1)
        return
    area := vars.log.areaID
    if (area = "" || area = BuildGuide.routeLastArea)
        return
    previous := BuildGuide.routeLastArea
    BuildGuide.routeLastArea := area
    if (area = "1_1_1")
        next := 1
    else
        next := BuildGuide_RouteArrival(area, previous)
    if !next
        return
    if (next != vars.leveltracker.guide.progress + 1)
        BuildGuide_SaveRoute(next)
    if (BuildGuide.tab = 6 && BuildGuide.panel
        && DllCall("IsWindowVisible", "Ptr", BuildGuide.panel))
        BuildGuide_DrawPanel()
}

BuildGuide_RouteArrival(area, previousArea)
{
    global vars
    page := BuildGuide_RouteStep(vars.leveltracker.guide.progress + 1)
    if !IsObject(page)
        return 0
    if (previousArea = "" || previousArea = "login")
    {
        previous := BuildGuide_RouteStep(page.index - 1, -1)
        while IsObject(previous) && !previous.target
            previous := BuildGuide_RouteStep(previous.index - 1, -1)
        if (previous.target = area)
            return 0
        if (page.target = area)
            return page.index + 1
        return BuildGuide_LocateRoute(area, page.index)
    }
    ; Objectives with no destination stay visible until the player moves on.
    while IsObject(page) && !page.target
        page := BuildGuide_RouteStep(page.index + 1)
    return IsObject(page) && page.target = area ? page.index + 1 : 0
}

BuildGuide_ToggleHelp()
{
    global BuildGuide
    if BuildGuide.help && DllCall("IsWindowVisible", "Ptr", BuildGuide.help)
    {
        Gui, BGHelp: Destroy
        BuildGuide.help := 0
        return
    }
    path := "img\GUI\nerdmitico-atalhos.png"
    if !FileExist(path)
    {
        LLK_ToolTip("Infográfico indisponível.", 2)
        return
    }
    global vars
    SysGet, desktop, MonitorWorkArea
    width := Min(1100, (vars.monitor.w ? vars.monitor.w : desktopRight - desktopLeft) - 72
        , Floor(((vars.monitor.h ? vars.monitor.h : desktopBottom - desktopTop) - 110) * 1.59))
    Gui, BGHelp: New, +AlwaysOnTop +ToolWindow +Hwndhelp, NerdMítico Jr. | Atalhos
    BuildGuide_Theme("BGHelp", help)
    Gui, BGHelp: Margin, 10, 10
    Gui, BGHelp: Add, Picture, w%width% h-1, %path%
    BuildGuide.help := help
    position := vars.monitor.w ? "AutoSize x" (vars.monitor.x + (vars.monitor.w - width - 20)//2) " y" (vars.monitor.y + 50) : "AutoSize Center"
    Gui, BGHelp: Show, %position%
}

BGHelpGuiClose:
BGHelpGuiEscape:
BuildGuide_ToggleHelp()
return

BGPrevious()
{
    global BuildGuide
    if (BuildGuide.tab = 6)
        BuildGuide_MoveRoute(-1)
    else
        BuildGuide_Step(-1)
    BuildGuide_DrawPanel()
}

BGNext()
{
    global BuildGuide
    if (BuildGuide.tab = 6)
        BuildGuide_MoveRoute(1)
    else
        BuildGuide_Step(1)
    BuildGuide_DrawPanel()
}

BGAuto()
{
    global BuildGuide, vars
    if (BuildGuide.tab = 6)
        BuildGuide_MoveRoute(0, true)
    else
    {
        BuildGuide.manual := 0
        BuildGuide_SetAct(vars.log.act)
    }
    BuildGuide_DrawPanel()
}

BGImport()
{
    BuildGuide_ImportDialog()
}

BGEdit()
{
    BuildGuide_Edit()
}

BGRun()
{
    BuildGuide_Run()
}

BGFinish()
{
    BuildGuide_Finish()
}

BGRecords()
{
    BuildGuide_Records()
}

BGPanelGuiClose:
BGPanelGuiEscape:
Gui, BGPanel: Hide
return


BGStartLeveling()
{
    global BuildGuide, vars
    if (BuildGuide.tab = 7)
        BGSavePreferences()
    BuildGuide_LoadRoute()
    BuildGuide_UpdateRoute()
    BuildGuide_SetAct(vars.log.act)
    if !IsObject(BuildGuide.run) || BuildGuide.run.saved || BuildGuide.run.paused
        BuildGuide_Run()
    BuildGuide_SetOverlay(true)
    Gui, BGPanel: Hide
    if vars.hwnd.poe_client
        WinActivate, % "ahk_id " vars.hwnd.poe_client
    BuildGuide_UpdateClock()
    BuildGuide_UpdateLeveling()
}

BGHideLeveling()
{
    BuildGuide_SetOverlay(false)
    BuildGuide_DrawPanel()
}

BGToggleLeveling()
{
    global BuildGuide
    if BuildGuide.leveling
        BGHideLeveling()
    else
    {
        BuildGuide_SetOverlay(true)
        BuildGuide_DrawPanel()
    }
}

BuildGuide_SetOverlay(visible)
{
    global BuildGuide
    BuildGuide.leveling := visible, BuildGuide.levelingKey := ""
    IniWrite, % (visible ? 1 : 0), % BuildGuide.preferenceFile, Overlay, campanha
    if !visible && BuildGuide.levelingHwnd
        Gui, BGLeveling: Hide
}

BGRouteBack()
{
    BuildGuide_MoveRoute(-1)
    BuildGuide_UpdateLeveling()
}

BGRouteNext()
{
    BuildGuide_MoveRoute(1)
    BuildGuide_UpdateLeveling()
}

BGRouteFollow()
{
    BuildGuide_MoveRoute(0, true)
    BuildGuide_UpdateLeveling()
}

BuildGuide_CampaignActive()
{
    global BuildGuide, vars
    return BuildGuide.leveling && !vars.poe_version
}

BuildGuide_UpdateLeveling()
{
    global BuildGuide, vars, BGLevelRoute, BGLevelGems, BGLevelTime, BGLevelStage, BGLevelArea, BGLevelDestination
    if !BuildGuide.leveling || !vars.hwnd.poe_client || !WinActive("ahk_id " vars.hwnd.poe_client)
        || (vars.log.areaID = "login") || (vars.log.act > 10)
        || vars.leveltracker.skilltree_schematics.GUI || BuildGuide.layout
        || (BuildGuide.help && DllCall("IsWindowVisible", "Ptr", BuildGuide.help))
    {
        if BuildGuide.levelingHwnd
            Gui, BGLeveling: Hide
        return
    }
    BuildGuide_LoadRoute()
    stage := BuildGuide.guide.stages[BuildGuide.stage]
    if !BuildGuide.levelingHwnd
    {
        Gui, BGLeveling: New, -Caption +ToolWindow +AlwaysOnTop +E0x08000000 +Hwndhwnd, NerdMítico Jr. | Campanha
        BuildGuide_Theme("BGLeveling", hwnd)
        Gui, BGLeveling: Margin, 12, 9
        Gui, BGLeveling: Font, s10 w700 cEBC461, Segoe UI
        Gui, BGLeveling: Add, Text, xm ym w500 vBGLevelStage
        Gui, BGLeveling: Font, s9 w400 cF2EAF9
        Gui, BGLeveling: Add, Text, xm y+5 w500 vBGLevelArea
        Gui, BGLeveling: Add, Text, xm y+3 w500 vBGLevelDestination
        Gui, BGLeveling: Font, s9 w600 cC29BFF
        Gui, BGLeveling: Add, Text, xm y+9 w235, Objetivos
        Gui, BGLeveling: Add, Text, x+10 yp w255, Gemas e links
        Gui, BGLeveling: Font, s9 w400 cF2EAF9
        height := Max(140, Min(250, Round(vars.client.h * 0.25)))
        Gui, BGLeveling: Add, Edit, xm y+4 w235 h%height% ReadOnly -Tabstop -E0x200 vBGLevelRoute Hwndroute
        Gui, BGLeveling: Add, Edit, x+10 yp w255 h%height% ReadOnly -Tabstop -E0x200 vBGLevelGems Hwndgems
        for _, control in [route, gems]
            DllCall("uxtheme\SetWindowTheme", "Ptr", control, "WStr", "DarkMode_Explorer", "Ptr", 0)
        Gui, BGLeveling: Font, s9 w600 cEBC461
        Gui, BGLeveling: Add, Button, xm y+8 w58 h23 -Tabstop gBGRouteBack, Voltar
        Gui, BGLeveling: Add, Button, x+5 yp w65 h23 -Tabstop gBGRouteNext, Avançar
        Gui, BGLeveling: Add, Button, x+5 yp w88 h23 -Tabstop gBGRouteFollow, Seguir zona
        Gui, BGLeveling: Add, Text, x+10 yp+4 w264 vBGLevelTime
        BuildGuide.levelingHwnd := hwnd
    }
    area := vars.log.areaID, areaName := BuildGuide_AreaName(area)
    key := BuildGuide.profile "|" BuildGuide.stage "|" vars.leveltracker.guide.progress "|" area "|" areaName "|" vars.log.act
    if (key != BuildGuide.levelingKey)
    {
        BuildGuide.levelingKey := key
        page := BuildGuide_RouteStep(vars.leveltracker.guide.progress + 1)
        target := BuildGuide_NextArea(page, area)
        route := BuildGuide_RouteText(true)
        gems := BuildGuide_LinkGroups(BuildGuide.guide.skills[stage.skill], true)
        acquisitions := BuildGuide_AcquisitionText(page.acquisitions)
        eol := Chr(13) Chr(10)
        if !IsObject(BuildGuide.guide)
            gems := "Importe seu PoB no painel (F5) para ver suas gemas."
        else if acquisitions
            gems := acquisitions eol eol "Links · " stage.title eol gems
        else
            gems := "Sem recompensa ou compra nesta etapa." eol eol "Links · " stage.title eol gems
        title := "NERDMÍTICO JR.  ·  CAMPANHA" (vars.log.act ? "  ·  ATO " vars.log.act : "")
        location := areaName ? "Você está em " areaName : (vars.log.file_location
            ? "Aguardando a zona no log do jogo" : "Client.txt indisponível · confira a pasta de logs do jogo")
        destination := target ? "Próxima área  ·  " BuildGuide_AreaName(target)
            : (IsObject(page) ? "Conclua os objetivos desta etapa" : "Campanha concluída")
        GuiControl, BGLeveling:, BGLevelRoute, %route%
        GuiControl, BGLeveling:, BGLevelGems, %gems%
        GuiControl, BGLeveling:, BGLevelStage, %title%
        GuiControl, BGLeveling:, BGLevelArea, %location%
        GuiControl, BGLeveling:, BGLevelDestination, %destination%
    }
    GuiControl, BGLeveling:, BGLevelTime, % BuildGuide_TimeText()
    position := vars.client.x "|" vars.client.y
    if !DllCall("IsWindowVisible", "Ptr", BuildGuide.levelingHwnd) || (position != BuildGuide.levelingPosition)
    {
        BuildGuide.levelingPosition := position
        Gui, BGLeveling: Show, % "NA AutoSize x" (vars.client.x + 18) " y" (vars.client.y + 60)
    }
}

BuildGuide_NextArea(page, current)
{
    if !IsObject(page)
        return ""
    last := 0
    for index, area in page.destinations
        if (area = current)
            last := index
    return page.destinations[last + 1]
}

BuildGuide_AcquisitionText(acquisitions)
{
    global db
    if !IsObject(acquisitions) || !acquisitions.Count()
        return ""
    catalog := db.leveltracker.gems, eol := Chr(13) Chr(10), text := "Gemas nesta etapa"
    for _, entry in acquisitions
    {
        gem := BuildGuide_AcquisitionGemName(entry.gem, catalog)
        quest := RegExReplace(entry.quest, "\d+$")
        npc := entry.buy ? BuildGuide_GemSeller(entry.quest) : catalog._quests[entry.quest].npc
        if entry.hideout
            npc := "Lilly Roth", quest := "esconderijo"
        else
        {
            StringUpper, quest, quest, T
            StringUpper, npc, npc, T
        }
        text .= eol (entry.buy ? "Compre" : "Pegue") " " gem
        text .= eol "  " (npc ? npc " · " : "") quest
        if entry.buy
            text .= eol "  " BuildGuide_GemCost(entry.gem, catalog[entry.gem].level)
    }
    return text
}

BuildGuide_AcquisitionGemName(key, catalog)
{
    global BuildGuide
    for _, skillset in BuildGuide.guide.skills
        for _, group in skillset.groups
            for _, gem in group.gems
                if (BuildGuide_GemKey(gem) = key)
                    return gem.name
    name := catalog[key].name ? catalog[key].name : key
    StringUpper, name, name, T
    return name
}

BuildGuide_LinkGroups(skillset, compact := false)
{
    if !IsObject(skillset) || !skillset.groups.Count()
        return "Nenhum conjunto de gemas nesta etapa."
    eol := Chr(13) Chr(10), text := compact ? "" : skillset.title
    for _, group in skillset.groups
    {
        active := "", supports := ""
        for _, gem in group.gems
        {
            label := gem.name (gem.count > 1 ? " ×" gem.count : "")
            if gem.support
                supports .= eol "  • " label
            else
                active .= (active ? " + " : "") label
        }
        heading := active ? active : "Grupo de suportes"
        if !compact
            heading .= " · " group.gems.Count() "L" (group.slot ? " · " BuildGuide_SlotLabel(group.slot) : "")
        text .= (text ? eol eol : "") heading supports
    }
    return text
}

BGCompareTree()
{
    global BuildGuide, vars, settings
    Gui, BGPanel: +OwnDialogs
    FileSelectFile, path, 3,, Selecione o XML atualizado do personagem, XML do Path of Building (*.xml)
    if ErrorLevel
        return
    FileRead, raw, *P65001 %path%
    if ErrorLevel
        return
    try
    {
        snapshot := BuildGuide_Parse(raw)
        if (snapshot.class != BuildGuide.guide.class)
            throw Exception("A classe do personagem é diferente da build do perfil.")
        native := vars.leveltracker["PoB" settings.leveltracker.profile]
        if !native.trees.Count()
            throw Exception("O perfil ativo precisa de uma árvore compatível.")
        actual := snapshot.trees[snapshot.activeTree]
        if !IsObject(actual)
            throw Exception("O arquivo não tem uma árvore ativa para comparar.")
        if !BuildGuide.treeTarget
            BuildGuide_SyncTree()
        index := BuildGuide.treeTarget ? BuildGuide.treeTarget : native["active tree"]
        if !native.trees[index]
            index := 1
        if (native.trees[index].version != actual.version)
            throw Exception("A árvore ativa do personagem usa uma versão diferente da etapa.")
        if !Leveltracker_PobSkilltree("init " actual.version)
            throw Exception("Os dados dessa versão da árvore não estão disponíveis.")
        result := BuildGuide_CheckTreeProgress(native.trees, index, actual)
    }
    catch error
    {
        MsgBox, 48, Conferir passivas, % error.Message
        return
    }
    BuildGuide.treeTarget := result.index
    native["active tree"] := result.index
    BuildGuide.levelingKey := ""
    title := native.trees[result.index].title
    if result.complete
        text := "Última etapa concluída: " title "."
    else if result.nextVersion
        text := "Etapa concluída: " title ". A próxima exige um XML da versão " StrReplace(result.nextVersion, "_", ".") "."
    else
        text := (result.index > index ? "Etapa avançada: " : "Etapa atual: ") title "."
            . Chr(10) "Faltam " result.missing " alocações e " result.remove " remoções."
    MsgBox, 64, Conferir passivas, %text%
}

BuildGuide_CheckTreeProgress(trees, index, actual)
{
    global db
    allocated := {}
    for _, id in StrSplit(actual.nodes, ",")
        if RegExMatch(id, "^\d+$")
            allocated[id + 0] := true
    count := trees.Count()
    while (index <= count && trees[index].version = actual.version)
    {
        target := trees[index], expected := {}, missing := 0, remove := 0
        definitions := db.leveltracker.trees[target.version].nodes
        for _, id in target.nodes
        {
            node := definitions[id]
            if (id = "" || (IsObject(node) && node.HasKey("classstartindex")) || node.isascendancystart)
                continue
            expected[id + 0] := true
            if !allocated[id + 0]
                missing++
        }
        for id, effect in target.masteries
            if (allocated[id + 0] && actual.masteries[id + 0] != effect)
                missing++
        previous := trees[index - 1]
        if (previous.version = target.version)
            for _, id in previous.nodes
            {
                node := definitions[id]
                if allocated[id + 0] && !expected[id + 0]
                    && !(IsObject(node) && node.HasKey("classstartindex")) && !node.isascendancystart
                    remove++
            }
        if missing || remove
            return {index: index, missing: missing, remove: remove, complete: false}
        if (index = count || trees[index + 1].version != actual.version)
            return {index: index, complete: index = count, nextVersion: trees[index + 1].version, missing: 0, remove: 0}
        index++
    }
    return {index: index, complete: false, missing: 0, remove: 0}
}

BuildGuide_SlotLabel(slot)
{
    static labels := {"Weapon": "Arma", "Weapon Swap": "Arma alternativa", "Helmet": "Elmo"
        , "Body Armour": "Armadura", "Gloves": "Luvas", "Boots": "Botas", "Amulet": "Amuleto"
        , "Ring": "Anel", "Belt": "Cinto", "Flask": "Frasco", "Quiver": "Aljava"}
    if RegExMatch(slot, "^(.*?)( \d+)?$", part) && labels.HasKey(part1)
        return labels[part1] part2
    return slot
}

BuildGuide_RoutePortuguese(line)
{
    static labels := {"waypoint": "ponto de passagem", "portal": "portal", "town": "cidade"
        , "quest": "missão", "lab": "Labirinto", "arena": "arena", "craft": "receita de fabricação"
        , "in-out2": "entre e saia", "skip": "pule"}
    static verbs := {"enter": "Entre em", "kill": "Derrote", "talk to": "Fale com", "return to": "Volte para"
        , "activate": "Ative", "go to": "Vá para", "use": "Use", "buy gem": "Comprar gema", "buy": "Compre"
        , "complete": "Conclua", "find": "Encontre", "pick up": "Pegue", "take": "Pegue", "optional": "Opcional"
        , "find & kill": "Encontre e derrote", "find & enter": "Encontre e entre em", "follow": "Siga"
        , "buy_gems": "Compre gemas", "relog": "Reconecte"}
    pos := 1
    while (pos := RegExMatch(line, "i)\(img:([^)]*)\)", icon, pos))
    {
        label := labels.HasKey(icon1) ? " " labels[icon1] " " : " "
        line := SubStr(line, 1, pos - 1) label SubStr(line, pos + StrLen(icon))
        pos += StrLen(label)
    }
    line := RegExReplace(line, "i)^\s*(?:leaguestart|twinkrun):\s*")
    line := RegExReplace(line, "i)^\s*\(hint\)_*", "Dica: ")
    line := RegExReplace(line, "i)\(color:[^)]*\)")
    line := RegExReplace(line, "i)^\s*complete\s+Labirinto\s+trial\b", "Conclua a prova do Labirinto")
    line := RegExReplace(line, "i)^\s*missão\s+(\w+)\s*:", "Fale com $1:")
    line := RegExReplace(line, "i)^\s*ponto de passagem\s+to\s+", "Use o ponto de passagem para ")
    line := RegExReplace(line, "i)^\s*portal\s+to\s+", "Use o portal para ")
    if RegExMatch(line, "i)^(\s*(?:Dica:\s*)?)(find & kill|find & enter|talk to|return to|go to|buy gem|buy_gems|pick up|enter|kill|activate|use|buy|complete|find|take|optional|follow|relog)\b", verb)
    {
        StringLower, action, verb2
        line := verb1 verbs[action] SubStr(line, StrLen(verb) + 1)
    }
    return line
}

BuildGuide_Text(guide, stage, tab)
{
    global BuildGuide, db
    if (tab = 5)
        return BuildGuide_RunDetails()

    if (tab = 1)
    {
        if !stage.skill
            return "Nenhum conjunto de gemas associado a esta etapa."
        if !IsObject(db.leveltracker) && IsFunc("DB_Load")
            DB_Load("leveltracker")
        skillset := guide.skills[stage.skill]
        previous := BuildGuide.stage > 1 ? guide.skills[guide.stages[BuildGuide.stage - 1].skill] : ""
        oldCounts := BuildGuide_GemCounts(previous)
        seen := {}
        text := BuildGuide_LinkGroups(skillset), acquisitions := ""
        for index, group in skillset.groups
        {
            for index, gem in group.gems
            {
                seen[gem.name] := (seen.HasKey(gem.name) ? seen[gem.name] : 0) + gem.count
                new := seen[gem.name] > (oldCounts.HasKey(gem.name) ? oldCounts[gem.name] : 0)
                if new
                {
                    acquisition := BuildGuide_GemSource(gem, guide.class, db.leveltracker.gems)
                    if acquisition
                        acquisitions .= Chr(13) Chr(10) "+ " gem.name Chr(13) Chr(10) "    " acquisition
                }
            }
        }
        if acquisitions
            text .= Chr(13) Chr(10) Chr(13) Chr(10) "Gemas para obter" acquisitions
        current := BuildGuide_GemCounts(skillset)
        for name, count in oldCounts
            if (count > (copies := current.HasKey(name) ? current[name] : 0))
                text .= Chr(13) Chr(10) "− " name " ×" (count - copies)
        return text
    }

    text := ""
    if (tab = 4)
    {
        if !stage.tree
            return "Nenhuma árvore associada a esta etapa."
        tree := guide.trees[stage.tree]
        for node, id in tree.sockets
            if IsObject(guide.items[id])
                text .= BuildGuide_ItemText("Encaixe " node, guide.items[id], id) Chr(13) Chr(10) Chr(13) Chr(10)
        return text ? text : "Esta árvore não tem joias preenchidas no PoB."
    }
    if !stage.gear
        return "Nenhum conjunto de equipamentos associado a esta etapa."
    set := guide.sets[stage.gear]
    for _, slot in set.slots
        if ((tab = 3) = !!RegExMatch(slot.name, "i)^Flask")) && IsObject(guide.items[slot.id])
            text .= BuildGuide_ItemText(slot.name, guide.items[slot.id], slot.id) Chr(13) Chr(10) Chr(13) Chr(10)
    return text ? set.title Chr(13) Chr(10) Chr(13) Chr(10) text : "Nenhum item preenchido nesta categoria."
}

BuildGuide_GemCounts(skillset)
{
    counts := {}
    if IsObject(skillset)
        for _, group in skillset.groups
            for _, gem in group.gems
                counts[gem.name] := (counts.HasKey(gem.name) ? counts[gem.name] : 0) + gem.count
    return counts
}

BuildGuide_GemSeller(quest)
{
    static sellers := {"enemy at the gate": "Nessa", "mercy mission": "Nessa", "breaking some eggs1": "Nessa"
        , "breaking some eggs2": "Nessa", "the caged brute1": "Nessa", "the caged brute2": "Nessa"
        , "the siren's cadence": "Nessa", "intruders in black": "Yeena", "sharp and cruel": "Yeena"
        , "lost in love": "Clarissa", "sever the right hand": "Clarissa", "a fixture of fate": "Siosa"
        , "breaking the seal": "Petarus e Vanja", "the eternal nightmare": "Petarus e Vanja", "fallen from grace": "Lilly Roth"}
    return sellers[quest]
}

BuildGuide_GemKey(gem)
{
    key := gem.name
    StringLower, key, key
    return key (gem.support && !RegExMatch(key, " support$") ? " support" : "")
}

BuildGuide_GemCost(gem, level)
{
    global BuildGuide
    path := BuildGuide.directory "\precos.ini"
    IniRead, price, %path%, Preços, %gem%, %A_Space%
    if (price = "")
        price := BuildGuide_GemPrice(level)
    return price != "" ? price : "preço a confirmar"
}

BuildGuide_GemSource(gem, class, catalog)
{
    global BuildGuide
    if !IsObject(catalog)
        return ""
    gemName := gem.name
    StringLower, gemName, gemName
    if RegExMatch(gemName, "i)^(?:Vaal |Awakened )| of ")
    {
        data := catalog[gemName]
        if !IsObject(data)
            return "Variante especial · consulte a origem no jogo"
    }
    lookup := BuildGuide_GemKey(gem)
    data := catalog[lookup]
    if !IsObject(data)
        return "Disponibilidade a confirmar"
    reward := "", purchase := "", rank := 99
    for quest, options in data.quests
    {
        details := catalog._quests[quest]
        if !details.act
            continue
        questName := RegExReplace(quest, "\d+$")
        StringUpper, questName, questName, T
        npc := BuildGuide_GemSeller(quest)
        if IsObject(options.quest) && BuildGuide_ClassAllowed(options.quest, class) && (!IsObject(reward) || details.act < reward.act)
            reward := {act: details.act, text: "Recompensa · Ato " details.act " · " details.npc " · " questName}
        if (npc != "") && IsObject(options.vendor) && BuildGuide_ClassAllowed(options.vendor, class) && details.act < rank
        {
            rank := details.act
            purchase := "Comprar · Ato " details.act " · " npc " · " questName
            purchase .= " · " BuildGuide_GemCost(lookup, data.level)
        }
    }
    result := reward.text
    if purchase
        result .= (result ? Chr(13) Chr(10) "    " : "") purchase
    return result ? result : "Disponibilidade a confirmar"
}

BuildGuide_GemPrice(level)
{
    global BuildGuide
    if !level
        return ""
    path := BuildGuide.directory "\precos.ini"
    IniRead, patch, %path%, Versao, patch, 3.29
    if (level >= 28 && level <= 37)
    {
        if (patch = "3.30")
            return level <= 33 ? "1× Orb of Alteration" : "1× Orb of Alchemy"
        if (patch = "3.29")
            return "1× Orb of Chance"
    }
    return ""
}

BuildGuide_ClassAllowed(classes, class)
{
    if !classes.Count()
        return true
    for _, candidate in classes
        if (candidate = class)
            return true
    return false
}

BuildGuide_Priority(item, id)
{
    global BuildGuide
    key := item.name "|" item.base "|" id
    if IsObject(BuildGuide.priorities[key])
        return {key: key, confirmed: true, mods: BuildGuide.priorities[key]}
    list := []
    if (item.rarity = "UNIQUE" || item.rarity = "RELIC")
        for _, mod in item.rolls
            list.Push(mod)
    for _, mod in item.mods
        if !BuildGuide_Contains(list, mod)
            list.Push(mod)
    for _, mod in item.implicits
        if !BuildGuide_Contains(list, mod)
            list.Push(mod)
    return {key: key, confirmed: false, mods: list}
}

BuildGuide_Contains(list, value)
{
    for _, candidate in list
        if (candidate = value)
            return true
    return false
}

BuildGuide_ItemLabel(item)
{
    return (item.rarity = "UNIQUE" || item.rarity = "RELIC") && item.name != item.base
        ? item.name " · " item.base : item.base
}

BuildGuide_ItemText(slot, item, id)
{
    priority := BuildGuide_Priority(item, id)
    static rarities := {"NORMAL": "Normal", "MAGIC": "Mágico", "RARE": "Raro", "UNIQUE": "Único", "RELIC": "Relíquia"}
    rarity := rarities.HasKey(item.rarity) ? rarities[item.rarity] : item.rarity
    line := BuildGuide_SlotLabel(slot) "  |  " BuildGuide_ItemLabel(item) "  [" rarity "]"
    if item.sockets
        line .= Chr(13) Chr(10) "Encaixes: " item.sockets
    if priority.confirmed && priority.mods.Count() && (item.rarity = "UNIQUE" || item.rarity = "RELIC")
        line .= Chr(13) Chr(10) "Mod principal: " priority.mods[1]
    if priority.mods.Count()
        line .= Chr(13) Chr(10) (priority.confirmed ? "Prioridade" : "Mods do PoB · ordem a confirmar")
    for index, mod in priority.mods
        line .= Chr(13) Chr(10) (priority.confirmed ? index ". " : "• ") mod
    return line
}

BuildGuide_Edit()
{
    global BuildGuide, BGItemChoice, BGItemMods
    stage := BuildGuide.guide.stages[BuildGuide.stage]
    ids := [], labels := ""
    for _, slot in BuildGuide.guide.sets[stage.gear].slots
    {
        item := BuildGuide.guide.items[slot.id]
        if !IsObject(item)
            continue
        ids.Push(slot.id)
        labels .= StrReplace(BuildGuide_SlotLabel(slot.name) " · " BuildGuide_ItemLabel(item), "|", "/") "|"
    }
    for node, id in BuildGuide.guide.trees[stage.tree].sockets
    {
        item := BuildGuide.guide.items[id]
        if !IsObject(item)
            continue
        ids.Push(id)
        labels .= StrReplace("Joia " node " · " BuildGuide_ItemLabel(item), "|", "/") "|"
    }
    if !ids.Count()
    {
        MsgBox, 64, Prioridades, Nenhum item foi associado a esta etapa.
        return
    }
    BuildGuide.editorIds := ids
    Gui, BGEditor: Destroy
    Gui, BGEditor: New, +AlwaysOnTop +ToolWindow, Prioridades da build
    BuildGuide_Theme("BGEditor")
    Gui, BGEditor: Add, Text, w600, Coloque um mod por linha. O primeiro é o mais importante.
    Gui, BGEditor: Add, DropDownList, w600 AltSubmit Choose1 vBGItemChoice gBGEditorSelect, % RTrim(labels, "|")
    Gui, BGEditor: Add, Edit, w600 r13 vBGItemMods
    Gui, BGEditor: Add, Button, w150 gBGEditorSave, Salvar prioridades
    BGEditorSelect()
    Gui, BGEditor: Show
}

BGEditorSelect()
{
    global BuildGuide
    GuiControlGet, choice, BGEditor:, BGItemChoice
    id := BuildGuide.editorIds[choice]
    item := BuildGuide.guide.items[id]
    priority := BuildGuide_Priority(item, id)
    text := ""
    for _, mod in priority.mods
        text .= (text ? Chr(13) Chr(10) : "") mod
    GuiControl, BGEditor:, BGItemMods, %text%
}

BGEditorSave()
{
    global BuildGuide
    GuiControlGet, choice, BGEditor:, BGItemChoice
    GuiControlGet, text, BGEditor:, BGItemMods
    id := BuildGuide.editorIds[choice]
    item := BuildGuide.guide.items[id]
    priority := BuildGuide_Priority(item, id)
    mods := []
    for _, line in StrSplit(text, Chr(10), Chr(13))
        if (Trim(line) != "")
            mods.Push(Trim(line))
    next := BuildGuide.priorities.Clone()
    if mods.Count()
        next[priority.key] := mods
    else
        next.Delete(priority.key)
    try BuildGuide_Write(BuildGuide.directory "\prioridades-" (BuildGuide.profile ? BuildGuide.profile : "1") ".json", JSON.Dump(next,, 2))
    catch error
    {
        MsgBox, 48, Prioridades, % error.Message
        return
    }
    BuildGuide.priorities := next
    Gui, BGEditor: Destroy
    BuildGuide_DrawPanel()
}

BuildGuide_SetAct(act)
{
    global BuildGuide
    if !act || BuildGuide.manual || !IsObject(BuildGuide.guide)
        return
    best := 0, bestAct := 0
    for index, stage in BuildGuide.guide.stages
        if (stage.act > bestAct && stage.act <= act)
            best := index, bestAct := stage.act
    if best
        BuildGuide.stage := best
}

BuildGuide_TreeSockets(nativeTree)
{
    global BuildGuide
    if !IsObject(BuildGuide.guide)
        return {}
    allocation := BuildGuide_JoinNodes(nativeTree.nodes)
    for _, tree in BuildGuide.guide.trees
        if (tree.version = nativeTree.version && tree.nodes = allocation)
            return tree.sockets
    if (nativeTree.title != "" && nativeTree.title != "untitled tree")
        for _, tree in BuildGuide.guide.trees
            if (tree.version = nativeTree.version && Leveltracker_PobRemoveTags(tree.title) = nativeTree.title)
                return tree.sockets
    return {}
}

BuildGuide_JoinNodes(nodes)
{
    result := ""
    for _, node in nodes
        result .= (result = "" ? "" : ",") node
    return result
}

BuildGuide_DrawJewels(graphics, positions, tree, width, height)
{
    global BuildGuide
    sockets := BuildGuide_TreeSockets(tree)
    for node, id in sockets
    {
        point := positions[node + 0], item := BuildGuide.guide.items[id]
        if !IsObject(point) || !IsObject(item)
            continue
        priority := BuildGuide_Priority(item, id)
        label := item.rarity = "UNIQUE" || item.rarity = "RELIC" ? item.name : item.base
        if priority.confirmed && priority.mods.Count()
            label .= " · " priority.mods[1]
        if (StrLen(label) > 61)
            label := SubStr(label, 1, 58) "…"
        labelWidth := Min(width, Max(86, StrLen(label) * 6 + 12))
        x := Max(0, Min(point.x + 12, width - labelWidth))
        y := Max(0, Min(point.y + 8, height - 19))
        brush := Gdip_BrushCreateSolid(0xE91C2636)
        ring := Gdip_CreatePen(0xFFF1BB61, 2)
        Gdip_DrawEllipse(graphics, ring, point.x - 8, point.y - 8, 16, 16)
        Gdip_FillRectangle(graphics, brush, x, y, labelWidth, 18)
        Gdip_TextToGraphics(graphics, label, "x" (x + 4) " y" (y + 1) " s11 cFFFCE0AB", "Segoe UI", labelWidth - 8, 17)
        Gdip_DeletePen(ring)
        Gdip_DeleteBrush(brush)
    }
}

BuildGuide_TreeHold()
{
    if !BuildGuide_ShowTree()
        return
    BuildGuide_UpdateLeveling()
    SetTimer, BuildGuide_TreeRelease, 30
    KeyWait, F8
    BuildGuide_TreeRelease()
}

BuildGuide_ShowTree()
{
    global vars, settings
    profile := settings.leveltracker.profile
    if !vars.leveltracker["PoB" profile].trees.Count()
    {
        LLK_ToolTip("Importe um PoB com árvore compatível no perfil ativo.", 2)
        return false
    }
    ; F8 is an explicit request to draw the tree. The native omni-key still uses screen recognition.
    if !vars.leveltracker.skilltree_schematics.GUI
    {
        BuildGuide_SyncTree()
        Leveltracker_PobSkilltree()
    }
    return vars.leveltracker.skilltree_schematics.GUI
}

BuildGuide_SyncTree()
{
    global BuildGuide, vars, settings
    profile := settings.leveltracker.profile
    native := vars.leveltracker["PoB" profile]
    if BuildGuide.treeTarget && IsObject(native.trees[BuildGuide.treeTarget])
    {
        native["active tree"] := BuildGuide.treeTarget
        return
    }
    tree := BuildGuide.guide.trees[BuildGuide.guide.stages[BuildGuide.stage].tree]
    if !IsObject(tree)
        return
    for index, candidate in native.trees
        if (candidate.version = tree.version && BuildGuide_JoinNodes(candidate.nodes) = tree.nodes)
        {
            native["active tree"] := index
            return
        }
}

BuildGuide_TreeRelease()
{
    global vars
    if GetKeyState("F8", "P") && BuildGuide_Focused()
        return
    SetTimer, BuildGuide_TreeRelease, Off
    if vars.leveltracker.skilltree_schematics.GUI
        Leveltracker_PobSkilltree("close")
}


BuildGuide_Layout()
{
    global BuildGuide, vars
    area := vars.log.areaID
    if !RegExMatch(area, "i)^[a-z0-9_]+$")
        return
    paths := []
    for _, extension in ["png", "jpg", "bmp"]
    {
        path := BuildGuide.directory "\layouts\" area "." extension
        if FileExist(path)
        {
            paths.Push(path)
            break
        }
    }
    if !paths.Count()
    {
        pattern := "img\GUI\act-decoder\zones\" area " *.jpg"
        Loop, Files, %pattern%
            paths.Push(A_LoopFilePath)
        pattern := "img\GUI\act-decoder\zones\" area " *.png"
        Loop, Files, %pattern%
            paths.Push(A_LoopFilePath)
    }
    if !paths.Count()
    {
        LLK_ToolTip("Sem imagem de layout para esta zona.", 2)
        return
    }

    BuildGuide.layoutImages := paths, BuildGuide.layoutPage := 1
    BuildGuide_DrawLayout()
    KeyWait, F9
    Gui, BGLayout: Destroy
    BuildGuide.layout := 0
}

BuildGuide_DrawLayout()
{
    global BuildGuide, vars
    Gui, BGLayout: Destroy
    Gui, BGLayout: New, -Caption +AlwaysOnTop +ToolWindow +E0x20 +Hwndlayout
    BuildGuide_Theme("BGLayout", layout)
    Gui, BGLayout: Margin, 12, 10
    Gui, BGLayout: Font, s10 w600 cEBC461
    title := vars.log.areaname ? vars.log.areaname : vars.log.areaID
    paths := BuildGuide.layoutImages, page := BuildGuide.layoutPage
    Gui, BGLayout: Add, Text,, % title " · " page "/" paths.Count() (paths.Count() > 1 ? "   [ / ] para alternar" : "")
    path := paths[page]
    bitmap := Gdip_CreateBitmapFromFile(path)
    if !bitmap
        return
    Gdip_GetImageDimension(bitmap, imageWidth, imageHeight)
    Gdip_DisposeImage(bitmap)
    scale := Min(1, Max(280, vars.client.w * 0.45) / Max(1, imageWidth)
        , Max(200, vars.client.h * 0.72) / Max(1, imageHeight))
    width := Round(imageWidth * scale)
    Gui, BGLayout: Add, Picture, w%width% h-1, %path%
    Gui, BGLayout: Show, % "NA AutoSize x" (vars.client.x + 18) " y" (vars.client.y + 55)
    BuildGuide.layout := layout
}

BuildGuide_StepLayout(delta)
{
    global BuildGuide
    count := BuildGuide.layoutImages.Count()
    if (count < 2)
        return
    BuildGuide.layoutPage := Mod(BuildGuide.layoutPage - 1 + delta + count, count) + 1
    BuildGuide_DrawLayout()
}

BuildGuide_Focused()
{
    global BuildGuide, vars
    active := WinActive("A")
    return active && (active = vars.hwnd.poe_client || active = BuildGuide.panel)
}

BuildGuide_UpdateClock()
{
    global BuildGuide, vars
    if !IsObject(BuildGuide.run) || !BuildGuide_Focused() || BuildGuide.leveling
    {
        if BuildGuide.clock
            Gui, BGClock: Hide
        return
    }
    if !BuildGuide.clock
    {
        global BGClockText
        Gui, BGClock: New, -Caption +AlwaysOnTop +ToolWindow +E0x20 +Hwndclock
        Gui, BGClock: Color, 21162E
        Gui, BGClock: Font, s9 cF2E0B6, Segoe UI
        Gui, BGClock: Margin, 8, 5
        Gui, BGClock: Add, Text, w300 vBGClockText
        BuildGuide.clock := clock
    }
    GuiControl, BGClock:, BGClockText, % BuildGuide_TimeText()
    Gui, BGClock: Show, % "NA x" (vars.client.x + vars.client.w - 325) " y" (vars.client.y + 42)
}

BuildGuide_Tick()
{
    global BuildGuide, vars, settings
    if (BuildGuide.profile != settings.leveltracker.profile)
    {
        BuildGuide.routeProfile := -1
        BuildGuide_LoadCached()
        Gui, BGEditor: Destroy
        if BuildGuide.panel && DllCall("IsWindowVisible", "Ptr", BuildGuide.panel)
        {
            if IsObject(BuildGuide.guide)
                BuildGuide_DrawPanel()
            else
                Gui, BGPanel: Hide
        }
    }
    if BuildGuide.panel && DllCall("IsWindowVisible", "Ptr", BuildGuide.panel) && !BuildGuide_Focused()
    {
        if !WinActive("ahk_class AutoHotkeyGUI ahk_pid " DllCall("GetCurrentProcessId"))
            Gui, BGPanel: Hide
    }
    act := vars.log.act
    if (act != BuildGuide.lastAct && act >= 1 && act <= 10)
    {
        old := BuildGuide.stage
        BuildGuide.manual := 0
        BuildGuide_SetAct(act)
        BuildGuide.lastAct := act
        if (old != BuildGuide.stage && BuildGuide.panel && DllCall("IsWindowVisible", "Ptr", BuildGuide.panel))
            BuildGuide_DrawPanel()
    }
    run := BuildGuide.run
    if IsObject(run)
    {
        BuildGuide_AdvanceTime(run, A_TickCount, vars.log.areaID, BuildGuide_AreaName(vars.log.areaID), vars.log.areaseed
            , BuildGuide_Focused())
        if !run.saved && vars.log.act = 11 && run.splits.Count()
            BuildGuide_Finish(true)
    }
    if BuildGuide.leveling && BuildGuide_Focused()
        BuildGuide_LoadRoute()
    BuildGuide_UpdateRoute()
    BuildGuide_UpdateClock()
    BuildGuide_UpdateLeveling()
    if (BuildGuide.panel && DllCall("IsWindowVisible", "Ptr", BuildGuide.panel))
    {
        GuiControl, BGPanel:, BGTime, % BuildGuide_TimeText()
        if (BuildGuide.tab = 5 && IsObject(run) && BuildGuide.lastSplitCount != run.splits.Count())
        {
            BuildGuide.lastSplitCount := run.splits.Count()
            GuiControl, BGPanel:, BGText, % BuildGuide_RunDetails()
        }
    }
}

BuildGuide_AdvanceTime(run, tick, area, name, seed, focused)
{
    if run.saved
        return
    delta := Max(0, Min(tick - run.tick, 1500))
    if !run.paused && focused && run.focused && run.zone && run.zone != "login"
        run.total += delta, run.zoneTime += delta
    run.tick := tick, run.focused := focused
    if (area != "" && (area != run.zone || (seed != "" && seed != run.seed)))
    {
        if run.zone && run.zone != "login"
            run.splits.Push({id: run.zone, name: run.name, ms: run.zoneTime})
        run.zone := area, run.name := name, run.seed := seed, run.zoneTime := 0
    }
    else if name
        run.name := name
}

BuildGuide_Run()
{
    global BuildGuide, vars, settings
    if !IsObject(BuildGuide.run) || BuildGuide.run.saved
    {
        profile := settings.leveltracker.profile
        mode := settings.leveltracker["guide" profile].info.leaguestart ? "Início de liga" : "Segundo personagem"
        BuildGuide.run := {started: A_NowUTC, tick: A_TickCount, total: 0, zoneTime: 0, splits: []
            , eligible: vars.log.areaID = "1_1_1"
            , profile: profile ? profile : 1, mode: mode, zone: vars.log.areaID, name: vars.log.areaname
            , seed: vars.log.areaseed, focused: false}
        BuildGuide.lastAct := 0, BuildGuide.manual := 0
    }
    else
        BuildGuide.run.paused := !BuildGuide.run.paused
}

BuildGuide_Finish(automatic := false)
{
    global BuildGuide, vars
    run := BuildGuide.run
    if !IsObject(run) || run.saved
        return
    if !automatic && vars.log.act != 11
    {
        MsgBox, 36, Finalizar campanha, Salvar como tentativa parcial?
        IfMsgBox, No
            return
    }
    run.complete := vars.log.act = 11, run.paused := true
    snapshot := run.Clone(), snapshot.splits := run.splits.Clone()
    if run.zone && run.zone != "login"
        snapshot.splits.Push({id: run.zone, name: run.name, ms: run.zoneTime})
    path := BuildGuide.directory "\runs.json"
    history := []
    try
    {
        if FileExist(path)
        {
            FileRead, raw, *P65001 %path%
            history := JSON.Load(raw)
        }
        history.Push(snapshot)
        BuildGuide_Write(path, JSON.Dump(history,, 2))
    }
    catch error
    {
        if !automatic
            MsgBox, 48, Salvar run, % error.Message
        return
    }
    run.saved := true
}

BuildGuide_Duration(ms)
{
    seconds := Floor(ms / 1000)
    return Format("{:02}:{:02}:{:02}", seconds // 3600, Mod(seconds // 60, 60), Mod(seconds, 60))
}

BuildGuide_TimeText()
{
    global BuildGuide
    run := BuildGuide.run
    if !IsObject(run)
        return "Cronômetro pronto · F10 para iniciar"
    state := run.saved ? "Salva" : run.paused ? "Em pausa" : "Em andamento"
    return state "   |   Zona " BuildGuide_Duration(run.zoneTime) "   |   Total " BuildGuide_Duration(run.total)
}

BuildGuide_RunDetails()
{
    global BuildGuide
    run := BuildGuide.run
    text := BuildGuide_TimeText()
    if !IsObject(run)
        return text
    for _, split in run.splits
        text .= Chr(13) Chr(10) BuildGuide_Duration(split.ms) "  " (split.name ? split.name : split.id)
    return text Chr(13) Chr(10) BuildGuide_Duration(run.zoneTime) "  " (run.name ? run.name : run.zone)
}

BuildGuide_Records()
{
    global BuildGuide
    path := BuildGuide.directory "\runs.json"
    if !FileExist(path)
    {
        MsgBox, 64, Recordes, Ainda não há runs salvas.
        return
    }
    FileRead, raw, *P65001 %path%
    try history := JSON.Load(raw)
    catch
    {
        MsgBox, 48, Recordes, Não foi possível ler runs.json.
        return
    }
    best := {}, rows := ""
    for _, run in history
    {
        key := "Perfil " run.profile " · " run.mode
        if run.complete && run.eligible && (!best.HasKey(key) || run.total < best[key])
            best[key] := run.total
        rows .= Chr(13) Chr(10) BuildGuide_Duration(run.total) " · " key (run.complete && run.eligible ? "" : " · parcial")
    }
    text := ""
    for key, time in best
        text .= BuildGuide_Duration(time) " · " key Chr(13) Chr(10)
    text := (text ? text : "Nenhuma run completa") Chr(13) Chr(10) "Histórico" rows
    Gui, BGRecords: Destroy
    Gui, BGRecords: New, +AlwaysOnTop +ToolWindow, Recordes
    BuildGuide_Theme("BGRecords")
    Gui, BGRecords: Add, Edit, w520 r14 ReadOnly, %text%
    Gui, BGRecords: Show
}

#If !vars.poe_version && BuildGuide_Focused()
F5::BuildGuide_ChooseTab(6)
F6::BuildGuide_ChooseTab(1)
F7::BuildGuide_ChooseTab(2)
F8::BuildGuide_TreeHold()
F9::BuildGuide_Layout()
F10::BuildGuide_Run()
^F10::BuildGuide_Finish()
F11::BuildGuide_ChooseTab(5)
#If !vars.poe_version && (BuildGuide_Focused() || WinActive("ahk_id " BuildGuide.help))
^l::BuildGuide_ToggleHelp()
#If BuildGuide.layout && GetKeyState("F9", "P") && BuildGuide_Focused()
[::BuildGuide_StepLayout(-1)
]::BuildGuide_StepLayout(1)
#If

BuildGuide_SelfTest(xmlPath, report, logPath := "", profileDirectory := "")
{
    global BuildGuide, db, vars, settings
    try
    {
        FileRead, raw, *P65001 %xmlPath%
        guide := BuildGuide_Parse(raw)
        code := BuildGuide_Encode(raw)
        if (BuildGuide_Decode(code) != raw)
            throw Exception("PoB compressed round trip failed.")
        if (guide.stages.Count() < 3 || guide.trees.Count() < 3 || guide.sets.Count() < 2)
            throw Exception("Missing stages, trees or gear.")
        if (guide.stages[1].act != 1 || guide.stages[4].gear != 2 || guide.stages[4].tree != 4)
            throw Exception("Stage tags did not match expected act transitions.")
        foundJewel := false, foundFlask := false, foundUnique := false
        for _, tree in guide.trees
            for _, id in tree.sockets
                if IsObject(guide.items[id])
                    foundJewel := true
        for _, item in guide.items
            if (item.rarity = "UNIQUE" && item.rolls.Count())
                foundUnique := true
        for _, set in guide.sets
            for _, slot in set.slots
                if RegExMatch(slot.name, "i)^Flask")
                    foundFlask := true
        if !foundJewel || !foundFlask || !foundUnique
            throw Exception("Jewel " foundJewel ", flask " foundFlask ", unique " foundUnique ".")
        BuildGuide := {stage: 1, priorities: {}, tab: 1, guide: guide, directory: "build-guide"}
        FileRead, gems, *P65001 data\english\[leveltracker] gems.json
        db := {leveltracker: {gems: JSON.Load(gems)}}
        gemText := BuildGuide_Text(guide, guide.stages[1], 1)
        if !InStr(gemText, "Essence Drain") || !InStr(gemText, "Nessa") || !InStr(gemText, "Orb of Transmutation")
            throw Exception("Gem links or vendor text missing. " SubStr(gemText, 1, 700))
        gearText := BuildGuide_Text(guide, guide.stages[1], 2)
        if !InStr(gearText, "Mods do PoB")
            throw Exception("Gear roll text missing.")
        run := {tick: 1000, focused: true, total: 0, zoneTime: 0, splits: [], zone: "first", seed: 1}
        BuildGuide_AdvanceTime(run, 1250, "first", "A", 1, true)
        BuildGuide_AdvanceTime(run, 1500, "second", "B", 2, true)
        BuildGuide_AdvanceTime(run, 1750, "second", "B", 2, false)
        if (run.total != 500 || run.splits[1].ms != 500 || run.zone != "second")
            throw Exception("Zone split timing failed.")
        actual := {version: "3_29", nodes: "2,3", masteries: {3: 11}}
        specs := [{version: "3_29", nodes: [1, 2, 3], masteries: {3: 11}}
            , {version: "3_29", nodes: [1, 3, 4], masteries: {3: 11}}]
        db.leveltracker.trees := {"3_29": {nodes: {1: {classstartindex: 0}}}}
        progress := BuildGuide_CheckTreeProgress(specs, 1, actual)
        if (progress.index != 2 || progress.missing != 1 || progress.remove != 1 || progress.complete)
            throw Exception("A comparação de passivas não avançou para o próximo objetivo.")
        actual.nodes := "3,4", actual.masteries[3] := 10
        progress := BuildGuide_CheckTreeProgress(specs, 2, actual)
        if (progress.complete || progress.missing != 1 || progress.remove != 0)
            throw Exception("Uma maestria divergente foi aceita.")
        actual.masteries[3] := 11
        if !BuildGuide_CheckTreeProgress(specs, 2, actual).complete
            throw Exception("A última árvore deveria estar concluída.")
        links := BuildGuide_LinkGroups({groups: [{gems: [{name: "Arcane Surge", support: true, count: 1}
            , {name: "Essence Drain", support: false, count: 1}]}]}, true)
        if (links != "Essence Drain" Chr(13) Chr(10) "  • Arcane Surge")
            throw Exception("As gemas não foram agrupadas como habilidade e suportes.")
        BuildGuide_DrawPanel(true)
        GuiControlGet, panelText, BGPanel:, BGText
        if !InStr(panelText, "Essence Drain")
            throw Exception("Panel content did not render.")
        BuildGuide_ChooseTab(2)
        GuiControlGet, panelText, BGPanel:, BGText
        if !InStr(panelText, "Mods do PoB")
            throw Exception("Equipment tab did not render.")
        vars := {hwnd: {}, client: {x: 0, y: 0, w: 1280, h: 720}, log: {act: 1, areaID: "1_1_1"}
            , leveltracker: {guide: {progress: 0}}, lang: Lang_Load("english\UI.txt")}
        for key, value in Lang_Load("english\client.txt")
            vars.lang[key] := value
        settings := {general: {lang: "english", lang_client: "english"}
            , leveltracker: {guide: {info: {gems: 1, leaguestart: 1}}}}
        DB_Load("leveltracker")
        route := vars.leveltracker.guide
        route.import := [["kill Hillock", "enter areaid1_1_town"], ["enter areaid1_1_2"]
            , ["activate (img:waypoint)"], ["enter areaid1_1_3"], ["enter areaid1_1_town"]]
        route.acquisitions := [[{gem: "essence drain", quest: "the caged brute2", buy: 1}]]
        if (BuildGuide_RouteArrival("1_1_town", "1_1_1") != 2)
            throw Exception("Entrar na cidade não avançou para a etapa seguinte.")
        route.progress := 1
        if BuildGuide_RouteArrival("1_1_town", "1_1_3")
            throw Exception("Voltar à cidade adiantou a rota.")
        route.progress := 2
        if (BuildGuide_RouteArrival("1_1_3", "1_1_2") != 5)
            throw Exception("A chegada não passou pelo objetivo sem destino.")
        route.progress := 0
        BuildGuide.preferenceFile := report ".ini"
        BuildGuide.routeProfile := 1, BuildGuide.routeLastArea := "1_1_1"
        Gui, BGTestGame: New, +Hwndgame, Janela de teste
        Gui, BGTestGame: Show, w300 h180
        vars.hwnd.poe_client := game
        vars.log.file_location := "Client.txt"
        BuildGuide.leveling := true
        BuildGuide_Tick()
        GuiControlGet, compactGems, BGLeveling:, BGLevelGems
        GuiControlGet, compactRoute, BGLeveling:, BGLevelRoute
        GuiControlGet, compactArea, BGLeveling:, BGLevelArea
        GuiControlGet, compactNext, BGLeveling:, BGLevelDestination
        if !BuildGuide.leveling || !DllCall("IsWindowVisible", "Ptr", BuildGuide.levelingHwnd)
            || !InStr(compactGems, "Compre Essence Drain") || !InStr(compactGems, "Nessa")
            || !InStr(compactGems, "Orb of Transmutation") || !InStr(compactRoute, "Derrote Hillock")
            || !InStr(compactArea, "Twilight Strand") || !InStr(compactNext, "Lioneye's Watch")
            || IsObject(BuildGuide.run)
            throw Exception("O painel compacto não mostrou a rota e as gemas automaticamente.")
        BGStartLeveling()
        if !IsObject(BuildGuide.run)
            throw Exception("Iniciar leveling não ligou o cronômetro.")
        Gui, BGTestAway: New, +Hwndaway, Teste fora do jogo
        Gui, BGTestAway: Show, w200 h100
        BuildGuide_UpdateLeveling()
        if DllCall("IsWindowVisible", "Ptr", BuildGuide.levelingHwnd)
            throw Exception("O painel compacto permaneceu visível fora do jogo.")
        Gui, BGTestAway: Destroy
        WinActivate, ahk_id %game%
        BuildGuide_UpdateLeveling()
        if !DllCall("IsWindowVisible", "Ptr", BuildGuide.levelingHwnd)
            throw Exception("O painel compacto não voltou ao focar o jogo.")
        BGHideLeveling()
        if DllCall("IsWindowVisible", "Ptr", BuildGuide.levelingHwnd)
            || LLK_IniRead(BuildGuide.preferenceFile, "Overlay", "campanha", 1)
            throw Exception("O painel compacto permaneceu visível.")
        FileDelete, % BuildGuide.preferenceFile
        Gui, BGTestGame: Destroy
        Gui, BGLeveling: Destroy
        Gui, BGPanel: Destroy
        if logPath
        {
            vars.log := {file_location: logPath, latest_location: logPath ".empty"}
            vars.general := {}
            Init_log()
            if !vars.log.areaID || !vars.log.areaname || !vars.log.act
                throw Exception("O log do PoE não identificou a zona e o ato na inicialização.")
            if (vars.log.file.Tell() != vars.log.file.Length)
                throw Exception("A leitura ao vivo não continuou pelo Client.txt.")
            logResult := " Client.txt: " vars.log.areaname " (Ato " vars.log.act ")."
            vars.log.file.Close()
        }
        if profileDirectory
        {
            ini := IniBatchRead(profileDirectory "\ini\leveling guide.ini")
            settings.leveltracker.guide.info := ini.info
            settings.leveltracker.guide.info.gems := 1
            vars.leveltracker["PoB"] := {class: ini.pob.class, gems: JSON.Load(ini.pob.gems)
                , vendors: ini.pob.vendors ? JSON.Load(ini.pob.vendors) : {}}
            SetWorkingDir, %profileDirectory%
            try Leveltracker_Load()
            finally
                SetWorkingDir, %A_ScriptDir%
            route := vars.leveltracker.guide, acquisitionCount := 0
            if (route.acquisitions.Count() != route.import.Count())
                throw Exception("A lista de gemas não acompanhou as etapas da rota.")
            for _, entries in route.acquisitions
                acquisitionCount += entries.Count()
            if (!route.import.Count() || !acquisitionCount)
                throw Exception("O perfil importado não gerou compras nem recompensas.")
            current := BuildGuide_RouteStep(route.progress + 1)
            if vars.log.areaID && IsObject(current) && (arrival := BuildGuide_RouteArrival(vars.log.areaID, ""))
                route.progress := arrival - 1
            current := BuildGuide_RouteStep(route.progress + 1)
            if !IsObject(current) || !current.lines.Count()
                throw Exception("O perfil importado não encontrou uma etapa para a zona do log.")
            routeResult := " " route.import.Count() " páginas; " acquisitionCount " aquisições; etapa " current.index "."
        }
        temp := report ".write"
        BuildGuide_Write(temp, "Joia · preço")
        FileRead, written, *P65001 %temp%
        FileDelete, %temp%
        if (written != "Joia · preço")
            throw Exception("UTF-8 cache write failed.")
        output := "PASS " guide.stages.Count() " stages; " guide.trees.Count() " trees; " guide.sets.Count() " gear sets." logResult routeResult
    }
    catch error
        output := "FAIL " error.Message " (line " error.Line ", " error.Extra ")"
    FileAppend, %output%, %report%, UTF-8
}
