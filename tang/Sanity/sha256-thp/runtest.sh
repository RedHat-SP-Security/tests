#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/tang/Sanity/sha256-thp
#   Description: Test tang SHA-256 thumbprints
#   Author: Sergio Correia <scorreia@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="tang"
PACKAGES="tang curl"

# Remove keys.
remove_keys() {
    _jwkdir="${1}"
    rlAssertExists "${_jwkdir}"

    rlRun "rm -f ${_jwkdir}/*.jwk" 0 "Remove regular keys"
    rlRun "rm -f ${_jwkdir}/.*.jwk" 0 "Remove rotated keys"
}

# Full validation of tang advertisement.
check_adv() {
    _adv="${1}"
    rlAssertNotEquals "Make sure advertisement is not empty" "${_adv}" ""
    rlRun "_jws=\$(jose fmt --json='${_adv}' -Oo-)" 0 "Make sure advertisement is valid JSON"
    rlRun "_jwks=\$(jose fmt --json='${_jws}' -Og payload -SyOg keys -AUo-)" 0 "Make sure advertisement is not malformed"
    rlRun "_ver=\$(echo '${_jwks}' | jose jwk use -i- -r -u verify -o-)" 0 "Make sure advertisement is not missing signatures"
    rlRun "_enc=\$(echo '${_jwks}' | jose jwk use -i- -r -u deriveKey -o-)" 0 "Make sure key derivation key is present"

    # Make sure keys are in an array.
    if ! jose fmt --json="${_enc}" -Og keys -A; then
        _enc=$(printf '{"keys": [%s]}' "${_enc}")
    fi

    rlRun "_jwk=\$(echo '${_enc}' | jose fmt -j- -Og keys -Af-)" 0 "Make sure exchange keys are present"
}

# Check if keys are named after their SHA-256 thumbprints.
check_keys() {
    _jwkdir="${1}"
    rlAssertExists "${_jwkdir}"

    pushd "${_jwkdir}"
        # Regular keys.
        for _jwk in *.jwk; do
            [ -e "${_jwk}" ] || continue
            rlRun "_thp256=\$(jose jwk thp -a S256 -i '${_jwk}')"
            rlAssertEquals "Make sure key name matches its SHA-256 thumbprint"  "${_thp256}.jwk" "${_jwk}"
        done

        # Rotated keys.
        for _jwk in .*.jwk; do
            [ -r "${_jwk}" ] || continue
            rlRun "_thp256=\$(jose jwk thp -a S256 -i '${_jwk}')"
            rlAssertEquals "Make sure key name matches its SHA-256 thumbprint"  ".${_thp256}.jwk" "${_jwk}"
        done
    popd
}

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all || rlDie "cannot continue"

        rlRun "packageVersion=$(rpm -q ${PACKAGE} --qf '%{name}-%{version}-%{release}\n')"
        rlTestVersion "${packageVersion}" '>=' 'tang-10-1' \
            || rlDie "Tested functionality is not in old version ${packageVersion}. Minimum expected version is tang-10"

        # Backup any possibly existing keys.
        rlRun "rlFileBackup --clean /var/db/tang/"

        rlRun "rlServiceStart tangd.socket"
    rlPhaseEnd

    rlPhaseStartTest "Make sure the server will create new keys and they are named after their SHA-256 thumbprints"
        # Remove any existing keys.
        rlRun "remove_keys /var/db/tang" 0 "Remove existing keys"

        # Now let's download an advertisement. The server should create
        # a new pair of keys.
        rlRun "adv=\$(curl -sf localhost/adv)" 0 "Download server advertisement"

        # Now let's validate the advertisement as well as verify the keys
        # are named after their SHA-256 thumbprints.
        rlRun "check_adv '${adv}'" 0 "Validate advertisement"
        rlRun "check_keys /var/db/tang" 0 " Make sure keys are named after their SHA-256 thumbprints"
    rlPhaseEnd

    rlPhaseStartTest "Make sure tangd-keygen create keys named after their SHA-256 thumbprints"
        # Remove any existing keys.
        rlRun "remove_keys /var/db/tang" 0 "Remove existing keys"

        rlRun "/usr/libexec/tangd-keygen /var/db/tang" 0 "Create new keys with tangd-keygen"

        # Now let's validate the advertisement as well as verify the keys
        # are named after their SHA-256 thumbprints.
        rlRun "check_adv '${adv}'" 0 "Validate advertisement"
        rlRun "check_keys /var/db/tang" 0 " Make sure keys are named after their SHA-256 thumbprints"
    rlPhaseEnd

    rlPhaseStartTest "Make sure tang-show-keys uses SHA-256 thumbprints"
        # Remove any existing keys.
        rlRun "remove_keys /var/db/tang" 0 "Remove existing keys"

        rlRun "/usr/libexec/tangd-keygen /var/db/tang sig exc" 0 "Create new keys with specific names with tangd-keygen"
        rlRun "check_adv '${adv}'" 0 "Validate advertisement"
        rlRun "sigthp256=\$(jose jwk thp -a S256 -i /var/db/tang/sig.jwk)" 0 "Calculate SHA-256 thumbprint of signing key"
        rlRun -s "tang-show-keys" 0 "Run tang-show-keys"
        rlAssertGrep "${sigthp256}" "${rlRun_LOG}"
        rm -f "${rlRun_LOG}"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlServiceRestore tangd.socket"
        rlRun "rlFileRestore"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
