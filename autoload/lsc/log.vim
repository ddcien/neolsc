
function! lsc#log#verbose(...) abort
    if g:lsc_log_verbose
        call call(function('lsc#log#log'), a:000)
    endif
endfunction

function! lsc#log#log(...) abort
    if !empty(g:lsc_log_file)
        call writefile([strftime('%c') . ':' . json_encode(a:000)], g:lsc_log_file, 'a')
    endif
endfunction
