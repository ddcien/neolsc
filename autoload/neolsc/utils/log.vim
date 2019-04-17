" vim: set foldmethod=marker foldlevel=0 nomodeline:

function! neolsc#utils#log#verbose(...) abort
    if g:neolsc_log_verbose
        call call(function('neolsc#utils#log#log'), a:000)
    endif
endfunction

function! neolsc#utils#log#log(...) abort
    if !empty(g:neolsc_log_file)
        call writefile([json_encode({'time':strftime('%c') ,'log':a:000})], g:neolsc_log_file, 'a')
    endif
endfunction

