" Return a list of lines that make up the doc block
function! phpdoc#function#parse(codeBlock)

    " Get the indentation level from the first line
    let l:indent = matchstr(a:codeBlock, '\v^\s*')

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
" TODO: If return value is a variable, trace it back to determine type
" Returns a single DocBlock line: @return <type>
function! s:parseFunctionReturn(codeBlock)
    " Match a return keyword at the start of a line (must be 1 return only)
    let l:numOfReturns = len(split(a:codeBlock, '\vreturn%(\s|\n)+[^;]+[;]')) - 1
    if l:numOfReturns == 1
        " Get the return statement value including syntax
        let l:returnValue = matchlist(a:codeBlock, '\vreturn%(\s|\n)+(.{-})%(\s|\n)*[;]')
        let l:returnType = s:getPhpType(l:returnValue[1])
        return " * @return ".l:returnType
    endif
    return ""
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
