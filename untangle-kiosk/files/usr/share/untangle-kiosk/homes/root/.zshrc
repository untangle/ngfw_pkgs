###################################
# Modules & Options
###################################

# modules
zmodload -i zsh/complist
zmodload -i zsh/parameter
_comp_setup+=$'\ntypeset -a userdirs'
zmodload -i zsh/mathfunc

# modes
autoload -U zed
autoload -U zmv
autoload -U edit-command-line
autoload -U compinit && compinit
autoload -U colors && colors
autoload -U insert-files
autoload -U history-search-end

# help
autoload run-help
alias run-help > /dev/null && unalias run-help

#options
setopt append_history
setopt NO_auto_cd
setopt NO_auto_menu
setopt auto_name_dirs
setopt auto_pushd
setopt autolist
setopt bare_glob_qual
setopt NO_beep
setopt NO_check_jobs
setopt NO_clobber
setopt cdable_vars
setopt complete_in_word
setopt correct
setopt extended_glob
setopt extended_history
setopt NO_flow_control
setopt glob_complete
setopt hash_cmds
setopt hash_dirs
setopt hist_allow_clobber
setopt hist_ignore_space
setopt hist_save_no_dups
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt hist_verify
setopt inc_append_history
setopt ksh_option_print
setopt list_packed
setopt NO_list_rows_first
setopt mark_dirs
setopt NO_menucomplete
setopt NO_multios
setopt NO_nomatch
setopt nohup
setopt NO_notify
setopt path_dirs
setopt NO_print_exit_value
setopt pushd_ignore_dups
setopt NO_pushd_minus
setopt pushd_silent
setopt pushd_to_home
setopt rc_expand_param
setopt rc_quotes
setopt NO_singlelinezle
setopt share_history

###################################
# Environment
###################################
literal="RRR"
typeset -xA extensions # this dictionary is also used by the lst() function
extensions=()
extensions[backup]="${literal}~ ${literal}# bak"
extensions[docs]="calendar doc dvi emacs html ics odf odt pdf pps ppt ps reg rtf srt tex txt todo xls xml"
extensions[archives]="ace arj bin bz2 cdr deb dmg ear exe gz iso jar lzh pgdump rar rpm tar taz tgz udeb udf war xpi z zip"
extensions[video]="3gp asf avi divx flv ifo m1v m2v mkv mov mp2 mp4 mpe mpeg mpg ram rm wmv xvid yuv"
extensions[audio]="au mp3 ogg wav wma"
extensions[pics]="bmp gif jpeg jpg pbm png ppm tga tif xbm xcf xpm"
extensions[code]="${literal}Makefile a bash c c++ class cpp diff el elz jacl java js jy ko lua o out patch pl pm py pyc pyo rb sh so sql tcl zsh"

# add the uppercase extensions too
for key in ${(k)extensions[@]} ; do
  extensions[$key]="$extensions[$key] ${(U)extensions[$key]}"
done

# history
HISTSIZE=1000000
SAVEHIST=1000000
HISTFILE=~/.zsh_history
HELPDIR=~/.zsh/help
MAILCHECK=0

# logins/logouts watch
LOGCHECK=30 # in seconds
WATCH=all
WATCHFMT="[%D %T] %n has %a %l from %M"

export PAGER=less

# ulimit
limit coredumpsize 0 # don't allow coredumps

###################################
# Key bindings
###################################
alias myls="ls -ldh --color *(N/) ; ls -lh --color *(^/) 2> /dev/null"
bindkey -e
bindkey -s "^o"   '; myls \r'
bindkey -s "^b"   'cd ..\r'
bindkey -s "^f"   'popd\r'

###################################
# Completion settings
###################################

# completion styles
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
[ -f ~/.ssh/known_hosts ] && zstyle ':completion:*:hosts' hosts `sed -e 's/[\,\ ].*//' ~/.ssh/known_hosts | xargs`
zstyle ':completion:*:processes' command 'ps h -u ${USER} --forest -o pid,cmd'
zstyle ':completion:*:processes-names' command 'ps -u ${USER} -o command'
zstyle ':completion:*:*:kill:*:processes' list-colors "=(#b) #([0-9]#)*=0=01;32"
zstyle ':completion:*:*:kill:*:processes' sort false
zstyle ':completion:*:*:killall:*:processes-names' list-colors "=*=01;32"
zstyle ':completion:*:warnings' format "%B$fg[red]%}---- no match for: $fg[white]%d%b"
zstyle ':completion:*:messages' format '%B%U---- %d%u%b'
zstyle ':completion:*:corrections' format '%B---- %d (errors %e)%b'
zstyle ':completion:*' verbose 'yes'
zstyle ':completion:*' file-sort name
zstyle ':completion:*' menu select=long

# completion for functions
compdef _hosts dig digs
compdef _locales setlocale
compdef _which what

# ZSH prompt
PROMPT=$'[%{\e[1;34m%}%n%{\e[0m%} @ %U%m%u] %{\e[0;32m%}%~%{\e[0m%} # '
RPROMPT=$''
case $TERM in
  rxvt*)
    precmd() { print -Pn "\e]0;%n@%m\a" } ;;
  sun*|vt*|screen*|xterm*)
    precmd() { print -Pn "\ek%n@%m\e\\" } ;;
  *)
    true
esac


