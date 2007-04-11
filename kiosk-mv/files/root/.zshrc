# test function
is4 () {
  [[ $ZSH_VERSION == 4.* ]]
}
is4.2 () {
  [[ $ZSH_VERSION == 4.2.* ]]
}

# run zsh version 4 if it's available
ZSH4=/usr/local/bin/zsh
if ! is4 && [[ $OSTYPE == solaris* ]] && [ -f $ZSH4 ] ; then
  SHELL=$ZSH4 $ZSH4 -l && echo about to exit && sleep 3 # last parts for debug
  exit
fi

###################################
# Modules & Options
###################################

# modules
is4 && zmodload -i zsh/complist
is4 && zmodload -i zsh/parameter
is4.2 && _comp_setup+=$'\ntypeset -a userdirs'
is4 && zmodload -i zsh/mathfunc

# modes
is4 && autoload -U zed
is4 && autoload -U zmv
is4 && autoload -U edit-command-line
is4 && autoload -U compinit && compinit
is4 && autoload -U colors && colors
is4 && autoload -U insert-files
is4 && autoload -U history-search-end

# mailcheck
#mailpath=(/var/mail/${USERNAME})

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
is4 && setopt bare_glob_qual
       setopt NO_beep
is4 && setopt NO_check_jobs
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
is4 && setopt hist_save_no_dups
is4 && setopt hist_ignore_all_dups
       setopt hist_reduce_blanks
       setopt hist_verify
is4 && setopt inc_append_history
       setopt ksh_option_print
is4 && setopt list_packed
is4 && setopt NO_list_rows_first
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
is4 && setopt share_history

###################################
# Environment
###################################
typeset -xA extensions # this dictionary is also used by the lst() function
extensions=()
extensions[docs]="doc dvi html odf pdf pps ppt ps rtf tex txt xls xml"
extensions[archives]="ace arj bin bz2 cdr deb dmg ear exe gz iso jar lzh pgdump rar rpm tar taz tgz udf war xpi z zip"
extensions[movies]="asf avi divx m1v m2v mov mp2 mp4 mpe mpeg mpg ram rm wmv xvid yuv"
extensions[audio]="au mp3 ogg wav wma"
extensions[pics]="bmp gif jpg pbm png ppm tga tif xbm xcf xpm"
extensions[code]="a bash c c++ class cpp elz jacl java ko jy o out pl pm py pyc pyo sh so sql tcl zsh"

# add the uppercase extensions too
for key in ${(k)extensions[@]} ; do
  extensions[$key]="$extensions[$key] ${(U)extensions[$key]}"
done

if is4 ; then # use something smart to associate colors and extensions
  local -A colors
  colors=()
  colors[docs]="02;37"
  colors[archives]="01;31"
  colors[movies]="01;33"
  colors[audio]="00;33"
  colors[pics]="00;36"
  colors[code]="01;35"

  LS_COLORS='ex=01;35:no=00:fi=00;37:di=01;36:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=04;31'
#  LS_COLORS='no=00:fi=00;37:di=01;02;36:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=04;31'
  for key in ${(k)extensions[@]} ; do
    color=${colors[$key]}
    # join on '=${color}:.*', and prepend to LS_COLORS
    LS_COLORS='*.'${(ej,=${color}:*.,)${=${extensions[$key]}}}=${color}:$LS_COLORS
  done
  export LS_COLORS
else # hardcode everything...
  export LS_COLORS='*.bmp=00;36:*.gif=00;36:*.jpg=00;36:*.pbm=00;36:*.png=00;36:*.ppm=00;36:*.tga=00;36:*.tif=00;36:*.xbm=00;36:*.xpm=00;36:*.BMP=00;36:*.GIF=00;36:*.JPG=00;36:*.PBM=00;36:*.PNG=00;36:*.PPM=00;36:*.TGA=00;36:*.TIF=00;36:*.XBM=00;36:*.XPM=00;36:*.doc=02;37:*.dvi=02;37:*.html=02;37:*.pdf=02;37:*.ps=02;37:*.rtf=02;37:*.tex=02;37:*.txt=02;37:*.xls=02;37:*.xml=02;37:*.DOC=02;37:*.DVI=02;37:*.HTML=02;37:*.PDF=02;37:*.PS=02;37:*.RTF=02;37:*.TEX=02;37:*.TXT=02;37:*.XLS=02;37:*.XML=02;37:*.c=01;35:*.c++=01;35:*.class=01;35:*.cpp=01;35:*.elz=01;35:*.jacl=01;35:*.java=01;35:*.jy=01;35:*.o=01;35:*.out=01;35:*.pl=01;35:*.pm=01;35:*.py=01;35:*.pyc=01;35:*.sh=01;35:*.so=01;35:*.sql=01;35:*.zsh=01;35:*.C=01;35:*.C++=01;35:*.CLASS=01;35:*.CPP=01;35:*.ELZ=01;35:*.JACL=01;35:*.JAVA=01;35:*.JY=01;35:*.O=01;35:*.OUT=01;35:*.PL=01;35:*.PM=01;35:*.PY=01;35:*.PYC=01;35:*.SH=01;35:*.SO=01;35:*.SQL=01;35:*.ZSH=01;35:*.mp3=00;33:*.ogg=00;33:*.wav=00;33:*.wma=00;33:*.MP3=00;33:*.OGG=00;33:*.WAV=00;33:*.WMA=00;33:*.asf=01;33:*.avi=01;33:*.divx=01;33:*.mov=01;33:*.mpeg=01;33:*.mpg=01;33:*.wmv=01;33:*.ASF=01;33:*.AVI=01;33:*.DIVX=01;33:*.MOV=01;33:*.MPEG=01;33:*.MPG=01;33:*.WMV=01;33:*.arj=01;31:*.bz2=01;31:*.deb=01;31:*.ear=01;31:*.gz=01;31:*.jar=01;31:*.lzh=01;31:*.rar=01;31:*.rpm=01;31:*.tar=01;31:*.taz=01;31:*.tgz=01;31:*.war=01;31:*.z=01;31:*.zip=01;31:*.ARJ=01;31:*.BZ2=01;31:*.DEB=01;31:*.EAR=01;31:*.GZ=01;31:*.JAR=01;31:*.LZH=01;31:*.RAR=01;31:*.RPM=01;31:*.TAR=01;31:*.TAZ=01;31:*.TGZ=01;31:*.WAR=01;31:*.Z=01;31:*.ZIP=01;31:no=00:fi=00;37:di=01;36:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=04;31'
fi

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

WORDCHARS=

# misc
EDITOR_ZSH=(emacs -nw)
export EDITOR="emacs -nw"
if which less > /dev/null ; then
  export PAGER=less
#  export LESS='--RAW-CONTROL-CHARS --tabs=8 -r'
#  export LESSOPEN='| /usr/bin/lesspipe %s'
#  export LESSCLOSE='/usr/bin/lesspipe %s %s'
else
  export PAGER=more
fi

export CVS_RSH=ssh
local -a javas ; javas=(/usr/lib/jvm/java*sun*(DN) /usr/local/j2*(DN))
if [[ ${#javas} -gt 0 ]] ; then
  export JAVA_HOME=$javas[-1]
  export JAVA=${JAVA_HOME}/bin/java
  path=($path $JAVA_HOME/bin)
fi

export XTERM="aterm-xterm -tr -sh 80 -fg White -bg Black -fn -jmk-neep-medium-r-normal--15-140-75-75-c-80-iso8859-15 -g 80x54 +sb -sl 10000 &"
#export XTERM="aterm-xterm -tr -sh 80 -fg White -bg Black -g 80x54 +sb -sl 10000 &"

ZSH_CONFIG_FILES=(~/.z(log|sh)^(_*|*~)(.) ~/.zsh/functions/_*)

# ulimit
limit coredumpsize 0 # don't allow coredumps

###################################
# Key bindings
###################################
bindkey '^W' kill-region
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey '\e[A' history-beginning-search-backward-end
bindkey '\e[B' history-beginning-search-forward-end

###################################
# Completion settings
###################################

# completion styles
is4 && zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
is4 && [ -f ~/.ssh/known_hosts ] && zstyle ':completion:*:hosts' hosts `sed -e 's/[\,\ ].*//' ~/.ssh/known_hosts | xargs`
is4 && zstyle ':completion:*:processes' command 'ps h -u ${USER} --forest -o pid,cmd'
is4 && zstyle ':completion:*:processes-names' command 'ps -u ${USER} -o command'
is4 && zstyle ':completion:*:*:kill:*:processes' list-colors "=(#b) #([0-9]#)*=0=01;32"
is4 && zstyle ':completion:*:*:kill:*:processes' sort false
is4 && zstyle ':completion:*:*:killall:*:processes-names' list-colors "=*=01;32"
is4 && zstyle ':completion:*:warnings' format "%B$fg[red]%}---- no match for: $fg[white]%d%b"
is4 && zstyle ':completion:*:messages' format '%B%U---- %d%u%b'
is4 && zstyle ':completion:*:corrections' format '%B---- %d (errors %e)%b'
is4 && zstyle ':completion:*' verbose 'yes'
is4 && zstyle ':completion:*' file-sort name
is4 && zstyle ':completion:*' menu select=long

# completion for functions
is4 && compdef _connect-run connect run
is4 && compdef _cvs cvsseb
is4 && compdef _hosts dig digs
is4 && compdef '_deb_packages expl uninstalled' i
is4 && compdef _python-doc pydoc-html
is4 && compdef '_files -W $HELPDIR' run-help
is4 && compdef _smartsudo s
is4 && compdef _initd-service se
is4 && compdef _locales setlocale
is4 && compdef _which what

###################################
# HOST/OSTYPE specificities
###################################

# OS specificities
case $OSTYPE in
  solaris*)
    path=(/opt/sfw/bin /opt/sfw/sbin /opt/csw/bin /opt/csw/sbin /usr/ucb /usr/ccs/bin /usr.local/bin /usr.local/sbin /usr.local/local/bin /usr.local/local/sbin $path)
    manpath=(/usr.local/man $manpath)
    export MANPATH
    [ -d /opt/csw/share/terminfo ] && export TERMINFO=/opt/csw/share/terminfo
    case $TERM in
      rxvt) export TERM=xterm ;;
      screen) who am i | grep -qv :S && export TERM=vt100 ;;
    esac ;;
  darwin*)
    [ "${TERM}" = "rxvt" ] && export TERM=xterm ;;
  *bsd*)
    if [[ $OSTYPE == openbsd* ]] ; then
      local o=usa.openbsd.org
      export CVSROOT=anoncvs@anoncvs3.$o:/cvs
      export PKG_PATH=ftp://ftp3.$o/pub/OpenBSD/`uname -r`/packages/i386
    fi ;;
esac

source ~/.zsh.prompt
source ~/.zsh.alias
source ~/.zsh.function
