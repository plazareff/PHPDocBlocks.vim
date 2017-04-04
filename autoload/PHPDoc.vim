" TODO: Edit existing doc block if exists
" TODO: methods, classes, consts, file, interfaces, traits
" TODO: Editable templates for each doc block type
" TODO: Tab to descriptions
" TODO: Make a :PHPDoc command that can be run or mapped 
" NOTE: %(\s|\n)* = non-capturing group to match whitespace and line breaks
" TODO: If has return statement and a throw statement in codeblock the return
" has to be mixed??

" Inserts a doc block above the current cursor line
function! PHPDoc#insert()

    let l:cursorLineContent = getline('.')
    let l:cursorLineNum = line('.')

    " Default error
    let l:phpDoc = ['error', 'Can''t find anything to document. (Move cursor to line with keyword)']

    " Function
    if matchstr(l:cursorLineContent, '\vfunction(\s|$)+') != ""
        let l:codeBlock = s:getCodeBlock("function")
        let l:phpDoc = s:parseFunction(l:codeBlock)
    endif

    if l:phpDoc[0] == 'error'
        execute "echohl Error | echon 'PHPDoc: '.l:phpDoc[1] | echohl Normal"
    elseif len(l:phpDoc) > 0
        call append((l:cursorLineNum-1), l:phpDoc)
    endif

endfunction

" Return a list of lines that make up the doc block
function! s:parseFunction(codeBlock)

    " Get the indentation level from the first line
    let l:indent = matchstr(a:codeBlock, '\v^\s+')

    " Remove escaped quotes
    let l:codeBlock = substitute(a:codeBlock, '\v\\"|\\''', "", "g")

    " Remove everything in strings for the whole code block (to remove semicolons in strings)
    let l:codeBlock = substitute(l:codeBlock, '\v".{-}"|''.{-}''', "\"\"", "g")

    " Match a valid function syntax, capture the name and parameters
    let l:nameAndParams = matchlist(l:codeBlock, '\vfunction%(\s|\n)+(\S+)%(\s|\n)*\((.{-})\)%(\s|\n)*\{')
    if l:nameAndParams == []
        return ['error','No function name detected']
    endif

    " @param
    let l:params = s:parseFunctionParams(l:nameAndParams[2])

    " @throws
    let l:throws = s:parseFunctionThrows(l:codeBlock)

    " @return
    let l:return = s:parseFunctionReturn(l:codeBlock)

    " Viml list of lines to append as the PHP documentaion block
    let l:phpDoc = ['/**',
                   \' *',
                   \' * '.l:nameAndParams[1],
                   \' *'] + l:params + l:throws
    if l:return != ""
        call add(l:phpDoc, l:return)
    endif
    call add(l:phpDoc, " */")

    " Loop through each line and add the appropriate indent
    let l:x = 0
    for i in l:phpDoc
        let l:phpDoc[l:x] = l:indent."".l:phpDoc[l:x]
        let l:x += 1
    endfor

    return l:phpDoc

endfunction

" TODO: A return in a catch block shouldn't be documented as @return?
" TODO: Test multiple return statements, if same types for all, use that
" type, if EXPLICITLY diff types, use mixed
" TODO: Look for method calls (current class only)? - if has docblock with
" return type, use that (must be the only return) (if all returns type is
" knowable and diffrerent, could use mixed as type)
" Returns a single DocBlock line: @return <type>
function! s:parseFunctionReturn(codeBlock)
    " Match a return keyword at the start of a line (must be 1 return only)
    let l:numOfReturns = len(split(a:codeBlock, '\vreturn%(\s|\n)+[^;]+[;]')) - 1
    if l:numOfReturns == 1
        " Get the return statement value including syntax
        let l:returnValue = matchlist(a:codeBlock, '\vreturn%(\s|\n)+(.{-})%(\s|\n)*[;]')
        let l:returnType = s:getPhpType(l:returnValue[1])
    else
        let l:returnType = ""
    endif
    return " * @return ".l:returnType
endfunction

" Returns a list of @throws DocBlock lines
function! s:parseFunctionThrows(codeBlock)

    " Nested 'throw new' exception name will be used instead of the exception name in the parent catch
    " Match catch(Exception $var), capture exception name
    let l:catchRegex = '\v\}%(\s|\n)*catch%(\s|\n)*\(%(\s|\n)*(.{-})%(\s|\n)+[\$].{-}%(\s|\n)*\)%(\s|\n)*\{'

    " Match throw new statement, capture the exception name
    let l:throwNewRegex = '\vthrow%(\s|\n)+new%(\s|\n)+(\\\u.{-}|\u.{-})%(\s|\n)*\(.{-}\)%(\s|\n)*[;]'

    let l:exceptionSyntaxes = [l:catchRegex.'.{-}'.l:throwNewRegex.'.{-}\}',
                              \l:catchRegex,
                              \l:throwNewRegex]
    let l:throws = []
    let l:matchPos = ["",0,0]
    let l:codeBlock = a:codeBlock
    for regex in l:exceptionSyntaxes
        while 1
            " Start matching from the end of the last match
            let l:matchPos = matchstrpos(l:codeBlock, regex, l:matchPos[2])
            let l:captureGroups = matchlist(l:matchPos[0], regex)
            if len(l:captureGroups) > 2 && l:captureGroups[2] != ""
                " Remove whole match from codeblock so we don't get duplicates
                let l:codeBlock = substitute(l:codeBlock, regex, "", "")
                let l:captureGroups[1] = l:captureGroups[2]
            endif
            if l:matchPos[2] != -1
                call add(l:throws, " * @throws ".l:captureGroups[1])
                continue
            endif
            break
        endwhile
    endfor

    return l:throws

endfunction

" Returns a list of @param DocBlock lines
function! s:parseFunctionParams(parameterString)

    " Remove everything from PHP arrays (removes commas)
    let l:paramsString = substitute(a:parameterString, '\v([\(\[])[^\]\)]*([\]\)])', '\1\2', "g")

    " Transform each parameter into a line to be used as a doc block
    let l:paramsList = split(l:paramsString, ",")
    let l:x = 0
    for i in l:paramsList
        " Convert all whitespace and new lines to a single space globally
        let i = substitute(i, '\v(\s|\n)+', " ", "g")
        " Strip leading and trailing spaces
        let i = substitute(i, '\v^[ ]*(.{-})[ ]*$', '\1', "")
        " If has no type hint and has a '=' use the default value as the type
        if matchstr(i, '\v^[&]{0,1}\$\w+[ ]*[=][ ]*') != ""
            " Get the parameter value
            let l:paramValue = matchlist(i, '\v^[&]{0,1}\$\w+[ ]*[=][ ]*(.*)')
            let l:paramType = s:getPhpType(l:paramValue[1])
            if l:paramType != ""
                let i = l:paramType." ".i
            endif
        endif
        " Remove everything from '=' to the end of line
        let i = substitute(i, '\v[ ]*[=][ ]*(.{-})[ ]*$', "", "")
        " Function contains variable arguments (...$args)
        if matchstr(i, '\v\.\.\.\$') != ""
            " Remove ... from start then add to end with a comma
            let i = substitute(i, '\v\.\.\.', "", "")
            let i = i.",..."
            " No type hint for this parameter
            if matchstr(i, '\v^\$') != ""
                let i = "mixed ".i
            endif
        endif
        let l:paramsList[l:x] = " * @param ".i
        let l:x += 1
    endfor

    return l:paramsList

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
        execute "normal! ".l:lineNum."G0".l:bracePosOnLine[1]."l%"
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
    "call append((l:blockStart-1), getline(l:blockStart, l:blockEnd))

endfunction
