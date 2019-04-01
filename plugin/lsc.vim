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


augroup lsc_auto_enable
    autocmd!
    autocmd VimEnter * call lsc#enable()
augroup END


command! LscCodeAction call lsc#textDocument_codeAction()
command! LscDeclaration call lsc#textDocument_declaration()
command! LscDefinition call lsc#textDocument_definition()
command! LscDocumentSymbol call lsc#textDocument_documentSymbol()
command! LscReferences call lsc#textDocument_references()
command! LscRename call lsc#textDocument_rename()
command! LscTypeDefinition call lsc#textDocument_typeDefinition()
command! LscWorkspaceSymbol call lsc#workspace_symbol()
command! LscImplementation call lsc#textDocument_implementation()
command! LscFold call lsc#textDocument_foldingRange()
command! LscDocumentFormat call lsc#textDocument_formatting()
command! -range LscDocumentRangeFormat call lsc#textDocument_rangeFormatting()
command! LscHover call lsc#textDocument_hover()
command! LscDocumentLink call lsc#textDocument_documentLink()
command! LscCodelens call lsc#textDocument_codeLens()
command! LscHighlight call lsc#textDocument_documentHighlight()
command! LscNextDiag call lsc#Diagnostics_next()
command! LscPrevDiag call lsc#Diagnostics_prev()
command! LscDocumentDiag call lsc#textDocument_diagnostics()
command! LscWorkspaceDiag call lsc#workspace_diagnostics()
command! -nargs=0 LscStatus echomsg lsc#status()


nnoremap <plug>(lsc-code-action) :<c-u>call lsc#textDocument_codeAction()<cr>
nnoremap <plug>(lsc-declaration) :<c-u>call lsc#textDocument_declaration()<cr>
nnoremap <plug>(lsc-definition) :<c-u>call lsc#textDocument_definition()<cr>
nnoremap <plug>(lsc-document-symbol) :<c-u>call lsc#textDocument_documentSymbol()<cr>
nnoremap <plug>(lsc-references) :<c-u>call lsc#textDocument_references()<cr>
nnoremap <plug>(lsc-rename) :<c-u>call lsc#textDocument_rename()<cr>
nnoremap <plug>(lsc-type-definition) :<c-u>call lsc#textDocument_typeDefinition()<cr>
nnoremap <plug>(lsc-workspace-symbol) :<c-u>call lsc#workspace_symbol()<cr>
nnoremap <plug>(lsc-implementation) :<c-u>call lsc#textDocument_implementation()<cr>
nnoremap <plug>(lsc-fold) :<c-u>call lsc#textDocument_foldingRange()<cr>
nnoremap <plug>(lsc-document-format) :<c-u>call lsc#textDocument_formatting()<cr>
vnoremap <plug>(lsc-document-format) :call lsc#textDocument_rangeFormatting()<cr>
nnoremap <plug>(lsc-hover) :<c-u>call lsc#textDocument_hover()<cr>
nnoremap <plug>(lsc-document-link) :<c-u>call lsc#textDocument_documentLink()<cr>
nnoremap <plug>(lsc-codelens) :<c-u>call lsc#textDocument_codeLens()<cr>
nnoremap <plug>(lsc-highlight) :<c-u>call lsc#textDocument_documentHighlight()<cr>
nnoremap <plug>(lsc-next-diag) :<c-u>call lsc#Diagnostics_next()<cr>
nnoremap <plug>(lsc_prev-diag) :<c-u>call lsc#Diagnostics_prev()<cr>
nnoremap <plug>(lsc-document-diag) :<c-u>call lsc#textDocument_diagnostics()<cr>
nnoremap <plug>(lsc-workspace-diag) :<c-u>call lsc#workspace_diagnostics()<cr>
nnoremap <plug>(lsc-status) :<c-u>call lsc#status()<cr>


