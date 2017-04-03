let s:save_cpo = &cpo
set cpo&vim

" TODO: Edit existing doc block if exists
" TODO: methods (@return / @throws), classes, consts, file, interfaces, traits
" TODO: Editable templates for each doc block type
" TODO: Tab to descriptions
" TODO: Make a :PHPDoc command that can be run or mapped 


" Inserts a doc block above the current cursor line
function! PHPDoc#insert()

    let l:cursorLineContent = getline('.')
    let l:cursorLineNum = line('.')

    " Default error
    let l:phpDoc = ['error', 'Can''t find anything to document. (Move cursor to line with keyword)']

    " Function
    if matchstr(l:cursorLineContent, '\vfunction(\s|$)+') != ""
        let l:codeBlock = s:getCodeBlock()
        let l:phpDoc = s:parseFunction(l:codeBlock)
    endif

    if l:phpDoc[0] == 'error'
        execute "echohl Error | echon 'PHPDoc: '.l:phpDoc[1] | echohl Normal"
    elseif len(l:phpDoc) > 0
        call append((l:cursorLineNum-1), l:phpDoc)
    endif

endfunction

" Return PHP type based on the syntax of a string
function! s:getPhpType(syntax)
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
    endif
    return ""
endfunction

" Get the code block
function! s:getCodeBlock()

    " Get the starting line number
    let l:blockStart = line('.')

    " Move cursor to the end of the block
    execute "normal! /{\<cr>%"

    " Get the last line number
    let l:blockEnd = line('.')

    " Move the cursor back to the start of the first line
    execute "normal! ".l:blockStart."G"

    " Return the code block as a string
    return join(getline(l:blockStart, l:blockEnd), "\n")

endfunction


let &cpo = s:save_cpo
