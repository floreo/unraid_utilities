#!/bin/bash

. /boot/config/plugins/user.scripts/scripts/Transmission_Move/transmission_move.conf

torrents="$( docker exec -i transmission transmission-remote -n ${credentials} -l )"
while read -r torrent; do
  if [ -n "$( echo "${torrent}" | grep 'Done' | grep '100%' )" ]; then
    id="$( echo "${torrent}" | awk '{ print $1 }' | grep -Eo '[0-9]+' )"
    labels="$( docker exec -i transmission transmission-remote -n ${credentials} -t${id} -i | grep "Labels:" | cut -d ':' -f2 | awk '{$1=$1};1' )"
    name="$( docker exec -i transmission transmission-remote -n ${credentials} -t${id} -i | grep "Name:" | cut -d ':' -f2 | awk '{$1=$1};1' )"
    echo ${id}
    echo "${labels}"
    echo "${name}"
    echo
    if [[ "$labels" == *movie* ]]; then
      ls "${src}${name}"
      mv "${src}${name}" "${dst}movies/${name}" && \
        docker exec -i transmission transmission-remote -n ${credentials} -t${id} -r
    elif [[ "$labels" == *serie* ]]; then
      serie_name=$( echo "${labels}" | sed -E 's/.*serie (.*)/\1/' )
      if [ ! -z "$serie_name" ]; then
        ls "${src}/${name}"
        echo "SERIE: $serie_name"
        #mkdir -p /mnt/titi/$serie_name
      fi
    fi
  fi
done <<< "${torrents}"
