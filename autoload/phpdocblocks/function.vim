" Return a list of lines that make up the doc block
function! phpdocblocks#function#parse(codeBlock)

    " Get the indentation level from the first line
    let l:indent = matchstr(a:codeBlock, '\v^\s*')

    " Match a valid function syntax, capture the name and parameters
    let l:functionPartsRegex = '\vfunction%(\s|\n)+(\S+)%(\s|\n)*\((.{-})\)[:]{0,1}%(\s|\n)*%(\w*)%(\s|\n)*\{'
    let l:functionParts = matchlist(a:codeBlock, l:functionPartsRegex)

    if l:functionParts != []
        let l:parameters = l:functionParts[2]
        let l:name = l:functionParts[1]
    else
        return ["error","Invalid PHP function declaration on this line."]
    endif

    " @param
    let l:param = s:parseFunctionParameters(l:parameters)

    " @throws
    let l:throws = s:parseFunctionThrows(a:codeBlock)

    " @return
    let l:return = s:parseFunctionReturn(a:codeBlock)

    " Viml list of lines to append as the PHP documentaion block
    let l:phpDocBlock = ["/**",
                   \" * ".l:name,
                   \" *"] + l:param + l:throws
    if l:return != ""
        call add(l:phpDocBlock, l:return)
    endif
    call add(l:phpDocBlock, " */")

    " Loop through each line and add the appropriate indent
    let l:x = 0
    for i in l:phpDocBlock
        let l:phpDocBlock[l:x] = l:indent."".l:phpDocBlock[l:x]
        let l:x += 1
    endfor

    return l:phpDocBlock

endfunction


" Returns a single DocBlock line: @return <type>
function! s:parseFunctionReturn(codeBlock)

    let l:codeBlock = s:removeArrayContents(a:codeBlock)

    let l:declaredReturnRegex = '\vfunction%(\s|\n)+%(\S+)%(\s|\n)*\(%(.{-})\)[:]{0,1}%(\s|\n)*(\w*)%(\s|\n)*\{'
    let l:declaredReturn = matchlist(l:codeBlock, l:declaredReturnRegex)
    if l:declaredReturn[1] != ""
        return " * @return ".l:declaredReturn[1]
    endif

    let l:matchPosition = ["",0,0]
    let l:returnRegex = '\vreturn%(\s|\n)+(.{-})%(\s|\n)*[;]'
    let l:returnTypes = []
    let l:declaredReturn = matchlist(l:codeBlock, l:declaredReturnRegex)

    if matchstr(l:codeBlock, l:returnRegex) != ""

        while 1
            " Start matching from the end of the last match
            let l:matchPosition = matchstrpos(l:codeBlock, l:returnRegex, l:matchPosition[2])
            if l:matchPosition[2] != -1
                let l:returnValue = matchlist(l:matchPosition[0], l:returnRegex)
                if len(l:returnValue) > 1
                    let l:returnType = s:getPhpType(l:returnValue[1])
                endif
                call add(l:returnTypes, l:returnType)
                continue
            endif
            break
        endwhile

        let l:sameReturnTypes = 1
        for l:rt in l:returnTypes
            if l:rt != l:returnTypes[0]
                let l:sameReturnTypes = 0
            endif
        endfor

        let l:explicitlyNotSameReturnTypes = 1
        for l:rt in l:returnTypes
            if l:rt == ""
                let l:explicitlyNotSameReturnTypes = 0
            endif
        endfor

        if l:sameReturnTypes
            let l:returnType = l:returnTypes[0]
        elseif l:explicitlyNotSameReturnTypes
            let l:uniqueReturnTypes = s:removeDuplicateListElements(l:returnTypes)
            let l:returnType = ""
            for l:rt in l:uniqueReturnTypes
                let l:returnType .= l:rt."|"
            endfor
            let l:returnType = substitute(l:returnType, '\v\|$', "", "")
        endif

        return " * @return ".l:returnType

    endif

    if g:phpdocblocks_return_void
        return " * @return void"
    endif

    return ""

endfunction


" Returns a list of @throws DocBlock lines
function! s:parseFunctionThrows(codeBlock)

    " Match catch(Exception $var), capture exception name
    let l:catchRegex = '\v\}%(\s|\n)*catch%(\s|\n)*\(%(\s|\n)*([\\]{0,1}%(\w|\d)+)%(\s|\n)+[\$]%(\w|\d)+%(\s|\n)*\)%(\s|\n)*[{]'

    " Match throw new statement, capture the exception name
    let l:throwRegex = '\vthrow%(\s|\n)+new%(\s|\n)+(\\\u.{-}|\u.{-})%(\s|\n)*\(.{-}\)%(\s|\n)*[;]'

    " Match throw statements nested inside catch blocks
    " Limitation: Only matches whitespace / newlines between the catch block
    " declaration and the throw statement
    let l:nestedThrowRegex = l:catchRegex.'%(\s|\n)*'.l:throwRegex

    let l:exceptionSyntaxes = [l:nestedThrowRegex, l:catchRegex, l:throwRegex]
    let l:throws = []
    let l:nestedThrowCode = []
    let l:matchPosition = ["",0,0]
    let l:codeBlock = a:codeBlock
    for regex in l:exceptionSyntaxes
        while 1
            " Start matching from the end of the last match
            let l:matchPosition = matchstrpos(l:codeBlock, regex, l:matchPosition[2])
            let l:exceptionNames = matchlist(l:matchPosition[0], regex)
            if len(l:exceptionNames) > 2 && l:exceptionNames[2] != ""
                call add(l:nestedThrowCode, l:exceptionNames[0])
                " Use the nested throw exception name
                let l:exceptionNames[1] = l:exceptionNames[2]
            endif
            if l:matchPosition[2] != -1
                call add(l:throws, " * @throws ".l:exceptionNames[1])
                continue
            endif
            break
        endwhile
        " Prevent duplicate exceptions from being found
        if len(l:nestedThrowCode) > 0
            for nestedThrowCode in l:nestedThrowCode
                let nestedThrowCode = substitute(nestedThrowCode, '\\', '\\\\', "g")
                let l:codeBlock = substitute(l:codeBlock, '\M'.nestedThrowCode, "", "")
            endfor
            let l:nestedThrowCode = []
        endif
    endfor

    return l:throws

endfunction


" Returns a list of @param DocBlock lines
function! s:parseFunctionParameters(parameters)

    let l:parameters = s:removeArrayContents(a:parameters)

    " Empty parameter declaration?
    if matchstr(l:parameters, '\v^%(\s|\n)*$') != ""
        return []
    endif

    " Transform each parameter into a line to be used as a doc block
    let l:paramsList = split(l:parameters, ",")

    let l:params = []
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
        call add(l:params, " * @param  ".i)
    endfor

    return l:params

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


function! s:removeArrayContents(string)
    return substitute(a:string, '\v([\(\[])[^\]\)]*([\]\)])', '\1\2', "g")
endfunction


function! s:removeDuplicateListElements(list)
    " if an element appears more than once in the list,
    " remove it, then continue to the next element and repeat
    return filter(a:list, 'count(a:list, v:val) == 1')
endfunction
