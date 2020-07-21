#!/bin/bash
# Tesseract OCR queue 
QUEUE=ocr-queue.d
FILE=$(basename $1)
HASH=$(md5sum $FILE | sed -r -e 's@^([^ ]{1,}) (.*)$@\1@g')
if [ ! -d $QUEUE ]; then
  mkdir $QUEUE
fi
grep -q $HASH $QUEUE/pending 2> /dev/null || {
  echo "$HASH $FILE" | tee -a ${QUEUE}/pending
}

if [ ! -f ${QUEUE}/active ]; then
  touch ${QUEUE}/active
fi

IN_QUEUE=$(wc -l ${QUEUE}/active | sed -r -e 's@^([0-9]{1,}) .*$@\1@g')

if [ "$IN_QUEUE" -lt 1 ]; then
  head -n1 ${QUEUE}/pending > ${QUEUE}/active
fi

if [ $IN_QUEUE -eq 1 ]; then
  HASH=$(cat ${QUEUE}/active | sed -r -e 's@^([^ ]{1,})[ ]+(.*)$@\1@g')
  SOURCE=$(cat ${QUEUE}/active | sed -r -e 's@^([^ ]{1,})[ ]+(.*)$@\2@g')
  echo "In queue: $SOURCE"
  if [ ! -d ${QUEUE}/${HASH} ]; then
    mkdir ${QUEUE}/${HASH}
  fi
  if [ ! -f ${QUEUE}/${HASH}/source.pdf ]; then
    cp $SOURCE ${QUEUE}/${HASH}/source.pdf
  fi
fi
