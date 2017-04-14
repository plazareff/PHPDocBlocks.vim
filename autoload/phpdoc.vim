" TODO: Edit existing doc block if exists
" TODO: methods, classes, consts, file, interfaces, traits, vars
" TODO: Editable templates for each doc block type
" TODO: Tab to descriptions
" TODO: Make a :PHPDoc command that can be run or mapped 
" NOTE: %(\s|\n)* = non-capturing group to match whitespace and line breaks
" TODO: If has return statement and a throw statement in codeblock the return
" has to be mixed??

" Inserts a doc block above the current cursor line
function! phpdoc#insert(...)

    let l:cursorLineContent = getline('.')
    let l:cursorLineNum = line('.')

    " Default error
    let l:phpDoc = ['error', 'Can''t find anything to document. (Move cursor to a line with a keyword)']

    " Function
    if matchstr(l:cursorLineContent, '\vfunction(\s|$)+') != ""
        let l:codeBlock = s:getCodeBlock("function")
        let l:phpDoc = phpdoc#function#parse(l:codeBlock)
    endif

    if l:phpDoc[0] == 'error'
        " Errors while testing need to be output to the buffer
        if a:0 > 0 && a:1 == "test"
            call append((l:cursorLineNum-1), "====== ERROR ======")
            call append((l:cursorLineNum), l:phpDoc[1])
            call append((l:cursorLineNum+1), "===================")
        else
             execute "echohl Error | echon 'PHPDoc: '.l:phpDoc[1] | echohl Normal"
        endif
    elseif len(l:phpDoc) > 0
        call append((l:cursorLineNum-1), l:phpDoc)
    endif

endfunction


" Get the code block
function! s:getCodeBlock(type)

    " Get the starting line number
    let l:blockStart = line('.')

    " For functions we need to be sure we are not matching inside default
    " parameter strings - ex: $param = ") {" could falsely match the start of
    " a block.
    " TODO: Multi-line strings?
    if a:type == "function"
        let l:lineNum = l:blockStart
        let l:i = 0
        while l:i < 10
            let l:i += 1
            let l:lineContent = getline(l:lineNum)
            " Remove escaped quotes
            let l:lineContent = substitute(l:lineContent, '\v\\"|\\''', "", "g")
            " Remove string contents
            let l:lineContent = substitute(l:lineContent, '\v".{-}"|''.{-}''', "\"\"", "g")
            " Find the real opening brace
            let l:matchBrace = matchstr(l:lineContent, '\v\{')
            if l:matchBrace == ""
                let l:lineNum += 1
                continue
            endif
            break
        endwhile
        let l:lineContent = getline(l:lineNum)
        let l:bracePosOnLine = matchstrpos(l:lineContent, '\v\{', 0)
        " Move cursor to the end of the block
        if l:bracePosOnLine[1] == 0
            let l:moveCursorLeft = ""
        else
            let l:moveCursorLeft = l:bracePosOnLine[1]."l"
        endif
        execute "normal! ".l:lineNum."G0".l:moveCursorLeft."%"
    else
        " Move cursor to the end of the block
        execute "normal! /{\<cr>%"
    endif

    " Get the last line number
    let l:blockEnd = line('.')

    " Move the cursor back to the start of the first line
    execute "normal! ".l:blockStart."G"

    " Return the code block as a string
    return join(getline(l:blockStart, l:blockEnd), "\n")
    "call append((l:blockStart-1), getline(l:blockStart, l:blockEnd)+l:bracePosOnLine)

endfunction
