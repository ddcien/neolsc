if exists('g:lsc_loaded')
    finish
endif
let g:lsc_loaded = 1

let g:lsc_log_verbose = get(g:, 'lsc_log_verbose', 1)
let g:lsc_log_file = get(g:, 'lsc_log_file', '/tmp/lsc.log')
let g:lsc_auto_enable = get(g:, 'lsc_auto_enable', 0)

let g:lsc_server_commands = {
            \ 'cpp': {
            \     'command': ['cquery', '--record', '/tmp/aaa', '--log-file=/tmp/cq_cpp.log'],
            \     'initialization_options': {'cacheDirectory': '/tmp/cquery_cache_cpp'}
            \ },
            \ 'c': {
            \     'command': ['cquery', '--record', '/tmp/bbb', '--log-file=/tmp/cq_c.log'],
            \     'initialization_options': {'cacheDirectory': '/tmp/cquery_cache_c'}
            \ },
            \ 'python': {
            \     'command': ['pyls'],
            \     'initialization_options': {}
            \ },
            \ }

" if g:lsc_auto_enable
    " augroup LSC
        " autocmd!
        " autocmd VimEnter * call lsc#enable()
    " augroup END
" endif

