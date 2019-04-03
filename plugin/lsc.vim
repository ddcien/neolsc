" vim: set foldmethod=marker foldlevel=0 nomodeline:
"
if exists('g:lsc_loaded')
    finish
endif
let g:lsc_loaded = 1

let g:lsc_log_verbose = get(g:, 'lsc_log_verbose', 1)
let g:lsc_log_file = get(g:, 'lsc_log_file', '/tmp/lsc.log')
let g:lsc_auto_enable = get(g:, 'lsc_auto_enable', 0)
let g:lsc_sort_locations = get(g:, 'lsc_sort_locations', 1)

" hover settings {{{
" lsc_hover_extra_info: Bool
"   v:true: add extra info to hover infomation
"   v:false: show the orignal infomation
"   default: v:true
let g:lsc_hover_extra_info = get(g:, 'lsc_hover_extra_info', v:false)

" lsc_hover_floating_window: Bool
"   v:true: show hover infomation in floating window
"   v:false: show hover infomation in preview window
"   default: v:true
let g:lsc_hover_floating_window = get(g:, 'lsc_hover_floating_window', v:true)

" lsc_hover_preview_direction: String
"   The direction of the preview window, one of ['top', 'bottom', 'left',
"   'right'], only used when lsc_hover_floating_window is v:false
"   default: 'top'
let g:lsc_hover_preview_direction = get(g:, 'lsc_hover_preview_direction', 'top')

" lsc_hover_preview_size: Number
"   the initial size of the preview window, if lsc_hover_preview_direction is
"   'top' or 'bottom', it means the hight; otherwise, the width of the preview
"   window. only used when lsc_hover_floating_window is v:false
"   default: 12
let g:lsc_hover_preview_size = get(g:, 'lsc_hover_preview_size', 12)
" }}}

" lsc_diag_strategy:
"     0: disable, never show diags
"     1: manual,
"     2: lazy,
"
let g:lsc_diag_strategy = get(g:, 'lsc_diag_strategy', 1)


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

command! LscWorkspaceSymbol call lsc#workspace_symbol()
command! LscWorkspaceDiag call lsc#workspace_diagnostics()

command! LscCodeAction call lsc#textDocument_codeAction()
command! -range LscRangeCodeAction call lsc#textDocument_rangeCodeAction()
command! LscDeclaration call lsc#textDocument_declaration()
command! LscDefinition call lsc#textDocument_definition()
command! LscSymbol call lsc#textDocument_documentSymbol()
command! LscReferences call lsc#textDocument_references()
command! LscRename call lsc#textDocument_rename()
command! LscTypeDefinition call lsc#textDocument_typeDefinition()
command! LscImplementation call lsc#textDocument_implementation()
command! LscFold call lsc#textDocument_foldingRange()
command! LscFormat call lsc#textDocument_formatting()
command! -range LscRangeFormat call lsc#textDocument_rangeFormatting()
command! LscHover call lsc#textDocument_hover()
command! LscLink call lsc#textDocument_documentLink()
command! LscCodelens call lsc#textDocument_codeLens()
command! LscHighlight call lsc#textDocument_documentHighlight()
command! LscNextDiag call lsc#Diagnostics_next()
command! LscPrevDiag call lsc#Diagnostics_prev()
command! LscDiag call lsc#textDocument_diagnostics()
command! -nargs=0 LscStatus echomsg lsc#status()

command! LscCaller call lsc#ccls_caller()
command! LscCallee call lsc#ccls_callee()
command! LscFileInfo call lsc#ccls_fileInfo()
command! LscInfo call lsc#ccls_info()
command! LscInheritanceBase call lsc#ccls_inheritance_base()
command! LscInheritanceDerived call lsc#ccls_inheritance_derived()
command! LscMemberFile call lsc#ccls_member_file()
command! LscMemberType call lsc#ccls_member_type()
command! LscMemberFunction call lsc#ccls_member_function()
command! LscMemberVariable call lsc#ccls_member_variable()
command! LscMavigateDown call lsc#ccls_navigate_down()
command! LscNavigateUp call lsc#ccls_navigate_up()
command! LscNavigateLeft call lsc#ccls_navigate_left()
command! LscNavigateRight call lsc#ccls_navigate_right()
command! LscReload call lsc#ccls_reload()
command! LscVars call lsc#ccls_vars()


nnoremap <plug>(lsc-workspace-symbol) :<c-u>call lsc#workspace_symbol()<cr>
nnoremap <plug>(lsc-workspace-diag) :<c-u>call lsc#workspace_diagnostics()<cr>

nnoremap <plug>(lsc-code-action) :<c-u>call lsc#textDocument_codeAction()<cr>
vnoremap <plug>(lsc-code-action) :call lsc#textDocument_rangeCodeAction()<cr>
nnoremap <plug>(lsc-declaration) :<c-u>call lsc#textDocument_declaration()<cr>
nnoremap <plug>(lsc-definition) :<c-u>call lsc#textDocument_definition()<cr>
nnoremap <plug>(lsc-symbol) :<c-u>call lsc#textDocument_documentSymbol()<cr>
nnoremap <plug>(lsc-references) :<c-u>call lsc#textDocument_references()<cr>
nnoremap <plug>(lsc-rename) :<c-u>call lsc#textDocument_rename()<cr>
nnoremap <plug>(lsc-type-definition) :<c-u>call lsc#textDocument_typeDefinition()<cr>
nnoremap <plug>(lsc-implementation) :<c-u>call lsc#textDocument_implementation()<cr>
nnoremap <plug>(lsc-fold) :<c-u>call lsc#textDocument_foldingRange()<cr>
nnoremap <plug>(lsc-format) :<c-u>call lsc#textDocument_formatting()<cr>
vnoremap <plug>(lsc-format) :call lsc#textDocument_rangeFormatting()<cr>
nnoremap <plug>(lsc-hover) :<c-u>call lsc#textDocument_hover()<cr>
nnoremap <plug>(lsc-link) :<c-u>call lsc#textDocument_documentLink()<cr>
nnoremap <plug>(lsc-codelens) :<c-u>call lsc#textDocument_codeLens()<cr>
nnoremap <plug>(lsc-highlight) :<c-u>call lsc#textDocument_documentHighlight()<cr>
nnoremap <plug>(lsc-next-diag) :<c-u>call lsc#Diagnostics_next()<cr>
nnoremap <plug>(lsc-prev-diag) :<c-u>call lsc#Diagnostics_prev()<cr>
nnoremap <plug>(lsc-diag) :<c-u>call lsc#textDocument_diagnostics()<cr>
nnoremap <plug>(lsc-status) :<c-u>call lsc#status()<cr>

nnoremap <plug>(lsc-caller) :<c-u>call lsc#ccls_caller()<cr>
nnoremap <plug>(lsc-callee) :<c-u>call lsc#ccls_callee()<cr>
nnoremap <plug>(lsc-file-nfo) :<c-u>call lsc#ccls_fileInfo()<cr>
nnoremap <plug>(lsc-info) :<c-u>call lsc#ccls_info()<cr>
nnoremap <plug>(lsc-inheritance-base) :<c-u>call lsc#ccls_inheritance_base()<cr>
nnoremap <plug>(lsc-inheritance-derived) :<c-u>call lsc#ccls_inheritance_derived()<cr>
nnoremap <plug>(lsc-member-file) :<c-u>call lsc#ccls_member_file()<cr>
nnoremap <plug>(lsc-member-type) :<c-u>call lsc#ccls_member_type()<cr>
nnoremap <plug>(lsc-member-function) :<c-u>call lsc#ccls_member_function()<cr>
nnoremap <plug>(lsc-member-variable) :<c-u>call lsc#ccls_member_variable()<cr>
nnoremap <plug>(lsc-navigate-down) :<c-u>call lsc#ccls_navigate_down()<cr>
nnoremap <plug>(lsc-navigate-up) :<c-u>call lsc#ccls_navigate_up()<cr>
nnoremap <plug>(lsc-navigate-left) :<c-u>call lsc#ccls_navigate_left()<cr>
nnoremap <plug>(lsc-navigate-right) :<c-u>call lsc#ccls_navigate_right()<cr>
nnoremap <plug>(lsc-reload) :<c-u>call lsc#ccls_reload()<cr>
nnoremap <plug>(lsc-vars) :<c-u>call lsc#ccls_vars()<cr>

inoremap <silent> <expr> <Plug>(lsc-complete) lsc#textDocument_completion()


let s:key = '<TAB>'
exe 'inoremap <expr>' . s:key . ' pumvisible() ? "\<C-n>" : "\' . s:key .'"'

inoremap <c-space> <Plug>(lsc-complete)
