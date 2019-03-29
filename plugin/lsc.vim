if exists('g:lsc_loaded')
    finish
endif
let g:lsc_loaded = 1

let g:lsc_log_verbose = get(g:, 'lsc_log_verbose', 1)
let g:lsc_log_file = get(g:, 'lsc_log_file', '/tmp/lsc.log')
let g:lsc_auto_enable = get(g:, 'lsc_auto_enable', 0)
let g:lsc_sort_locations = get(g:, 'lsc_sort_locations', 1)

" auto_codeLens:
"     0: disable
"     1: on_save
"     2: on_change
"
" auto_documentlink:
"     0: disable
"     1: on_save
"     2: on_change
"
" auto_documentlink:
"     0: disable
"     1: on_CursorHold
"

let g:lsc_server_commands = [
            \ {
            \     'name': 'ccls',
            \     'command': ['ccls', '--log-file=/tmp/cq_cpp.log'],
            \     'initialization_options': {
            \         'cache': {
            \             'directory':'.ccls-cache',
            \         },
            \         'highlight': {
            \             'lsRanges': v:true,
            \         },
            \     },
            \     'workspace_settings': {},
            \     'settings': {
            \         'auto_codeLens': 2,
            \         'auto_documentlink': 2,
            \         'auto_documenthighlight': 0
            \     },
            \     'whitelist': ['c', 'cpp', 'objc', 'objcpp', 'cc'],
            \ },
            \ {
            \     'name': 'pyls',
            \     'command': ['pyls'],
            \     'initialization_options': {},
            \     'workspace_settings': {},
            \     'whitelist': ['python']
            \ },
            \ {
            \     'name': 'rls',
            \     'command': ['rls'],
            \     'initialization_options': {},
            \     'workspace_settings': {},
            \     'whitelist': ['rust']
            \ },
            \ ]
