#!/bin/bash
case "$1" in 
  new)
    git status | grep -A10000 'Untracked files' | tr '\t' '#' | grep '^##' | sed -r -e 's@^##@@g' | sed -r -e 's@"@@g' -e 's@\\([0-9]{1,3})@?@g' | grep -v '.tar.xz'
    ;;
  types)
    $0 new | file --preserve-date --mime-type --files-from -
    ;;
  add-dirs)
    C=0
    for D in $($0 new); do
      if [ -d "$D" ]; then
        echo $D
        ENTRIES=$(find "$D" -type f ! -name .git | sed -r -e 's@^@  @g' | wc -l)
        if [ $ENTRIES -gt 1 ]; then
          git add "$(find "$D" -type f ! -name .git | head -n1)" && git commit -a -m "Add directory $D/" && git push
        else
          git add "$(find "$D" -type f ! -name .git )" && git commit -a -m "Add directory $D/" && git push
        fi
        ((C++))
      fi
    done
    if [ $C -gt 0 ]; then
      echo "Processed $C directories"
    fi
    ;;
  add-files)
    N=$($0 new | wc -l)
    while [ $N -gt 0 ]; do
      $0 new > lisdata.current
      rm -f lisdata.exclude
      touch lisdata.exclude
      $0 pack-path
      # sleep 5
      if [ ! -z $DO_GC ]; then
        echo "Garbage collection..."
        git gc
        echo "Garbage collection done."
      else
        if [ -z $UNTARXZ ]; then
          read -t 5 -p "Enter 'U' to unpack additional .tar.xz files" NONCE
        else
          NONCE="U"
        fi
        if [ "$NONCE" == "U" ]; then
          $0 untarxz
        fi
      fi
      N=$($0 new | wc -l)
    done
    ;;
  untarxz)
    clear 
    SIZELIMIT=50000000
    SUM=0
    PREVSUM=0
    L=1 
    while [ $L -lt 100 ]; do
      SUMPART=""
      PACKSIZE=$(git status | grep -A10000 'Untracked files:' | sed -r -e 's@\t@#@g' | grep '\.tar\.xz' | sed -r -e 's@^##@@g' | head -n$L | tr '\n' '\0' | du -c --files0-from=- | tail -n1 | tr '\t' ' ' | tr -s ' ' | sed -r -e 's@^([0-9]{1,}) .*$@\1@g')
      for F in $(git status | grep -A10000 'Untracked files:' | sed -r -e 's@\t@#@g' | grep '\.tar\.xz' | sed -r -e 's@^##@@g' | head -n$L); do
        if [ ! -f "$F" ]
          then continue
        fi
        S=$(echo $(tar -vtf "$F" | tr '\t' ' ' | tr -s ' ' | sed -r -e 's@^([^ ]{1,}) ([^ ]{1,}) ([0-9]{1,}) .*@\3+@g'))
        SUMPART="${S}${SUMPART}"
      done 
      SUM=$(echo $SUMPART | sed -r -e 's@\+$@@g' | bc)
      echo "$L: Packed size $PACKSIZE --> $SUM"
      if [ $PREVSUM -eq 0 ]; then
        PREVSUM=$SUM 
      fi 
      if [ $SUM -gt $SIZELIMIT ]; then
        break
      fi 
      PREVSUM=$SUM
      ((L++))
    done 
    echo "Unpacking $L for $PREVSUM < $SIZELIMIT" 
    while [ $L -gt 0 ]; do 
      for F in $(git status | grep -A10000 'Untracked files:' | sed -r -e 's@\t@#@g' | grep '\.tar\.xz' | sed -r -e 's@^##@@g' | head -n$L | tail -n1); do
        echo "Unpacking and removing $F"
        tar -vxf "$F" && rm -fv "$F" 
      done
      ((L--))
    done 
    echo 
    git status | grep -v '\.tar\.xz$' 
    echo 
    df -m
    ;;
  pack-path)
    PACKLIMIT=50
    SIZELIMIT=10000
    diff --context=$(cat lisdata.current | wc -l) lisdata.{exclude,current} | grep '^+' | sed -r -e 's@^\+ @@g' > lisdata.keep
    [ ! -z $TEST ] && exit 0
    Q=0
    while true; do
      N=$(cat lisdata.keep | wc -l)
      M=$N
      PACKSIZE=1
    
      # Keep adding files to the pack until $SIZE exceeds threshold
      while [ $PACKSIZE -lt $PACKLIMIT ]; do
        P=$PACKSIZE
        [ $N -lt $PACKSIZE ] && P=$N 
        head -n$P lisdata.keep > lisdata.pack.tmp
        SIZE=$(cat lisdata.pack.tmp | tr '\n' '\0' | du -c --files0-from=- | tail -n1 | sed -r -e 's@^([0-9]{1,}).*@\1@g')
        if [ $SIZE -gt $SIZELIMIT ]; then
          break
        fi
        ((PACKSIZE++))
      done
    
      cat <<EOF > lisdata.pack
#!/bin/bash
DATESTAMP=\$(date +"%Y%m%d-%H%M%S")
EOF
      cat lisdata.pack.tmp >> lisdata.pack
    
      ((N-=P))
      tail -n$N lisdata.keep > lisdata.remainder
      mv -f lisdata.remainder lisdata.keep
      echo $M $N
      sed -i -r -e 's@^([^#$]{1,})$@  git add "\1"@g' lisdata.pack
      cat <<EOF >> lisdata.pack
git commit -a -m "PDF files fetched via wget --mirror on or before \$DATESTAMP"
git push
EOF
    
      chmod 755 lisdata.pack
      echo
      cat lisdata.pack
      echo "Size: ${SIZE}"
      mv -f lisdata.pack{,.sh}
      ./lisdata.pack.sh
      echo
      if [ ! -z $DEBUG ]; then
        echo "Sleeping for 3..."
        sleep 3
        echo "Done sleeping."
        echo
      fi
    
      if [ $N -le 0 ]
        then break
      fi
      ((Q++))
    done
    echo "Iterations: $Q"
    ;;
  *)
    for F in $(git status | grep -A10000 'Untracked files' | tr '\t' '#' | grep '^##' | sed -r -e 's@^##@@g' | sed -r -e 's@"@@g' -e 's@\\([0-9]{1,3})@?@g'); do
      [ -e $F ] && {
      git add "$F" && basename $F
    } || {
      echo "? $F"
    }
    done | sort -u
    ;;
esac

