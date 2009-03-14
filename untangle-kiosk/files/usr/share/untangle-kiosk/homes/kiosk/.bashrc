if [ `tty` = "/dev/tty1" ]; then
  while true ; do
    ps aux | awk '/^(xinit|X|startx)/ { print $2 }' | xargs kill -9 2> /dev/null
    startx
  done
fi
