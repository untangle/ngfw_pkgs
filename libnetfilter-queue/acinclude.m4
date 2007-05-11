
dnl The --with-nfnetlink parameter gives the option to reference a
dnl libnfnetlink library that is not installed in one of the standard
dnl places.

AC_DEFUN([NETFILTER_SET_PATH_TO_LIBNFNETLINK], [
dnl These two variables are set to the include resp. library path.
dnl Additional the CFLAGS and LDFLAGS must be updated, so that further
dnl tests can pick up the new settings

ADD_CFLAGS_FOR_LIBNFNETLINK=""
ADD_LDFLAGS_FOR_LIBNFNETLINK=""
AC_ARG_WITH(nfnetlink,
  [  --with-nfnetlink=PATH   Use nfnetlink in PATH],
  [ if test "x$withval" = "xno" ; then
        AC_MSG_ERROR([*** nfnetlink is required ***])
    elif test "x$withval" != "xyes"; then
      if test -d "$withval/lib"; then
       ADD_LDFLAGS_FOR_LIBNFNETLINK="-L${withval}/lib"
       AC_MSG_RESULT(setting libnetlink library dir: ${withval}/lib)
      else
       ADD_LDFLAGS_FOR_LIBNFNETLINK="-L${withval}"
       AC_MSG_RESULT(setting libnetlink library dir: ${withval})
      fi
      if test -d "$withval/include"; then
       ADD_CFLAGS_FOR_LIBNFNETLINK="-I${withval}/include"
       AC_MSG_RESULT(setting libnetlink include dir: ${withval}/include)
      else
       ADD_CFLAGS_FOR_LIBNFNETLINK="-I${withval}"
       AC_MSG_RESULT(setting libnetlink include dir: ${withval})
      fi
    fi ]
)
AC_SUBST(ADD_CFLAGS_FOR_LIBNFNETLINK)
AC_SUBST(ADD_LDFLAGS_FOR_LIBNFNETLINK)
CFLAGS="$ADD_CFLAGS_FOR_LIBNFNETLINK $CFLAGS"
CPPFLAGS="$ADD_CFLAGS_FOR_LIBNFNETLINK $CPPFLAGS"
LDFLAGS="$ADD_LDFLAGS_FOR_LIBNFNETLINK $LDFLAGS"
])

