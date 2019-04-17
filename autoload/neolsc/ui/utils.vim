" vim: set foldmethod=marker foldlevel=0 nomodeline:

function! neolsc#ui#utils#position_compare(pos0, pos1) abort
    if a:pos0.line > a:pos1.line
        return 1
    elseif a:pos0.line < a:pos1.line
        return -1
    elseif a:pos0.character > a:pos1.character
        return 1
    elseif a:pos0.character < a:pos1.character
        return -1
    else
        return 0
    endif
endfunction
