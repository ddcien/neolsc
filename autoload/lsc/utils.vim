
function! lsc#utils#get_buffer_path(...) abort
    return expand((a:0 > 0 ? '#' . a:1 : '%') . ':p')
endfunction

function! lsc#utils#get_filetype(...) abort
    if a:0 == 0
        let l:buffer_filetype = &filetype
    else
        if type(a:1) == v:t_string
            let l:buffer_filetype = a:1
        else
            let l:buffer_filetype = getbufvar(a:1, '&filetype')
        endif
    endif
    return l:buffer_filetype
endfunction


function! lsc#utils#get_buffer_uri(...) abort
    return lsc#uri#path_to_uri(expand((a:0 > 0 ? '#' . a:1 : '%') . ':p'))
endfunction
