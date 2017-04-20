" :PHPDocBlocks command
command! -nargs=0 PHPDocBlocks :call phpdocblocks#insert()

" Add '@return void' to procedures 
let g:phpdocblocks_return_void = 1


" Inserts a doc block above the current cursor line
function! phpdocblocks#insert(...)

    let l:cursorLineContent = getline('.')
    let l:cursorLineNum = line('.')

    " Default error
    let l:output = ['error', 'Can''t find anything to document. (Move cursor to a line with a keyword)']

    " Function
    if matchstr(l:cursorLineContent, '\vfunction(\s|$)+') != ""
        let l:codeBlock = s:codeBlockWithoutStringContent()
        let l:output = phpdocblocks#function#parse(l:codeBlock)
    endif

    if l:output[0] == 'error'
        " Errors while testing need to be output to the buffer
        if a:0 > 0 && a:1 == "test"
            call append((l:cursorLineNum-1), "====== ERROR ======")
            call append((l:cursorLineNum), l:output[1])
            call append((l:cursorLineNum+1), "===================")
        else
             execute "echohl Error | echon 'PHPDocBlocks: '.l:output[1] | echohl Normal"
        endif
    elseif len(l:output) > 0
        call append((l:cursorLineNum-1), l:output)
    endif

endfunction


" Return the code block as a string
function! s:codeBlockWithoutStringContent()

    let l:codeBlock = ""
    let l:depth = 0
    let l:lineNumber = line('.')
    let l:totalLinesInDocument = line('$')

    while l:lineNumber <= l:totalLinesInDocument
        let l:line = getline(l:lineNumber)
        let l:line = s:removeStringContent(l:line)
        let l:openingBraceCount = len(split(l:line, '\v\{', 1)) - 1
        if l:openingBraceCount > 0
            let l:depth += l:openingBraceCount
        endif
        let l:closingBraceCount = len(split(l:line, '\v\}', 1)) - 1
        if l:closingBraceCount > 0
            let l:depth -= l:closingBraceCount
        endif
        let l:codeBlock .= l:line."\n"
        if l:depth == 0 && l:closingBraceCount > 0
            break
        endif
        let l:lineNumber += 1
    endwhile

    return l:codeBlock

endfunction


function! s:removeEscapedQuotes(string)
    return substitute(a:string, '\v\\"|\\''', "", "g")
endfunction


function! s:removeStringContent(string)
    let l:string = s:removeEscapedQuotes(a:string)
    return substitute(l:string, '\v".{-}"|''.{-}''', "\"\"", "g")
endfunction
