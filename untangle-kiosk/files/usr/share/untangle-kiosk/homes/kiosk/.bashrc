if [ `tty` = "/dev/tty1" ]; then
  nohup startx &
  exit
fi
