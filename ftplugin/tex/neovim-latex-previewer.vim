" tex-live-preview plugin for NeoVim and Vim 8
" Last Change: 3 Jan 2018
" Maintainer: Tamvana Makuluni
" License: This file is placed in the public domain.

if !exists('s:initialized')
    " Create the temporary directory for compilation.
    let s:tmp = tempname()
    call mkdir( s:tmp, 'p' )
    let s:initialized = 1
    " Initialize script-wide variables.
    let s:roots = {}
    let s:shared = {}
    let s:tex_allowed_executables = { 'tex': 1,
                                    \ 'latex': 1,
                                    \ 'luatex': 1,
                                    \ 'xetex': 1,
                                    \ }
    call extend( s:tex_allowed_executables,
               \ get( g:, 'latex_magic_comment_allowed_programs', {} ) )
    let s:tex_options = {
                        \ 'enc': [ 'ini', '-ini -enc' ],
                        \ 'flerror': [ 'fle', '-file-line-error' ],
                        \ '!flerror': [ 'fle', '-no-file-line-error' ],
                        \ 'ini': [ 'ini', '-ini' ],
                        \ 'batch': [ 'int', '-interaction batchmode' ],
                        \ 'nonstop': [ 'int', '-interaction nonstopmode' ],
                        \ 'scroll': [ 'int', '-interaction scrollmode' ],
                        \ 'errorstop': [ 'int', '-interaction errorstopmode' ],
                        \ 'shellescape': [ 'se', '-shell-escape' ],
                        \ '!shellescape': [ 'se', '-no-shell-escape' ],
                        \ 'srcspecials': [ 'spec', '-src-specials' ],
                        \ '!srcspecials': [ 'spec', '-no-src-specials' ],
                        \ 'synctex': [ 'sync', '-synctex=1' ],
                        \ '!synctex': [ 'sync', '-synctex=0' ],
                        \ }
    call extend( s:tex_options,
               \ get( g:, 'latex_allowed_executables', {} ) )

    "" Define the augroup
    augroup _latex_previewer_
        au!
    augroup END

    "" Function definitions
    " Expand a path relative to some base directory
    " I can't entirely believe this doesn't exist already, but I didn't find
    " it in the documentation.
    function s:path_expand( base, path, expansion )
        let l:cwd = getcwd()
        exe 'cd ' . a:base
        let l:ret = fnamemodify( a:path, a:expansion )
        exe 'cd ' . l:cwd
        return l:ret
    endfunction

    " Some shortcuts
    function s:tmpdir(file,...)
        return s:tmp . "/" . s:shared[s:root(a:file)]['id'] . "/"
    endfunction
    function s:mkdir(name,...)
        if !isdirectory( a:name )
            call mkdir( a:name, 'p' )
        endif
    endfunction
    function s:dict(file,...)
        if ( a:0 == 0 )
            return get( s:shared, s:root(a:file), {} )
        elsei ( a:0 == 1 )
            return get( get( s:shared, s:root(a:file), {} ), a:1, 0 )
        elsei ( a:0 == 2 )
            let s:shared[s:root(a:file)][a:1] = a:2
        endif
    endfunction
    function s:relpath(file,...)
        return s:dict(a:file,'rel')[a:file]
    endfunction
    function s:root(file,...)
        return get( s:roots, a:file, -1 )
    endfunction
    function s:clear_pjob(file,...)
        call s:dict(a:file, 'pjob', -1 )
    endfunction
    function s:options(file,...)
        return join(values(s:dict(a:file,'options')), " ")
    endfunction
    function s:initstring(file,...)
        return join(values(s:dict(a:file,'init')), " ")
    endfunction

    " Commands for manipulating the log.
    function s:clear_log(file,...)
        call s:dict(a:file, 'log', [] )
    endfunction
    function s:log(file,lines)
        call s:dict(a:file, 'log', s:dict(a:file, 'log' ) + a:lines )
    endfunction
    function s:log_callback(file,job,data,...)
        call s:log(a:file, a:data )
    endfunction
    function s:show_log(file,...)
        call writefile(s:dict(a:file,'log'),s:tmpdir(a:file) . 'log')
        exe 'pedit ' . s:tmpdir(a:file) . 'log'
    endfunction

    " These wrappers are here to make logging automatic.
    function s:system(file,command,...)
        call s:log(a:file, [ '> ' . a:command ] )
        let l:ret = systemlist( a:command )
        call s:log(a:file, l:ret )
        return l:ret
    endfunction
    function s:jobstart(file,command,...)
        let l:options = { 'on_stdout': function('s:log_callback',[a:file]),
                        \ 'on_stderr': function('s:log_callback',[a:file]) }
        let l:command = a:command
        let l:i = 1
        while l:i <= a:0
            let l:a = get(a:,l:i,{})
            if type(l:a) == v:t_dict
                call extend(l:options,l:a)
            elsei type(l:a) == v:t_string
                call extend( l:options,{ 'cwd': l:a } )
            endif
            let l:i += 1
        endwhile
        call s:log(a:file, [ '> ' . a:command ] )
        let l:job = jobstart( l:command, l:options )
        call jobclose( l:job, 'stdin' )
        return l:job
    endfunction

    " Determine the full path to the root document for this project.
    " This needs to be rerun when the % !TeX root= is changed, which can
    " be done with a :vi
    function s:get_root(file,...)
        " Look for a magic comment.
        let l:root = search( '^%\s*!TeX\s\+root\s*=\s*.', 'n' )
        if l:root > 0
            " If the magic comment is found, this will give our root file
            " name.
            let l:root = matchlist( getline(l:root),
                               \ '^%\s*!TeX\s\+root\s*=\s*\(.\{-1,}\)\s*$' )[1]
            let l:root = s:path_expand( expand('%:p:h'), l:root, ':p' )
        else
            " Otherwise, assume this is the root file.
            let l:root = expand( '%:p' )
        endif
        " Set up s:roots to point this file to its corresponding root path
        let s:roots[expand('%:p')] = l:root
        " Set up s:shared with information about the file. This is local to
        "   the script so that it isn't exposed to the user and it is shared
        "   among multiple buffers.
        let s:shared[l:root] = get( s:shared,
                            \ l:root,
                            \ { 'dir': fnamemodify( l:root, ':h:S' ),
                              \ 'file': fnamemodify( l:root, ':t:S' ),
                              \ 'out': fnamemodify( l:root, ':t:r:S' ) . '.pdf',
                              \ 'id': len(s:shared) } )
        call extend( s:dict(a:file),
                   \ { 'rel': {},
                     \ 'mode': get( g:, 'latex_previewer_mode', 0 ),
                     \ 'sync': get( g:, 'latex_previewer_sync', 1 ),
                     \ 'timer': get( g:, 'latex_previewer_timer', -1 ),
                     \ 'viewer': get( g:, 'latex_previewer_app', 'mupdf' ),
                     \ 'enabled': get( g:, 'latex_previewer_enabled', 0 ),
                     \ 'write': get( g:, 'latex_previewer_write', 'pdf' ),
                     \ 'cache': get( g:, 'latex_previewer_cache', 0 ),
                     \ 'program': get( g:, 'latex_command', 'latex' ),
                     \ 'compilepath': '-pdfps',
                     \ 'options': {},
                     \ 'timerid': -1,
                     \ 'init': {},
                     \ 'pjob': -1,
                     \ 'job': -1,
                     \ 'log': [],
                     \ 'rerun': 0 },
                   \ 'keep' )
        " Look for a magic comment setting the program. For now, only tex,
        " latex, xetex, and luatex are accepted as executable names anything
        " else will be given as a -progname argument to the default executable.
        let l:program = search(
                      \ '^%\s*!TeX\s\+program\s*=\s*[a-zA-Z]\+\s*$', 'n' )
        if l:program > 0
            let l:program = matchlist( getline(l:program),
                             \ '^%\s*!TeX\s\+program\s*=\s*\(.\{-1,}\)\s*$' )[1]
            if get( s:tex_allowed_executables, l:program, 0)
                call s:dict(a:file, 'program', l:program )
            else
                call extend( s:dict(a:file)['options'],
                    \ { 'prog': '-progname ' . l:program . ' ' } )
            endif
        endif
        " Look for a magic comment setting tex options.
        let l:options = split(
                    \ get( g:, 'latex_default_options', 'synctex, flerror, nonstopmode' ),
                    \ '\s*,\s*' )
        let l:opts = search( '^%\s*!TeX\s\+options\s*=\s*.', 'n' )
        if l:opts > 0
            call extend( l:options, split( matchlist( getline(l:opts),
              \ '^%\s*!TeX\s\+options\s*=\s*\(.\{-1,}\)\s*$' )[1], '\s*,\s*' ) )
        else
        endif
        for l:opt in l:options
            if get( s:tex_options, l:opt, '' ) isnot ''
                call extend( s:dict(a:file)['options'], { s:tex_options[l:opt][0]:
                            \ s:tex_options[l:opt][1] } )
            endif
        endfor
        " Cache this value to avoid using s:path_expand (and thus cd)later
        call extend( s:dict(a:file)['rel'],
                   \ { expand('%:p'): s:path_expand(
                                                   \ fnamemodify(s:root(a:file),':h'),
                                                   \ expand('%:p'),
                                                   \ ':.' ) } )
    endfunction

    " This is the main compilation function.
    function s:run(file,...)
        if s:dict(a:file,'job') isnot -1
            call s:dict(a:file, 'rerun', 1 )
        else
            echo "Compiling..."
            call s:dict(a:file, 'job', 0 )
            call s:clear_log(a:file)
            " Write out the contents of the buffer.
            let l:buf_file = s:tmpdir(a:file) . 'buf/' . s:relpath(a:file)
            call s:mkdir( fnamemodify( l:buf_file, ':h' ) )
            call writefile( getline( 1, '$' ),
                          \ s:tmpdir(a:file) . 'buf/' . s:relpath(a:file) )
            if s:dict(a:file,'cache')
                let l:compile_dir = s:dict(a:file,'dir') . '/.nlp/'
                call s:mkdir( fnamemodify( s:root(a:file), ':h' ) . '/.nlp/' )
            else
                let l:compile_dir = s:tmpdir(a:file) . 'compile/'
            endif
            call s:system(a:file, 'unionfs -o cow ' .
                      \ l:compile_dir . '=RW:' .
                      \ s:tmpdir(a:file) . 'buf=RO:' .
                      \ s:dict(a:file,'dir') . '=RO ' .
                      \ s:tmpdir(a:file) . 'mount' )
            if s:dict(a:file,'mode') > 0
                " Mount the buffer copy over the other copy.
                if s:dict(a:file,'mode') == 1
                    call s:system(a:file, 'latexdiff --flatten ' .
                       \ fnamemodify( s:root(a:file), ':S' ) . ' ' .
                       \ s:tmpdir(a:file) . 'mount/' . s:dict(a:file,'file') .
                       \ ' >' . s:tmpdir(a:file) . 'diff/' . s:dict(a:file,'file') )
                else
                    call s:system(a:file, 'cd ' . s:tmpdir(a:file) . 'mount && ' .
                             \ 'latexdiff-vc --force --git -r master -d ' .
                             \ s:tmpdir(a:file) . 'diff/ ' .
                             \ s:dict(a:file,'file') . ' ' . s:relpath(a:file) )
                endif
                call s:system(a:file, 'fusermount -u ' .
                          \ s:tmpdir(a:file) . 'mount' )
                call s:system(a:file, 'unionfs -o cow ' .
                          \ l:compile_dir . '=RW:' .
                          \ s:tmpdir(a:file) . 'diff=RO:' .
                          \ s:dict(a:file,'dir') . '=RO ' .
                          \ s:tmpdir(a:file) . 'mount' )
            endif
            call s:dict(a:file, 'job',
                    \ s:jobstart(a:file, 'latexmk ' .
                           \ s:dict(a:file,'compilepath') .
                           \ ' -f ' .
                           \ '-e ' .
                             \ '"' . s:initstring(a:file) . '" ' . 
                           \ '-latex=' .
                             \ s:dict(a:file,'program') . ' ' .
                           \ '-latexoption=' .
                             \ '"' . s:options(a:file) . '" ' .
                           \ s:dict(a:file,'file'),
                           \ s:tmpdir(a:file) . 'mount',
                           \ { 'on_exit': function('s:postcompile',[a:file]) } ) )
        endif
    endfunction

    function s:run_if_enabled(file,...)
        if s:dict(a:file,'enabled')
            call s:run(a:file)
        endif
    endfunction

    function s:run_timer(file,...)
        call timer_stop( s:dict(a:file,'timerid') )
        call s:dict(a:file,'timerid', -1)
        s:run(a:file)
    endfunction

    " Cleanup function after a compile operation
    function s:postcompile(file,...)
        let l:sync_pos = s:get_sync_pos(a:file)
        call s:system(a:file, 'fusermount -u ' .
                  \ s:tmpdir(a:file) . 'mount' )
        call s:dict(a:file, 'job', -1 )
        echo ""
        if s:dict(a:file,'cache')
            let l:compile_dir = s:dict(a:file,'dir') . '/.nlp/'
        else
            let l:compile_dir = s:tmpdir(a:file) . 'compile/'
        endif
        let l:outfile = l:compile_dir . s:dict(a:file,'out')
        if s:dict(a:file,'pjob') is -1 
            " Start the viewer if 'pjob' is unset.
            call s:dict(a:file, 'pjob', s:jobstart(a:file, s:dict(a:file,'viewer') . ' ' . l:outfile,
                                 \ { 'on_exit': function('s:clear_pjob',[a:file]) } ) )
        elsei s:dict(a:file,'viewer') == 'mupdf'
            " Send a SIGHUP for a reload if we're using mupdf
            call s:system(a:file, 'kill -s SIGHUP ' . jobpid( s:dict(a:file,'pjob') ) )
        endif
        try
            if and( s:dict(a:file,'mode') == 0, s:dict(a:file,'sync') )
                if s:dict(a:file,'viewer') == 'mupdf'
                    call s:system(a:file, 'xdotool search --name ' . s:dict(a:file,'out') .
                                        \ ' type --window %1 ' .
                                           \ l:sync_pos["Page"] . 'g' )
                endif
            endif
        catch
        endtry
        " Copy files to the root directory.
        let l:write = s:dict(a:file,'write')
        if l:write isnot 0
            if l:write == '!tex'
                let l:write = " -name '*.*' -and -not -name '*.tex'"
            elsei match( l:write, '^[a-zA-Z0-9]\+\(|[a-zA-Z0-9]\+\)*$' )+1
                let l:exts = ''
                for l:ext in split(l:write,'|')
                    let l:exts .= " -o -name '*." . l:ext . "'"
                endfor
                let l:exts = l:exts[3:]
                let l:write = l:exts
            else
                let l:write = " -name '*.pdf'"
            endif
            call s:system(a:file, 'cd ' . l:compile_dir . ' && ' .
                         \ 'cp --parents `find .' . l:write . '` '
                            \ . s:dict(a:file,'dir') )
        endif
        " Call the next compile.
        if s:dict(a:file,'timer') > -1
            call s:dict(a:file, 'rerun', 0 )
            if s:dict(a:file, 'timerid' ) is -1
                call s:dict(a:file,
                            \ 'timerid',
                            \ timer_start( s:dict(a:file,'timer'),
                                \ function('s:run_timer',[a:file])
                            \ ) )
            endif
        elsei s:dict(a:file,'rerun')
            call s:dict(a:file, 'rerun', 0 )
            " We introduce a small break between runs when possible.
            call timer_start( 500, function('s:run_if_enabled',[a:file]) )
        endif
    endfunction

    " Final cleanup on quit
    function s:quitting()
    endfunction

    "" Synctex subroutines.
    function s:get_sync_pos(file,...)
        let l:list = s:system(a:file, 'synctex view -i ' .
                    \ line('.') . ':' . col('.') . ':' .
                    \ s:tmpdir(a:file) . 'mount/' . s:relpath(a:file) . ' -o ' .
                    \ s:tmpdir(a:file) . 'mount/' .
                    \ s:dict(a:file,'out') )
        let l:return = {}
        for l:item in l:list
            let l:match = matchlist( l:item, '\([^:]\+\):\(.\+\)' )
            if len(l:match)
                let l:return[l:match[1]]=l:match[2]
            endif
        endfor
        return l:return
    endfunction

    "" Functions which change settings.
    " Change compilation modes
    function s:set_mode_by_name(file,...)
        if a:0
            if tolower(a:1) == 'diff'
                call s:dict(a:file, 'mode', 1 )
            elsei tolower(a:1) == 'git'
                call s:dict(a:file, 'mode', 2 )
            else
                call s:dict(a:file, 'mode', 0 )
            endif
            call s:run_if_enabled(a:file)
        else
            if s:dict(a:file,'mode') == 1
                echo 'git'
            elsei s:dict(a:file,'mode') == 2
                echo 'diff'
            else
                echo 'plain'
            endif
        endif
    endfunction

    " Change preview app
    function s:set_preview_app(file,...)
        if a:0
            call s:dict(a:file, 'viewer', a:1 )
        else
            echo s:dict(a:file,'viewer')
        endif
    endfunction

    " Enable or disable the previewer
    function s:set_enabled(file,...)
        if a:0
            call s:dict(a:file, 'enabled', !!a:1 )
            call s:run_if_enabled(a:file)
        else
            echo s:dict(a:file,'enabled')?'LatexPreviewerOn':'LatexPreviewerOff'
        endif
    endfunction

    " Enable or disable forward sync with synctex
    function s:set_sync(file,...)
        if a:0
            call s:dict(a:file, 'sync', !!a:1 )
        else
            echo s:dict(a:file,'sync')?'LatexPreviewerSyncOn':'LatexPreviewerSyncOff'
        endif
    endfunction

    " Set the preview timer
    function s:set_timer(file,...)
        if a:0
            if a:1 > 0
                call s:dict(a:file, 'timer', 1000 * a:1 )
                call s:run_timer(a:file)
            else
                call s:dict(a:file, 'timer', -1 )
            endif
        else
            if s:dict(a:file,'timer') > 0
                echo s:dict(a:file,'timer') / 1000
            else
                echo -1
            endif
        endif
    endfunction

    " Set the write mode
    function s:set_write(file,...)
        if a:0
            call s:dict(a:file, 'write', a:1 )
        else
            echo s:dict(a:file,'write')
        endif
    endfunction

    " Set the caching mode
    function s:set_cache(file,...)
        if a:0
            call s:dict(a:file, 'cache', !!a:1 )
        else
            echo s:dict(a:file,'cache')?'LatexPreviewerCacheOn':'LatexPreviewerCacheOff'
        endif
    endfunction
endif

" Determine the root document and set the appropriate directories.
call s:get_root(expand('%:p'))
call s:mkdir(s:tmpdir(expand('%:p')) . "buf")
call s:mkdir(s:tmpdir(expand('%:p')) . "compile")
call s:mkdir(s:tmpdir(expand('%:p')) . "diff")
call s:mkdir(s:tmpdir(expand('%:p')) . "mount")

" Command definitions
command! -buffer LatexPreview call s:run(expand('%:p'))
command! -buffer LatexPreviewOn call s:set_enabled(expand('%:p'),1)
command! -buffer LatexPreviewOff call s:set_enabled(expand('%:p'),0)
command! -buffer LatexPreviewToggle call s:set_enabled(expand('%:p'), !s:dict(expand('%:p'),'enabled') )
command! -buffer LatexPreviewCacheOn call s:set_cache(expand('%:p'),1)
command! -buffer LatexPreviewCacheOff call s:set_cache(expand('%:p'),0)
command! -buffer LatexPreviewCacheToggle call s:set_cache(expand('%:p'), !s:dict(expand('%:p'),'cache') )
command! -buffer LatexPreviewSyncOn call s:set_sync(expand('%:p'),1)
command! -buffer LatexPreviewSyncOff call s:set_sync(expand('%:p'),0)
command! -buffer LatexPreviewSyncToggle call s:set_sync(expand('%:p'), !s:dict(expand('%:p'),'sync') )
command! -buffer -nargs=? LatexViewer call s:set_preview_app(expand('%:p'),<f-args>)
command! -buffer -nargs=? LatexPreviewMode call s:set_mode_by_name(expand('%:p'),<f-args>)
command! -buffer -nargs=? LatexPreviewTimer call s:set_timer(expand('%:p'),<f-args>)
command! -buffer -nargs=? LatexPreviewWriteMode call s:set_write(expand('%:p'),<f-args>)
command! -buffer NextLatexPreviewMode 
            \ call s:dict( expand('%:p'), 'mode', ( s:dict(expand('%:p'),'mode') + 1 ) % 3 )
command! -buffer PrevLatexPreviewMode 
            \ call s:dict( expand('%:p'), 'mode', ( s:dict(expand('%:p'),'mode') + 2 ) % 3 )
command! -buffer LatexPreviewLog call s:show_log(expand('%:p'))

" Autocommands
au! _latex_previewer_ TextChanged,TextChangedI <buffer> call s:run_if_enabled(expand('<afile>:p'))
au _latex_previewer_ BufUnload <buffer> call s:quitting()
au _latex_previewer_ BufFilePost,BufReadPost,BufNewFile <buffer> call s:get_root(expand('<afile>:p'))
