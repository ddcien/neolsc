" vim: set foldmethod=marker foldlevel=0 nomodeline:

let s:file_handler = {}

function s:file_handler.alloc(buf)
    if type(a:buf) == v:t_number
        let l:buf = a:buf
        let l:uri = lsc#utils#get_buffer_uri(a:buf)
    else
        let l:buf = bufnr(lsc#uri#uri_to_path(a:buf))
        let l:uri = a:buf
    endif

    if empty(l:uri)
        return
    endif

    let l:fh = copy(s:file_handler)

    let l:fh._ver = 1
    let l:fh._buf = l:buf
    let l:fh._uri = l:uri
    if l:buf > 0
        let l:fh._tick = getbufvar(l:buf, 'changedtick')
    else
        let l:fh._tick = -1
    endif

    let l:fh._diagnostics = [[], {}]
    let l:fh._code_actions = []
    let l:fh._codelenses = []
    let l:fh._highlights = []
    let l:fh._documentlinks = []
    let l:fh._vtext = {}

    return l:fh
endfunction

function s:file_handler.set_virtual_text(ns_id, line, chunks)
    if a:line < 0
        let self._vtext[a:ns_id] = {}
        return nvim_buf_clear_namespace(self._buf, a:ns_id, 0, -1)
    endif

    if !has_key(self._vtext, a:ns_id)
        let self._vtext[a:ns_id] = {}
    endif

    let self._vtext[a:ns_id][a:line] = a:chunks

    if empty(a:chunks)
        call nvim_buf_clear_namespace(self._buf, a:ns_id, a:line, a:line)
    else
        let l:chunks = []
        for l:chk in values(self._vtext)
            call extend(l:chunks, get(l:chk, a:line, []))
        endfor
        call nvim_buf_set_virtual_text(self._buf, a:ns_id, a:line, l:chunks, {})
    endif
endfunction

function s:file_handler.add_highlight(ns_id, line, hl_group, col_start, col_end)
    call nvim_buf_add_highlight(self._buf, a:ns_id, a:hl_group, a:line, a:col_start, a:col_end)
endfunction

function lsc#file#new(buf)
    return s:file_handler.alloc(a:buf)
endfunction
