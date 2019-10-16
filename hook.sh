#!/usr/bin/env bash


# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright 2016 Brian Bennett
#

restart_service() {
    local SERVICE="${1}"

    # This hook is called once for each service to restart
    #
    # Parameters:
    # - SERVICE
    #   The service identifier to restart

    uname_s=$(uname -s)
    case "$uname_s" in
        SunOS)
            if svcs -H "${SERVICE}" | grep ^online; then
                if svcprop -p refresh "${SERVICE}"; then
                    printf 'Refreshing %s...' "${SERVICE}"
                    svcadm refresh "${SERVICE}"
                else
                    printf 'Restarting %s...' "${SERVICE}"
                    svcadm restart "${SERVICE}"
                fi
                printf 'done.\n'
            else
                printf 'Service "%s" is not online, skipping.\n' "${service}"
            fi
            ;;
        FreeBSD)
            service "$SERVICE" restart
            ;;
        Linux)
            # FFS.
            # http://unix.stackexchange.com/q/18209/3309
            if [[ -f "/etc/init.d/$SERVICE" ]]; then
                # sysv-init, and compatible
                "/etc/init.d/$SERVICE" restart
            elif init --version =~ 'upstart'; then
                # upstart, without sysv-init compatible scripts
                service "$SERVICE" restart
            elif command -v rc-service; then
                # OpenRC
                rc-service "$SERVICE" restart
            elif systemctl is-active "$SERVICE"; then
                # systemd
                systemctl restart "$SERVICE"
            else
                printf 'Unknown Linux init style.  '
                printf '%s not restarted.\n' "$SERVICE"
            fi
            ;;
        *)
            printf 'Restarting services not yet supported on %s.\n' "$uname_s"
            ;;
    esac

}

deploy_challenge() {
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
    cd "${WEBROOT}" || exit
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
        http-server "${PWD}" -a '::' -p 80 &
        # Store the PID to kill it in clean_challenge.
        printf '%s' "$!" > "${WELLKNOWN}/http-server.pid"
        # Give node time to start
        sleep 10
    fi
    #echo "Listening in ${PWD}"
    #echo "curl -i http://64.30.128.110/.well-known/acme-challenge/${TOKEN_FILENAME:?}"
}

clean_challenge() {
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
        if command -v pwait; then
            pwait "$SERVER_PID"
        else
            # Sigh.
            sleep 10
        fi
        rm "${WELLKNOWN}/http-server.pid"
    fi
    [[ -f "${WELLKNOWN}/${TOKEN_FILENAME}" ]] && rm "${WELLKNOWN:?}/${TOKEN_FILENAME:?}"
    true

}

deploy_cert() {
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

    export DOMAIN KEYFILE CERTFILE FULLCHAINFILE CHAINFILE TIMESTAMP
    # Ensure we have a dhparam file
    DHFILE="$SSLBASE/dhparam.pem"
    if ! [[ -f $DHFILE ]]; then
        openssl dhparam -out "$DHFILE" 2048
    fi
    # Create a fully bundled PEM, containing everything.
    cat "$KEYFILE" "$FULLCHAINFILE" "$DHFILE" > "$CERTDIR/$DOMAIN/fullbundle.pem"
    chown -R "${OWNER:-root}" "$CERTDIR"
    chmod 0644 "$DHFILE"
    #shellcheck disable=SC2153
    for service in "${SERVICES[@]}"; do
        restart_service "$service"
    done

}

unchanged_cert() {
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

invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"

    # This hook is called if the challenge response has failed, so domain
    # owners can be aware and act accordingly.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - RESPONSE
    #   The response that the verification server returned

    echo "HOOK: ${FUNCNAME[*]}"

}

request_failure() {
    local STATUSCODE="${1}" REASON="${2}" REQTYPE="${3}"

    # This hook is called when an HTTP request fails (e.g., when the ACME
    # server is busy, returns an error, etc). It will be called upon any
    # response code that does not start with '2'. Useful to alert admins
    # about problems with requests.
    #
    # Parameters:
    # - STATUSCODE
    #   The HTML status code that originated the error.
    # - REASON
    #   The specified reason for the error.
    # - REQTYPE
    #   The kind of request that was made (GET, POST...)

    echo "HOOK: ${FUNCNAME[*]}"

}

startup_hook() {
  # This hook is called before the cron command to do some initial tasks
  # (e.g. starting a webserver).

  :

    echo "HOOK: ${FUNCNAME[*]}"

}

exit_hook() {
  # This hook is called at the end of the cron command and can be used to
  # do some final (cleanup or other) tasks.

  :

    echo "HOOK: ${FUNCNAME[*]}"

}

# Get the global config variables
# shellcheck disable=SC1090
source "${CONFIG:-config}"

HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert|unchanged_cert|invalid_challenge|request_failure|startup_hook|exit_hook)$ ]]; then
  "$HANDLER" "$@"
fi
