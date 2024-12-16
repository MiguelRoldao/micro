VERSION = "1.1.0"

local util = import("micro/util")
local config = import("micro/config")
local buffer = import("micro/buffer")

local ft = {}

ft["apacheconf"] = "# %s"
ft["batch"] = ":: %s"
ft["c"] = "// %s"
ft["c++"] = "// %s"
ft["cmake"] = "# %s"
ft["conf"] = "# %s"
ft["crystal"] = "# %s"
ft["css"] = "/* %s */"
ft["d"] = "// %s"
ft["dart"] = "// %s"
ft["dockerfile"] = "# %s"
ft["elm"] = "-- %s"
ft["fish"] = "# %s"
ft["freest"] = "-- %s"
ft["gdscript"] = "# %s"
ft["glsl"] = "// %s"
ft["go"] = "// %s"
ft["haskell"] = "-- %s"
ft["html"] = "<!-- %s -->"
ft["ini"] = "; %s"
ft["java"] = "// %s"
ft["javascript"] = "// %s"
ft["jinja2"] = "{# %s #}"
ft["json"] = "// %s"
ft["julia"] = "# %s"
ft["kotlin"] = "// %s"
ft["lua"] = "-- %s"
ft["markdown"] = "<!-- %s -->"
ft["nginx"] = "# %s"
ft["nim"] = "# %s"
ft["objc"] = "// %s"
ft["ocaml"] = "(* %s *)"
ft["pascal"] = "{ %s }"
ft["perl"] = "# %s"
ft["php"] = "// %s"
ft["pony"] = "// %s"
ft["powershell"] = "# %s"
ft["proto"] = "// %s"
ft["python"] = "# %s"
ft["python3"] = "# %s"
ft["ruby"] = "# %s"
ft["rust"] = "// %s"
ft["scala"] = "// %s"
ft["shell"] = "# %s"
ft["sql"] = "-- %s"
ft["swift"] = "// %s"
ft["tex"] = "% %s"
ft["toml"] = "# %s"
ft["twig"] = "{# %s #}"
ft["v"] = "// %s"
ft["xml"] = "<!-- %s -->"
ft["yaml"] = "# %s"
ft["zig"] = "// %s"
ft["zscript"] = "// %s"
ft["zsh"] = "# %s"

local last_ft

function updateCommentType(buf)
    if buf.Settings["commenttype"] == nil or (last_ft ~= buf.Settings["filetype"] and last_ft ~= nil) then
        if ft[buf.Settings["filetype"]] ~= nil then
            buf:SetOptionNative("commenttype", ft[buf.Settings["filetype"]])
        else
            buf:SetOptionNative("commenttype", "# %s")
        end

        last_ft = buf.Settings["filetype"]
    end
end

function isCommented(bp, lineN, commentRegex)
    local line = bp.Buf:Line(lineN)
    local regex = commentRegex:gsub("%s+", "%s*")
    return string.match(line, regex)
end

function commentLine(bp, lineN, indentLen)
    local line = bp.Buf:Line(lineN)
    local commentType = bp.Buf.Settings["commenttype"]
    local indent = string.sub(line, 1, indentLen)
    local trimmedLine = string.sub(line, indentLen + 1)
    trimmedLine = trimmedLine:gsub("%%", "%%%%")
    local commentedLine = commentType:gsub("%%s", trimmedLine)
    bp.Buf:Replace(buffer.Loc(0, lineN), buffer.Loc(#line, lineN), indent .. commentedLine)
end

function uncommentLine(bp, lineN, commentRegex)
    local line = bp.Buf:Line(lineN)
    if not string.match(line, commentRegex) then
        commentRegex = commentRegex:gsub("%s+", "%s*")
    end
    if string.match(line, commentRegex) then
        uncommentedLine = string.match(line, commentRegex)
        bp.Buf:Replace(buffer.Loc(0, lineN), buffer.Loc(#line, lineN), util.GetLeadingWhitespace(line) .. uncommentedLine)
    end
end

-- unused
function toggleCommentLine(bp, lineN, commentRegex)
    if isCommented(bp, lineN, commentRegex) then
        uncommentLine(bp, lineN, commentRegex)
    else
        commentLine(bp, lineN, #util.GetLeadingWhitespace(bp.Buf:Line(lineN)))
    end
end

function toggleCommentSelection(bp, lines, commentRegex)
    local allComments = true
    for line,_ in pairs(lines) do
        if not isCommented(bp, line, commentRegex) then
            allComments = false
            break
        end
    end

    -- NOTE: we assume that the indentation is either tabs only or spaces only
    local indentMin = -1
    if not allComments then
        for line,_ in pairs(lines) do
            local indentLen = #util.GetLeadingWhitespace(bp.Buf:Line(line))
            if indentMin == -1 or indentLen < indentMin then
                indentMin = indentLen
            end
        end
    end

    for line,_ in pairs(lines) do
        if allComments then
            uncommentLine(bp, line, commentRegex)
        else
            commentLine(bp, line, indentMin)
        end
    end
    return not allComments
end

function comment(bp, args)
    updateCommentType(bp.Buf)

    local commentType = bp.Buf.Settings["commenttype"]
    local commentRegex = "^%s*" .. commentType:gsub("%%","%%%%"):gsub("%$","%$"):gsub("%)","%)"):gsub("%(","%("):gsub("%?","%?"):gsub("%*", "%*"):gsub("%-", "%-"):gsub("%.", "%."):gsub("%+", "%+"):gsub("%]", "%]"):gsub("%[", "%["):gsub("%%%%s", "(.*)")

    local lines = {}
    local curData = {}
    -- gather cursor data and lines to (un)comment
    for i = 0,#bp.Buf:getCursors()-1 do
        local cursor = bp.Buf:getCursor(i)        
        local hasSelection = cursor:HasSelection()
        table.insert(curData, {
            sel = -cursor.CurSelection,
            curpos = -cursor.Loc,
            cursor = cursor,
            hasSelection = hasSelection
        })
        if hasSelection then
            for lineN = cursor.CurSelection[1].Y, cursor.CurSelection[2].Y do
                lines[lineN] = true
            end
        else
            lines[cursor.Y] = true
        end
    end
    -- (un)comment selected lines
    local commented = toggleCommentSelection(bp, lines, commentRegex)
    -- restore cursors
    local displacement = (string.find(commentType, "%%s") - 1) * (commented and 1 or -1)
    for i=1,#curData do
        local cursor = curData[i].cursor
        if curData[i].hasSelection then
            cursor.CurSelection[1].Y = curData[i].sel[1].Y
            cursor.CurSelection[2].Y = curData[i].sel[2].Y
            cursor.CurSelection[1].X = curData[i].sel[1].X + displacement
            cursor.CurSelection[2].X = curData[i].sel[2].X + displacement
        else
            cursor.Y = curData[i].curpos.Y
            cursor.X = curData[i].curpos.X + displacement
        end
        cursor:Relocate()
        cursor:StoreVisualX()
    end
end

function string.starts(String,Start)
    return string.sub(String,1,string.len(Start))==Start
end

function init()
    config.MakeCommand("comment", comment, config.NoComplete)
    config.TryBindKey("Alt-/", "lua:comment.comment", false)
    config.TryBindKey("CtrlUnderscore", "lua:comment.comment", false)
    config.AddRuntimeFile("comment", config.RTHelp, "help/comment.md")
end
