" vim: set foldmethod=marker foldlevel=0 nomodeline:

function! neolsc#ui#codeaction#update(server, actions, buf) abort
    let l:buf_ctx = neolsc#ui#workfile#get(a:buf)
    if empty(l:buf_ctx)
        return
    endif

    let l:buf_ctx['_actions'][0] = a:actions
    let l:buf_ctx['_actions'][1] = {}

    for l:action in a:actions
        let l:diagnostics = get(l:action, 'diagnostics')
        if empty(l:diagnostics)
            continue
        endif
        call sort(l:diagnostics, {d0, d1 -> neolsc#ui#utils#position_compare(d0['range']['start'], d1['range']['start'])})
        for l:diag in l:diagnostics
            let l:line = l:diag['range']['start']['line']
            let l:buf_ctx['_actions'][1][l:line] = add(get(l:buf_ctx['_actions'][1], l:line, []), l:action)
        endfor
    endfor
endfunction

function! s:_codeAction_apply(server, action) abort
    if has_key(a:action, 'command') && type(a:action['command']) == v:t_string
        call neolsc#ui#workspace#executeCommand(a:server, a:action)
        return
    endif
    if has_key(a:action, 'edit')
        let l:buf = nvim_get_current_buf()
        call neolsc#ui#edit#WorkspaceEdit(l:buf, a:action['edit'])
    endif
    if has_key(a:action, 'command')
        call neolsc#ui#workspace#executeCommand(a:server, a:action['command'])
    endif
endfunction

function! neolsc#ui#codeaction#apply(server, actions, fixit_if_one)
    if empty(a:actions)
        return
    endif

    if len(a:actions) == 1 && a:fixit_if_one
        call s:_codeAction_apply(a:server, a:actions[0])
        return
    endif

    let l:actlist = []
    let l:idx = 1

    for l:action in a:actions
        call add(l:actlist, printf('%d. %s', l:idx, l:action['title']))
        let l:idx += 1
    endfor

    let l:idx = inputlist(l:actlist)
    if l:idx < 1 || l:idx > len(l:actlist)
        return
    endif

    call s:_codeAction_apply(a:server, a:actions[l:idx - 1])
endfunction


