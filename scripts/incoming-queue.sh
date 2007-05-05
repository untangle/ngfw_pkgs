#! /bin/sh

REP=/var/www/untangle
INCOMING=$REP/incoming

for i in $INCOMING/*.changes; do
  DISTRIBUTION=$(cat $i | grep '^Distribution: ' | sed 's/Distribution: //')
  reprepro -Vb $REP include $DISTRIBUTION $i
  reprepro -Vb $REP includedsc $DISTRIBUTION ${i/.changes/.dsc}

  # Delete the referenced files
  sed '1,/Files:/d' $i | sed '/BEGIN PGP SIGNATURE/,$d' \
       | while read MD SIZE SECTION PRIORITY NAME; do
        
      [ -z "$NAME" ] && continue

      if [ -f "$INCOMING/$NAME" ]; then
          rm "$INCOMING/$NAME"  || exit 1
      fi
  done

  # Finally delete the .changes file itself.
  rm -f $i
done
