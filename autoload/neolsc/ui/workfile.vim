" vim: set foldmethod=marker foldlevel=0 nomodeline:

let s:_neolsc_working_buffers = {}

function! neolsc#ui#workfile#add(buf, server)
    let s:_neolsc_working_buffers[a:buf] = {
                \ '_buf': a:buf,
                \ '_tick': nvim_buf_get_changedtick(a:buf),
                \ '_version': 0,
                \ '_server': a:server,
                \ '_actions': [[], {}],
                \ '_diagnostics': [[], {}],
                \ '_doclinks': [[], {}],
                \ '_codelens': [[], {}],
                \ '_vtext': {'_diagnostics': {}, '_codelens': {}, '_doclinks': {}},
                \ '_lines': nvim_buf_get_lines(a:buf, 0, -1, v:true),
                \ }
endfunction

function! neolsc#ui#workfile#getAll() abort
    return values(s:_neolsc_working_buffers)
endfunction

function! neolsc#ui#workfile#get(buf) abort
    return get(s:_neolsc_working_buffers, a:buf)
endfunction

function! neolsc#ui#workfile#remove(buf)
    if has_key(s:_neolsc_working_buffers, a:buf)
        call remove(s:_neolsc_working_buffers, a:buf)
    endif
endfunction
