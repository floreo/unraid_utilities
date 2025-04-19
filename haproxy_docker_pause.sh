#!/usr/bin/env bash

# Connects to the haproxy socket
# Get scur of _haproxy_backends
# docker pause or unpause if there's any trafic

declare -a _containers_to_track=( \
    "audiobookshelf"
    "Collabora-CODE"
    "Grafana"
    "jellyfin"
    "Kavita"
    "LubeLogger"
    "Mealie"
    "medusa"
    "NGinx"
    "nextcloud"
    "open-webui"
    "ovaliash"
    #"tvheadend"
    "vaultwarden"
)

declare -a _containers_lifetime=( \
    "0"
    "0"
    "0"
    "0"
    "0"
    "0"
    "0"
    "0"
    "0"
    "0"
    "0"
    "0"
    #"0"
    "0"
)

declare -a _haproxy_backends=( \
    "audiobook"
    "office"
	  "grafana"
    "jellyfin"
    "ebook"
    "vehicle"
    "mealie"
    "medusa"
    "www"
    "nextcloud"
    "open-webui"
    "alias"
    #"tvheadend"
    "vault"
)

## Pause all containers when init
for _container_to_track in "${_containers_to_track[@]}";
do
	docker pause "${_container_to_track}" &>/dev/null
	sleep 0.1
done

while true;
do
    exec 3<>/dev/tcp/172.76.0.2/9999
    echo "show stat" >&3
    
    while IFS=, read -r _pxname _svname _qcur _qmax _scur _smax _slim _stot _bin _bout; do
        if [[ " ${_haproxy_backends[@]} " =~ " ${_pxname} " && "${_svname}" != "BACKEND" ]]; then
            _i="$(( $(printf "%s\n" "${_haproxy_backends[@]}" | sed -n '/^'${_pxname}'$/{=;q}') - 1 ))"
            _container_to_track="${_containers_to_track[${_i}]}"
            _container_paused="$( docker ps | grep "${_container_to_track}" | grep "Paused" &>/dev/null && echo "ok" || echo "nok" )"
            _haproxy_backend="${_haproxy_backends[${_i}]}"
            echo "found ${_pxname} : ${_scur} : ${_containers_lifetime[${_i}]} | paused: ${_container_paused}"
        else
            continue
        fi
    
        if [ "${_scur}" -ge 1 ]; then
            _containers_lifetime[${_i}]=0
            if [ "${_container_paused}" == "ok" ]; then
                if [ "${_container_to_track}" == "nextcloud" ]; then
                    docker unpause mysql_nextcloud
                    docker unpause redis
                fi
                if [ "${_container_to_track}" == "open-webui" ]; then
                    docker unpause ollama
                fi
                docker unpause "${_container_to_track}"
                echo "unpause ${_container_to_track} -> ${_haproxy_backend}"
            fi
        else
            if [ "${_containers_lifetime[${_i}]}" -ge 300 ]; then
                if [ "${_container_paused}" == "nok" ]; then
                    if [ "${_container_to_track}" == "nextcloud" ]; then
                        docker pause mysql_nextcloud
                        docker pause redis
                    fi
                    if [ "${_container_to_track}" == "open-webui" ]; then
                        docker pause ollama
                    fi
                    docker pause "${_container_to_track}"
                    echo "pause ${_container_to_track} -> ${_haproxy_backend}"
                fi
            else
                ((_containers_lifetime[${_i}]++))
            fi
        fi
    done <&3

    exec 3<&-
    exec 3>&-
	echo
	sleep 1
done
