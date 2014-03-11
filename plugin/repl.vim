" Vim plugin for handling a REPL interpreter in a scratch buffer
"
" Maintainer:	Thomas Baruchel <baruchel@gmx.com>
" Last Change:	2014 Mar 11
" Version:      1.0

" Copyright (c) 2014 Thomas Baruchel
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
"
let g:repl_cmd = '/home/thomas/Téléchargements/GNUAPL/trunk/src/apl --noSV --rawCIN --noColor'
let g:repl_stop = ')OFF'
let g:repl_send = "'REPL-VIM'"
let g:repl_detect = 'REPL-VIM'

map µ :call ReplCmd()<CR>

" Do not edit below

if exists('loaded_repl') || &cp
    finish
endif
let loaded_repl=1

function! ReplCloseInternal(n)
  let l:bn = bufnr('%')
  " got to the edit buffer
  exe 'buffer! '. a:n
  exe 'autocmd! * <buffer=' . b:repl_bufnr . '>'
  exe 'autocmd! * <buffer=' . a:n . '>'
  " close the process
  let l:tmp = system('echo "' . b:repl_stop . '" >> ' . b:repl_fifo_in)
  " an empty line should close the 'tail -f' process
  let l:tmp = system('echo "" >> ' . b:repl_fifo_in)
  " remove some variables
  let l:tmp = b:repl_bufnr
  unlet! b:repl_bufnr
  unlet! b:repl_stop
  unlet! b:repl_send

  " I have to think if it is really useful to delete the two FIFOs
  " (because a race condition could occur if they are removed
  " before the 'stop' command has actually been read, and it may be
  " important with interpreters that don't accept Ctrl-D like GNU APL
  " When Vim leaves, the directory is deleted anyway.

  "let l:tmp = system('rm -f ' . b:repl_fifo_in)
  unlet! b:repl_fifo_in
  "let l:tmp = system('rm -f ' . b:repl_fifo_out)
  unlet! b:repl_fifo_out

  " remove variables from the REPL buffer
  exe 'buffer! '. l:tmp
  unlet! b:repl_fifo_out
  unlet! b:repl_mainbuffer
  " come back to the currentbuffer
  exe 'buffer! '. l:bn
endfunction

function! ReplClose()
  if exists('b:repl_mainbuffer')
    exe 'call ReplCloseInternal(' . b:repl_mainbuffer . ')'
    return
  endif
  if !exists('b:repl_bufnr')
    echo 'No REPL is running in associated to this buffer'
    return
  endif
  exe 'call ReplCloseInternal(' . bufnr('%') . ')'
endfunction

function! ReplCmd()
  exe '.write! >> ' . b:repl_fifo_in
  let l:tmp = system('echo "' . b:repl_send . '" >> ' . b:repl_fifo_in)
  let l:bn = bufnr('%')           " current buffer number
  let l:tmp = bufwinnr(bufname(b:repl_bufnr))
  exe 'buffer! '. b:repl_bufnr
  exe 'silent normal! G'
  exe 'read! cat ' . b:repl_fifo_out
  if l:tmp > 0
    let l:tmp2 = winnr()
    exe l:tmp . "wincmd w"
    exe 'silent normal! G'
    exe l:tmp2 . "wincmd w"
  endif
  redraw!
  exe 'buffer! '. l:bn
endfunction

function! ReplNew()

  if exists('b:repl_bufnr')
    echo 'REPL buffer already existing'
    return
  endif

  let l:bn = bufnr('%')           " current buffer number
  let l:bs = expand('%:t')        " current buffer name
  let l:n = '[REPL:' . l:bs . ']' " name of the new buffer
  if strlen(l:bs) == 0
    let l:n = '[REPL]'
  endif

  " create two fifo special files
  let b:repl_fifo_in = tempname()
  let l:tmp = system('mkfifo ' . b:repl_fifo_in)
  let b:repl_fifo_out = tempname()
  let l:out = b:repl_fifo_out
  let l:tmp = system('mkfifo ' . b:repl_fifo_out)

  " copy the global variables to buffer variables
  " in order to allow the global variables to be changed
  let b:repl_stop = g:repl_stop
  let b:repl_send = g:repl_send

" tail -f test | while read -r line; do ( while [ $line != "VIM" ]; do echo $line; read -r line;   done             )  ; done

  let l:tmp = 'tail -f ' . b:repl_fifo_in
  let l:tmp = l:tmp . ' | ' . g:repl_cmd
  "let l:tmp = l:tmp . ' | { echo "$$" > ' . b:repl_fifo_out .'; while read -r line;'
  let l:tmp = l:tmp . ' | { while read -r line;'
  let l:tmp = l:tmp . ' do { while [ "$line" != "' . g:repl_detect .'" ];'
  let l:tmp = l:tmp . ' do echo $line; read -r line; done; } > ' . b:repl_fifo_out .';'
  let l:tmp = l:tmp . ' done; } &'
  let l:tmp = system(l:tmp)
  " send an initial command to be detected
  let l:tmp = system('echo "' . b:repl_send . '" >> ' . b:repl_fifo_in)

  " create the new buffer
  exe 'new ' . l:n
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal buflisted
  let l:nn = bufnr('%')           " buffer number of the REPL
  let b:repl_mainbuffer = l:bn
  let b:repl_fifo_out = l:out

  exe 'read! cat ' . l:out
  exe 'silent normal! G'
  redraw

  " autocmd for removing the local variable in the initial buffer
  " when the scratch is closed
  exe 'autocmd BufDelete <buffer> call ReplCloseInternal(' . l:bn . ')'
  exe 'autocmd BufDelete <buffer> autocmd! * <buffer=' . l:nn . '>'

  " switch back to the current buffer and define a local variable for
  " accessing the REPL buffer
  wincmd j
  let b:repl_bufnr = l:nn
  exe 'autocmd BufDelete <buffer> call ReplCloseInternal(' . l:bn . ')'

endfunction
