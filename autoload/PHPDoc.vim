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

" Return a list of lines that make up the doc block
function! s:parseFunction(codeBlock)

    " Get the indentation level from the first line
    let l:indent = matchstr(a:codeBlock, '\v^\s+')

    " Extract the function name and parameters from the code block
    let l:nameAndParams = matchlist(a:codeBlock, '\vfunction(\s|\n)+(\S+)(\s|\n)*\((.{-})\)(\s|\n)*\{')

    if l:nameAndParams == []
        return ['error','No function name detected']
    endif
    let l:paramsList = s:parseFunctionParameters(l:nameAndParams[4])

    " TODO: Test multiple return statements, if same types for all, use that
    " type, if EXPLICITLY diff types, use mixed
    " TODO: Look for method calls (current class only)? - if has docblock with
    " return type, use that (must be the only return) (if all returns type is
    " knowable and diffrerent, could use mixed as type)
    " Match a return keyword at the start of a line (must be 1 return only)
    let l:return = ""
    let l:numOfReturns = len(split(a:codeBlock, '\v[\n](\s)*return(\s)+[^;]+[;]')) - 1
    if l:numOfReturns == 1
        " Remove everything in strings for the whole code block (to remove semicolons in strings)
        let l:noStringContent = substitute(a:codeBlock, '\v([''"])[^''"]*([''"])', '\1\2', "g")
        " Get the return statement value including syntax
        let l:returnValue = matchlist(l:noStringContent, '\v[\n](\s)*return(\s)+(.{-})[;]')
        let l:returnType = s:getPhpType(l:returnValue)
    else
        let l:returnType = ""
    endif
    let l:return .= " * @return ".l:returnType

    " TODO: Nested throw new inside a catch block - prioritize the throw new
    " try {} catch(\Exception $var) {}
    let l:throwsRegex = ['\v\}(\s|\n)*catch(\s|\n)*\((.{-})(\s|\n)+[\$](.{-})\)(\s|\n)*\{',
                        \'\vthrow(\s|\n)+new(\s|\n)+((\\[A-Z]|[A-Z])(.{-}))\((.{-})\)[;]']
    let l:throwsList = []
    let l:throws = ["",0,0]
    for regex in l:throwsRegex
        while 1
            let l:throws = matchstrpos(a:codeBlock, regex, l:throws[2])
            let l:throwsName = matchlist(l:throws[0], regex)
            if l:throws[2] != -1
                call add(l:throwsList, " * @throws ".l:throwsName[3])
                continue
            endif
            break
        endwhile
    endfor

    " throws new \Exception("message");


    " Viml list of lines to append as the PHP documentaion block
    let l:phpDoc = ['/**',
                   \' *',
                   \' * '.l:nameAndParams[2],
                   \' *'] + l:paramsList + l:throwsList
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


" Returns a list of parameter lines ready to be inserted into a doc block
function! s:parseFunctionParameters(parameterString)

    " Remove everything from PHP strings in default parameter declarations (removes commas)
    let l:paramsString = substitute(a:parameterString, '\v([''"])[^''"]*([''"])', '\1\2', "g")

    " Remove everything from PHP arrays (removes commas)
    let l:paramsString = substitute(l:paramsString, '\v([\(\[])[^\]\)]*([\]\)])', '\1\2', "g")

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
