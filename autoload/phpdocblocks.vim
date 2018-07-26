" :PHPDocBlocks command
command! -nargs=0 PHPDocBlocks :call phpdocblocks#insert()

" Add '@return void' to procedures 
let g:phpdocblocks_return_void = 1

" Inserts a doc block above the current cursor line
function! phpdocblocks#insert(...)

    let l:cursorLineContent = getline('.')
    let l:cursorLineNum = line('.')
    let l:codeBlock = s:codeBlockWithoutStringContent()
    let l:indent = matchstr(l:codeBlock, '\v^\s*')
    let l:output = []

    if matchstr(l:cursorLineContent, '\vfunction(\s|$)+') != ""
        let l:docData = phpdocblocks#function#parse(l:codeBlock)
        let l:output += s:docTemplate(l:docData, "function")
    else
        let l:output = ['error', 'Can''t find anything to document. (Move cursor to a line with a keyword)']
    endif

    if l:output[0] == 'error'
        " Errors while testing need to be output to the buffer
        if a:0 > 0 && a:1 == "test"
            call append((l:cursorLineNum-1), "====== ERROR ======")
            call append((l:cursorLineNum), l:output[1])
            call append((l:cursorLineNum+1), "===================")
            call append((l:cursorLineNum-1), l:codeBlock)
        else
             execute "echohl Error | echon 'PHPDocBlocks: '.l:output[1] | echohl Normal"
        endif
   elseif len(l:output) > 0
        " Add indent
        let l:indentedOutput = []
        for l:o in l:output
            let l:indentedOutput += [l:indent.l:o]
        endfor
        call append((l:cursorLineNum-1), l:indentedOutput)
        "call append((l:cursorLineNum-1), l:codeBlock)
    endif

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
function! s:codeBlockWithoutStringContent()

    let l:codeBlock = ""
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
        " Find the closing brace for the code block
        let l:openingBraceCount = len(split(l:line, '\v\{', 1)) - 1
        if l:openingBraceCount > 0
            let l:blockDepth += l:openingBraceCount
        endif
        let l:closingBraceCount = len(split(l:line, '\v\}', 1)) - 1
        if l:closingBraceCount > 0
            let l:blockDepth -= l:closingBraceCount
        endif
        let l:codeBlock .= l:line
        if l:blockDepth == 0 && l:closingBraceCount > 0
            break
        endif
        let l:lineNumber += 1
    endwhile

    return l:codeBlock

endfunction
