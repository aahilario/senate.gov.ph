#!/bin/bash
PACKLIMIT=10
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
  if [ -z $DEBUG ]; then
    mv -f lisdata.pack{,.sh}
    ./lisdata.pack.sh
    echo
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
