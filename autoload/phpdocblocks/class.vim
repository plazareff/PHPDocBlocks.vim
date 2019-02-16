" Return a list of lines that make up the doc block
function! phpdocblocks#class#parse(code)
    " Match a valid function syntax, capture the name and parameters
    let l:classPartsRegex = '\vclass%(\s|\n)+(\w+)%(\s|\n)*%(extends){0,1}%(\s|\n)*(\w*)%(\s|\n)*\{'
    let l:classParts = matchlist(a:code, l:classPartsRegex)
    if l:classParts != []
        let l:name = l:classParts[1]
        if l:classParts[2] != ""
            let l:parentClass = l:classParts[2]
        else
            " Will not write the template line for an empty list
            let l:parentClass = []
        endif
    else
        return ["error","Invalid PHP class declaration on this line."]
    endif
    return {'name': l:name, 'parent-class': l:parentClass}
endfunction
