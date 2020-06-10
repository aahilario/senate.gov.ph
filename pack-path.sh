#!/bin/bash
PACKSIZE=20
diff --context=$(cat lisdata.current | wc -l) lisdata.{exclude,current} | grep '^+' | sed -r -e 's@^\+ @@g' > lisdata.keep
Q=0
while true; do
  N=$(cat lisdata.keep | wc -l)
  M=$N
  P=$PACKSIZE
  [ $N -lt $PACKSIZE ] && P=$N 
  cat <<EOF > lisdata.pack
#!/bin/bash
DATESTAMP=\$(date +"%Y%m%d-%H%M%S")
EOF
  head -n$P lisdata.keep >> lisdata.pack
 
  ((N-=P))
  tail -n$N lisdata.keep > lisdata.remainder
  mv lisdata.remainder lisdata.keep
  echo $M $N
  sed -i -r -e 's@^([^#$]{1,})$@  git add "\1"@g' lisdata.pack
  cat <<EOF >> lisdata.pack
git commit -a -m "PDF files fetched via wget --mirror on or before \$DATESTAMP"
git push
EOF

  chmod 755 lisdata.pack
  cat lisdata.pack
  bash lisdata.pack
  sleep 3

  if [ $N -le 0 ]
  then break
  fi
  ((Q++))
done

echo "Iterations: $Q"
