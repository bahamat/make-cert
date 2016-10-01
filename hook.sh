#!/usr/bin/env bash


# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright 2016 Brian Bennett
#

function deploy_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    # This hook is called once for every domain that needs to be
    # validated, including any alternative names you may have listed.
    #
    # Parameters:
    # - DOMAIN
    #   The domain name (CN or subject alternative name) being
    #   validated.
    # - TOKEN_FILENAME
    #   The name of the file containing the token to be served for HTTP
    #   validation. Should be served by your web server as
    #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
    # - TOKEN_VALUE
    #   The token value that needs to be served for validation. For DNS
    #   validation, this is what you want to put in the _acme-challenge
    #   TXT record. For HTTP validation it is the value that is expected
    #   be found in the $TOKEN_FILENAME file.

    echo "HOOK: ${FUNCNAME[*]}"
    printf '%s' "${TOKEN_VALUE}" > "${WELLKNOWN:?}/${TOKEN_FILENAME:?}"
    cd "${WEBROOT}"
    #echo "${WELLKNOWN:?}/${TOKEN_FILENAME:?}"
    # Should we spawn a listener?
    # If netstat reports a listner on port 80 it will be stored in $a.
    # If $a is empty (i.e., there is NOT already a listener) then we will
    # start one.
    case $(uname -s) in
        Darwin)
            a=$(netstat -na -p tcp -f inet | awk '/LISTEN/ {if ($4~".80$") {print $4}}')
            ;;
        FreeBSD)
            a=$(netstat -na -p tcp -f inet | nawk '/LISTEN/ {if ($4~".80$") {print $4}}')
            ;;
        SunOS)
            a=$(netstat -na -f inet | nawk '/.80.*LISTEN/ {if ($1~".80$") {print $1}}')
            ;;
        Linux)
            a=$(netstat -natl | awk '{if ($4~":80$") {print $4}}')
            ;;
    esac
    if [[ -z $a ]]; then
        http-server ${PWD} -p 80 &
        # Store the PID to kill it in clean_challenge.
        printf '%s' "$!" > "${WELLKNOWN}/http-server.pid"
        # Give node time to start
        sleep 10
    fi
    #echo "Listening in ${PWD}"
    #echo "curl -i http://64.30.128.110/.well-known/acme-challenge/${TOKEN_FILENAME:?}"
}

function clean_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    # This hook is called after attempting to validate each domain,
    # whether or not validation was successful. Here you can delete
    # files or DNS records that are no longer needed.
    #
    # The parameters are the same as for deploy_challenge.

    echo "HOOK: ${FUNCNAME[*]}"
    if [[ -f "${WELLKNOWN}/http-server.pid" ]]; then
        SERVER_PID=$(cat "${WELLKNOWN}/http-server.pid")
        kill "$SERVER_PID"
        pwait "$SERVER_PID"
        rm "${WELLKNOWN}/http-server.pid"
    fi
    [[ -f "${WELLKNOWN}/${TOKEN_FILENAME}" ]] && rm "${WELLKNOWN:?}/${TOKEN_FILENAME:?}"
    true

}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"

    # This hook is called once for each certificate that has been
    # produced. Here you might, for instance, copy your new certificates
    # to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - TIMESTAMP
    #   Timestamp when the specified certificate was created.

    echo "HOOK: ${FUNCNAME[*]}"

    # Ensure we have a dhparam file
    if ! [[ -f $SSLBASE/dhparam.pem ]]; then
        openssl dhparam -out "$SSLBASE/dhparam.pem" -dsaparam 2048
    fi
    for service in "${SERVICES[@]}"; do
    if svcs -H "${service}" | grep ^online; then
        printf 'Restarting %s...' "${service}"
        svcadm restart "${service}"
        printf 'done.\n'
    else
        printf 'Service "%s" is not online, skipping.\n' "${service}"
    fi
    done

}

function unchanged_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    # This hook is called once for each certificate that is still
    # valid and therefore wasn't reissued.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).

    echo "HOOK: ${FUNCNAME[*]}"

}

# Get the global config variables
source "${CONFIG}"

HANDLER=$1; shift; $HANDLER $@
