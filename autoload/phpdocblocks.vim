" :PHPDocBlocks command
command! -nargs=0 PHPDocBlocks :call phpdocblocks#insert()

" Add '@return void' to procedures 
let g:phpdocblocks_return_void = 1

" Inserts a doc block above the current cursor line
function! phpdocblocks#insert(...)

    let l:cursorLineContent = getline('.')
    let l:cursorLineNum = line('.')
    let l:output = []
    let l:code = ""

    if matchstr(l:cursorLineContent, '\vfunction(\s|$)+') != ""
        let l:code = s:codeWithoutStringContent("block")
        let l:docData = phpdocblocks#function#parse(l:code)
        if type(l:docData) == v:t_dict
            let l:output += s:docTemplate(l:docData, "function")
        elseif type(l:docData) == v:t_list
            let l:output += l:docData
        endif
    elseif matchstr(l:cursorLineContent, '\v\${1}\w+') != ""
        let l:code = s:codeWithoutStringContent("variable")
        let l:docData = phpdocblocks#variable#parse(l:code)
        if type(l:docData) == v:t_dict && type(l:docData["variable"]) == v:t_string
            let l:output += s:docTemplate(l:docData, "variable")
        elseif type(l:docData) == v:t_dict && type(l:docData["variable"]) == v:t_list
            let l:output += s:docTemplate(l:docData, "multiple-variables")
        elseif type(l:docData) == v:t_list
            let l:output += l:docData
        endif
    else
        let l:output = ['error', 'Can''t find anything to document. (Move cursor to a line with a keyword)']
    endif

    if l:output[0] == 'error'
        " Errors while testing need to be output to the buffer
        if a:0 > 0 && a:1 == "test"
            call append((l:cursorLineNum-1), "====== ERROR ======")
            call append((l:cursorLineNum), l:output[1])
            call append((l:cursorLineNum+1), "===================")
            call append((l:cursorLineNum-1), l:code)
        else
             execute "echohl Error | echon 'PHPDocBlocks: '.l:output[1] | echohl Normal"
        endif
   elseif len(l:output) > 0
        " Add indent
        let l:indent = matchstr(l:code, '\v^\s*')
        let l:indentedOutput = []
        for l:o in l:output
            let l:indentedOutput += [l:indent.l:o]
        endfor
        call append((l:cursorLineNum-1), l:indentedOutput)
        "call append((l:cursorLineNum-1), l:code)
    endif

endfunction


" Return PHP type based on the syntax of a string
function! phpdocblocks#getPhpType(syntax)
    " Starts with ' or " (string)
    if matchstr(a:syntax, '\v^''|"') != ""
        return "string"
    " A whole number
    elseif matchstr(a:syntax, '\v^[-+]{0,1}[0-9]+$') != ""
        return "int"
    " A number with a decimal
    elseif matchstr(a:syntax, '\v^[-+]{0,1}[0-9]+\.[0-9]+$') != ""
        return "float"
    " Is boolean - case insensitive
    elseif matchstr(a:syntax, '\v\c^true|false$') != ""
        return "bool"
    " Matches [] or array() - case insensitive
    elseif matchstr(a:syntax, '\v\c^\[\]|array\(\)$') != ""
        return "array"
    " Null - case insensitive
    elseif matchstr(a:syntax, '\v\c^null$') != ""
        return "null"
    " Object instantiation - case insensitive
    elseif matchstr(a:syntax, '\v\c^new \w+') != ""
        let l:instantiation = matchlist(a:syntax, '\v\c^new (\w+)')
        return l:instantiation[1]
    endif
    return ""
endfunction


" Remove everything inside array declarations
function! s:removeArrayContents(string)
    let l:chars = split(a:string, '\zs')
    let l:string = ""
    let l:squareDepth = 0
    let l:roundDepth = 0
    let l:i = -1
    for l:char in l:chars
        let l:i += 1
        if l:char == "["
            if l:squareDepth == 0 && l:roundDepth == 0
                let l:string .= l:char
            endif
            let l:squareDepth += 1
            continue
        elseif l:char == "]" && l:squareDepth != 0
            if l:squareDepth == 1 && l:roundDepth ==0
                let l:string .= l:char
            endif
            let l:squareDepth -= 1
            continue
        elseif l:char == "(" && a:string[l:i-5:l:i-1] == "array"
            if l:roundDepth == 0 && l:squareDepth == 0
                let l:string .= l:char
            endif
            let l:roundDepth += 1
            continue
        elseif l:char == ")" && l:roundDepth != 0
            if l:roundDepth == 1 && l:squareDepth == 0
                let l:string .= l:char
            endif
            let l:roundDepth -= 1
            continue
        endif
        if l:squareDepth == 0 && l:roundDepth == 0
            let l:string .= l:char
        endif
    endfor
    return l:string
endfunction


" Remove everything inside parentheses
function! s:removeParenthesesContents(string)
    let l:chars = split(a:string, '\zs')
    let l:string = ""
    let l:depth = 0
    for l:char in l:chars
        if l:char == "("
            if l:depth == 0
                let l:string .= l:char
            endif
            let l:depth += 1
            continue
        elseif l:char == ")"
            if l:depth == 1
                let l:string .= l:char
            endif
            let l:depth -= 1
            continue
        endif
        if l:depth == 0
            let l:string .= l:char
        endif
    endfor
    return l:string
endfunction


" Compose a doc block from a template
function! s:docTemplate(docData, docType)
    let l:path = fnamemodify(resolve(expand('<sfile>:p')), ':h')
    let l:templateLines = readfile(l:path."/PHPDocBlocks.vim/templates/".a:docType.".tpl")
    let l:output = []
    for l:templateLine in l:templateLines
        if l:templateLine[0] != "#" && l:templateLine != ""
            let l:tagName = matchlist(l:templateLine, '\v\c\{\{[ ]*(.{-})[ ]*\}\}')
            if l:tagName != []
                let l:output += s:transformTemplateLine(a:docData, l:tagName[1], l:templateLine)
            else
                call add(l:output, l:templateLine)
            endif
        endif
    endfor
    return l:output
endfunction


" Convert template tags to documentation data
function! s:transformTemplateLine(docData, tagName, templateLine)
    let l:output = []
    if has_key(a:docData, a:tagName)
        let l:lineRegex = '\v^(.{-})\{\{[ ]*'.a:tagName.'[ ]*\}\}(.{-})$'
        let l:linePart = matchlist(a:templateLine, l:lineRegex)
        if type(a:docData[a:tagName]) == v:t_list
            for l:data in a:docData[a:tagName]
                call add(l:output, l:linePart[1].l:data.l:linePart[2])
            endfor
        else
            call add(l:output, l:linePart[1].a:docData[a:tagName].l:linePart[2])
        endif
    endif
    return l:output
endfunction


" Return the code block as a string
function! s:codeWithoutStringContent(type)

    let l:code = ""
    let l:blockDepth = 0
    let l:lineNumber = line('.')
    let l:totalLinesInDocument = line('$')
    let l:isDoubleQuoteString = 0
    let l:isSingleQuoteString = 0

    while l:lineNumber <= l:totalLinesInDocument
        let l:line = getline(l:lineNumber)
        " Remove escaped quotes
        let l:line = substitute(l:line, '\v\\"|\\''', "", "g")
        " Remove all string content over multiple lines
        let l:chars = split(l:line, '\zs')
        let l:line = ""
        for l:char in l:chars
            if l:isSingleQuoteString == 0 && l:isDoubleQuoteString == 0
                if l:char == "'"
                    let l:isSingleQuoteString = 1
                    let l:line .= "'"
                elseif l:char == '"'
                    let l:isDoubleQuoteString = 1
                    let l:line .= '"'
                else
                    let l:line .= l:char
                endif
            elseif l:isSingleQuoteString == 1
                if l:char == "'"
                    let l:isSingleQuoteString = 0
                    let l:line .= "'"
                endif
            elseif l:isDoubleQuoteString == 1
                if l:char == '"'
                    let l:isDoubleQuoteString = 0
                    let l:line .= '"'
                endif
            endif
        endfor
        if a:type == "block"
            " Find the closing brace for the code block
            let l:openingBraceCount = len(split(l:line, '\v\{', 1)) - 1
            if l:openingBraceCount > 0
                let l:blockDepth += l:openingBraceCount
            endif
            let l:closingBraceCount = len(split(l:line, '\v\}', 1)) - 1
            if l:closingBraceCount > 0
                let l:blockDepth -= l:closingBraceCount
            endif
            let l:code .= l:line
            if l:blockDepth == 0 && l:closingBraceCount > 0
                break
            endif
        elseif a:type == "variable"
            let l:semicolonPosition = matchstrpos(l:line, ";")
            if l:semicolonPosition[2] == -1
                let l:code .= l:line
            else
                let l:code .= l:line[0:l:semicolonPosition[2]]
                break
            endif
        endif
        let l:lineNumber += 1
    endwhile

    let l:code = s:removeArrayContents(l:code)
    if a:type == "variable"
        let l:code = s:removeParenthesesContents(l:code)
    endif
    return l:code

endfunction
