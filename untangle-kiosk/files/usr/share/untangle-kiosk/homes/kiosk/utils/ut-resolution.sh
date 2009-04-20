#! /bin/sh

# choose new resolution from an ordered list, and bail out if
# something somehow went wrong
if ! gvidm -r $(xrandr | awk '/^ / {print $1}' | sort -rn) ; then
  Xdialog --title Resolution --msgbox "Can not change resolution." 10 30
  exit 1
fi

# write it
xrandr | head -1 | perl -pe 's/.* current (\d+) x (\d+).*/$1x$2/' >| /home/kiosk/.ut-resolution

# restart desktop utils
/home/kiosk/utils/ut-desktop.sh
