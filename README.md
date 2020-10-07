neovim-latex-previewer
======================
This is an nvim plugin designed to do live pdf updates of latex projects for
preview.

## Features

The main idea of this plugin was to help me typeset my thesis. Several latex
previewers for vim exist, but this one has two different diff modes, which work
on projects with multiple files.

By setting the mode to diff, you see the differences between the version of the
file that you are currently typing and the version which is saved to disk.

By setting the mode to git, you see the differences between the version of the
file that you are currently typing and the latest commit.

## Dependencies

nvim-latex-previewer uses latexmk to typeset documents and does a unionmount
with fuse to superimpose the edited versions of files over the current saved
versions. It therefore depends on:

* mupdf (currently the only fully supported previewer)
* unionmount-fuse
* latexmk (currently the only supported compiler)
* xdotool (for sync)

## Installation
On my current setup, I've installed this with
[vim-plug](https://github.com/junegunn/vim-plug). After installing vim-plug,
just add `Plug 'emakman/nvim-latex-previewer'` to your plugin section, restart,
and then do a `:PlugInstall`.

I don't consider this previewer to be configuration-free however. I recommend
putting something like the following into ~/.config/nvim/ftplugin/tex.vim:

    nmap <buffer> <Leader>p :LatexPreviewToggle<CR>
    nmap <buffer> <Leader>[ :PrevLatexPreviewMode<CR>
    nmap <buffer> <Leader>] :NextLatexPreviewMode<CR>

This way you can enable/disable previewing by typing `\-p`, and change the mode
by typing `\-[` and `\-]` (replace `\` with your current mapleader).

## Magic Comments
The previewer behavior can be modified by beginning your document with a "magic
comment". The most important is the TeX root directive: 

>    % !TeX root = main.tex

Which tells the previewer which file to feed to tex. The previewer expects all
files referenced by the root directory to be in some subdirectory of the
directory that contains it.

The next directive is the TeX program directive:

>    % !TeX program = latex

you can use this to set the program to tex (plain tex), latex, xetex, or luatex.
If you set it to anything else, it will run latex, but change the -progname.
This may change the format files that are used. Finally, we have the TeX options
directive:

>    % !TeX options = nonstop, synctex

You can use this to set a list of command-line options for latex:

| Setting      | command-line options       |
| ------------ | -------------------------- |
| enc          | -enc -ini                  |
| flerror      | -file-line-error           |
| !flerror     | -no-file-line-error        |
| ini          | -ini                       |
| batch        | -interaction=batchmode     |
| nonstop      | -interaction=nonstopemode  |
| scroll       | -interaction=scrollmode    |
| errorstop    | -interaction=errorstopmode |
| shellescape  | -shell-escape              |
| !shellescape | -no-shell-escape           |
| srcspecials  | -src-specials              |
| !srcspecials | -no-src-specials           |
| synctex      | -synctex=1                 |
| !synctex     | -synctex=0                 |

## Commands
nvim-latex-previewer defines the following commands: 

    LatexPreview

Immediately compiles the document and opens the preview.

    LatexPreviewOn
    LatexPreviewOff
    LatexPreviewToggle

Enable or disable live preview. When previewing is first enabled, the document
will be typeset and (if successful) will open in the selected viewer (for now,
that means MuPDF).

    LatexPreviewMode <mode>
    NextLatexPreviewMode
    PrevLatexPreviewMode

This sets the preview mode. Choices are:

| Setting | Behavior                                                             |
| ------- | -------------------------------------------------------------------- |
| plain   | Typeset the current version of the document in the buffer. (default) |
| diff    | Typeset the diff of the current version against the saved version.   |
| git     | Typeset the current version of the document against the git master.  |

    LatexPreviewTimer <n>

Set a timer for compilation. When enabled, the document will update every `n`
seconds. To disable this feature, set the timer interval to -1.

    LatexPreviewSyncOn
    LatexPreviewSyncOff
    LatexPreviewSyncToggle

Enable or disable sync mode (enabled by default). When sync mode is enabled,
the preview will fast-forward to the page containing the text being edited
each time it updates.

    LatexPreviewCacheOn
    LatexPreviewCacheOff
    LatexPreviewCacheToggle

Enable or disable the preview cache. When this is enabled, a folder named .nlp
will be created in the directory containing the project root, in which all
files created during compilation will be stored. This can help improve
initial compile speed when reopening the document but has no other benefits.

    LatexPreviewWriteMode <mode>

This setting determines which files are saved to the project's root directory. 
It can be any of the following:

| Setting | Behavior |
| ------- | -------- |
| 0 | No files are saved. |
| !tex | Saves all files with extensions other than tex. |
| ext1\|ext2 | Saves all files with extension ext1 or ext2. This list can contain any number of extensions separated by \| |

The default setting is 'pdf'.

    LatexViewer <viewer>

The executable used for viewing the document. Only mupdf will sync, but other
viewers will likely open correctly at least.

    LatexPreviewLog

Shows a log of the last compile. This will generate errors if the document has
not been compiled yet, and will update when the document is recompiled
(specifically to avoid problems with timed compilation).
