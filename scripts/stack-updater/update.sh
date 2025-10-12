#!/bin/bash

if [ $# -eq 0 ]; then
  DIRECTORY_NAMES="$(ls -d -- */)"
else
  DIRECTORY_NAMES="$@"
fi

for DIRECTORY_NAME in $DIRECTORY_NAMES
do
    RELATIVE_DIRECTORY=./$DIRECTORY_NAME
    if [ -d "$RELATIVE_DIRECTORY" ]; then
      cd $RELATIVE_DIRECTORY
      docker compose down && docker compose pull && docker compose up -d
      cd ../
    else
      echo "$DIRECTORY_NAME does not exit"
    fi
done