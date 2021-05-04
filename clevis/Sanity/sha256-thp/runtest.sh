#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/clevis/Sanity/sha256-thp
#   Description: Test clevis SHA-256 thumbprints
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

PACKAGE="clevis"
PACKAGES="${PACKAGE} tang curl"

# tang keys.
SIG='{"alg":"ES512","crv":"P-521","d":"Aa2_sR5XAmf_SaFCg6kJgkOgdPOGXvdy_rXCUqHd01aZ5RlW_rwzh4xNt71JhXtuO7BQwlx_JVUczoFXobugqIpv","key_ops":["sign","verify"],"kty":"EC","x":"AEU3OcVAfeQVEVM80MovUudwAljCHO52ZHusEWq8nKrpQKd83TycQDDH8thISstAXHCYmIKZE0DJAO1apLtZcRpd","y":"API8fwZBkBfv-FvPtMxBPbULzqRLZ2ye1V9YNHDv3gPMfpwUove8EEuv4L79qnc6NToBYl06wc6naKzYqdrcXfhy"}'
EXC='{"alg":"ECMR","crv":"P-521","d":"AWig71T4HCF8JtLAZ-SnKRyNRIxYt1M46pWH0UI5pihNo5hGWcwHaQQzSk-bqt56V54Xje6RkFB4z59SrRjuPhzG","key_ops":["deriveKey"],"kty":"EC","x":"AIYLTegtjecxcRJvO6ioezGF7jk98Qlgkfi51v9lmpIVq9Ygsul2KbypMunVRSGb9klWgTHud26AJBlOe0eZuXjf","y":"AJRF9klU9e1igr8dKOutsJp59XJ4KjFbcQSfe-iZ2ssRd50iBmTS03QYMtj8j9_xmWGrmwbB-VrVp3D2LPJS5cJk"}'
# Thumbprints.
EXC_S1_THP='wZ5D32uwhSHD6m5LNIWM-GQewjk'
EXC_S256_THP='0LFRNkTacm21MIrTi1wglICY4vi0e3w1mx7rnDG9S9Q'
SIG_S1_THP='YQo5v40etPZe-_VCLJukAYyRfcc'
SIG_S256_THP='Gd4a29y8FIqgcgRWpG2w6d0CacnV46jxhXVXR5Q116E'

# Encrypted data.
DATA='Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed eget diam fringilla, laoreet neque nec, pellentesque felis. Integer vitae molestie enim. Maecenas cursus in urna eget molestie. Vivamus vitae mattis massa. Nunc fermentum turpis quis neque facilisis tincidunt. Interdum et malesuada fames ac ante ipsum primis in faucibus. Sed ut diam lectus. Cras cursus ac dolor sit amet maximus. Phasellus sed nisl eget purus egestas ornare quis dictum mauris. Nulla eleifend semper mauris in finibus. Nam nec nibh at nisl tempus mollis. Suspendisse turpis nisi, dignissim quis ornare nec, viverra eget erat. Proin in mi vitae velit pretium faucibus. Aliquam a gravida mi, in tristique nunc. Nunc vel lorem eu justo blandit scelerisque.'
ENC_DATA='eyJhbGciOiJFQ0RILUVTIiwiY2xldmlzIjp7InBpbiI6InRhbmciLCJ0YW5nIjp7ImFkdiI6eyJrZXlzIjpbeyJhbGciOiJFQ01SIiwiY3J2IjoiUC01MjEiLCJrZXlfb3BzIjpbImRlcml2ZUtleSJdLCJrdHkiOiJFQyIsIngiOiJBSVlMVGVndGplY3hjUkp2TzZpb2V6R0Y3ams5OFFsZ2tmaTUxdjlsbXBJVnE5WWdzdWwyS2J5cE11blZSU0diOWtsV2dUSHVkMjZBSkJsT2UwZVp1WGpmIiwieSI6IkFKUkY5a2xVOWUxaWdyOGRLT3V0c0pwNTlYSjRLakZiY1FTZmUtaVoyc3NSZDUwaUJtVFMwM1FZTXRqOGo5X3htV0dybXdiQi1WclZwM0QyTFBKUzVjSmsifSx7ImFsZyI6IkVTNTEyIiwiY3J2IjoiUC01MjEiLCJrZXlfb3BzIjpbInZlcmlmeSJdLCJrdHkiOiJFQyIsIngiOiJBRVUzT2NWQWZlUVZFVk04ME1vdlV1ZHdBbGpDSE81MlpIdXNFV3E4bktycFFLZDgzVHljUURESDh0aElTc3RBWEhDWW1JS1pFMERKQU8xYXBMdFpjUnBkIiwieSI6IkFQSThmd1pCa0Jmdi1GdlB0TXhCUGJVTHpxUkxaMnllMVY5WU5IRHYzZ1BNZnB3VW92ZThFRXV2NEw3OXFuYzZOVG9CWWwwNndjNm5hS3pZcWRyY1hmaHkifV19LCJ1cmwiOiJsb2NhbGhvc3QifX0sImVuYyI6IkEyNTZHQ00iLCJlcGsiOnsiY3J2IjoiUC01MjEiLCJrdHkiOiJFQyIsIngiOiJBQWNPVk9WZ09DOGhVRVBWWktPTDVxeG56emlVc0E0alllOHgxVEVicnpSVk1hekYtTWJILS1CVjNuU3FGS2xjQ2pubzB0SjZkQlg3UUFwVTkwM1M1eHpfIiwieSI6IkFZT2NPWUl4NkhreTROMXgxM3F6SmluMklLU3p5OWZzdEtCN3hnNHF3UEtTLXRWd3R3YlE5T2MyMWhNRnh6MG44dUJCVFpJOElRQ3BOUzFiYkx0bFllUFIifSwia2lkIjoid1o1RDMydXdoU0hENm01TE5JV00tR1Fld2prIn0..vqalGdr7uSrFmUT3.rnkOhUZoywjnKTA_46T80RSllVmkd5ETT7spu2gbdSO42qcJICa4-RU78v5thkYfNBIipchN-5ncZU3UptBEqSjEZ1cN3O8w4GxHkFbgReGaUBHhht6d6KaZGwsWYARGTiGaK8vlnbJijZOi7VfvyS7yq0a67wkn_GE7V78MhXmh3HZBNkc9_mNs1_NUsAFZRBrKv4iQDZTtub9QiBWiReMYk0fEB4qnhR8Yi_v-Qes_sdmJOtWbqS2Elm1arUoHY257mcv6vdX3dhoFsnxlhc10UGIQ_Wjdc-DCxsFzWTVN5TiGqMRAtDpJsqEybNcWk0sQ8LdVex6u4V3FN6QQrb3ch_B91KI90jdQc_ZzyfYGQ0Ku2EvFd00nulQuIaHkkmMIRilUskrIVNQED2ALC87BA3iALRAoohIjs6pyuAxREEk_WK6l6aMKOwAf3kq9r6vrJ9eyl6KeObroam40PQHh7wb1N4VrUoJGwUHp1r8QZR6M4QtkJPxJYzTca-l4URoe9_SkKZING_8vpYooV7e-7vZzsgf2bbcsA-UzvXOppvsBaRolsgzvlIbKvm0_dOzbPf6dKNiAh058BuZagLAo0JdsZVwgk7Z0O2IBJ5PcDrh4xLCj45plTGZWadvLXUPU-_2jWx8EDA0E0dOpwq-8uwujQPewJ91oCOy8FrPfdC9gcCmGSDgHDdpIGCq7RIm5EcbZKWPEUlvXRAiuM8RvmG1gqujgDE_ca0PCoPaslP-oqSAHf0VB02a-egMSF_P1hLq_ZQli6eCoWCqr8wIKXPyin_Q7qFgVPA0iqO6xvdaYuElGS6pwb-R3tvNA7BROCKhkhymX_Gp-U5u7d16V6Ja6x1f6WothrWj7YANRan-aEpPAYKiW7IS0xcYFe0UJ01PHGS0PEBQR_mlxNj5zu3qDpYU4ExaE0aXujM3ENU9Bz0IczXSRf41GLHI6Gd1UWC31WZ8dFwVG.86AAIKBjWuzgLpYQlynwWg'

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all || rlDie "cannot continue"

        # Check if we have the expected minimum version.
        rlRun "packageVersion=$(rpm -q ${PACKAGE} --qf '%{name}-%{version}-%{release}\n')"
        rlTestVersion "${packageVersion}" '>=' 'clevis-18-1' \
            || rlDie "Tested functionality is not in old version ${packageVersion}. Minimum expected version is clevis-18"

        # Backup any possibly existing keys then remove them.
        rlRun "rlFileBackup --clean /var/db/tang/"
        rlRun "rm -f /var/db/tang/*.jwk"
        rlRun "rm -f /var/db/tang/.*.jwk"

        # Add the test keys.
        rlRun "echo '${SIG}' > /var/db/tang/sig.jwk"
        rlRun "echo '${EXC}' > /var/db/tang/exc.jwk"

        rlRun "rlServiceStart tangd.socket"
    rlPhaseEnd

    rlPhaseStartTest "Make sure encrypt-ed data uses SHA-1 thumbprints"
        rlRun "hdr64=\$(echo "${ENC_DATA}" | cut -d'.' -f1)"
        rlRun "hdr=\$(echo "${hdr64}" | jose b64 dec --base64=-)"

        rlRun "kid=\$(jose fmt --json='${hdr}' --object --get kid --string --unquote=-)"
        rlAssertEquals "Check that kid matches exc SHA-1 thumbprint" "${kid}" "${EXC_S1_THP}"
    rlPhaseEnd

    rlPhaseStartTest "Make sure that we can decrypt data encoded with SHA-1 thumbprints"
        rlRun "decoded=\$(printf '%s' '${ENC_DATA}' | clevis decrypt)"
        rlAssertEquals "Check that decoded data matches" "${decoded}" "${DATA}"
    rlPhaseEnd

    rlPhaseStartTest "Make sure we can use both SHA-1 and SHA-256 thumbprints to encode data"
        cfg1=$(printf '{"url":"localhost","thp":"%s"}' "${SIG_S1_THP}")
        cfg256=$(printf '{"url":"localhost","thp":"%s"}' "${SIG_S256_THP}")
        for cfg in "${cfg1}" "${cfg256}"; do
            rlRun "enc=\$(printf '%s' '${DATA}' | clevis encrypt tang '${cfg}')"
            rlRun "dec=\$(printf '%s' '${enc}' | clevis decrypt)"
            rlAssertEquals "Check that decoded data matches" "${dec}" "${DATA}"
            break
        done
    rlPhaseEnd

    rlPhaseStartTest "Make sure newly encoded data uses SHA-256 thumbprints"
        cfg256=$(printf '{"url":"localhost","thp":"%s"}' "${SIG_S256_THP}")
        rlRun "enc=\$(printf '%s' '${DATA}' | clevis encrypt tang '${cfg256}')"
        rlRun "hdr64=\$(echo "${enc}" | cut -d'.' -f1)"
        rlRun "hdr=\$(echo "${hdr64}" | jose b64 dec --base64=-)"
        rlRun "kid=\$(jose fmt --json='${hdr}' --object --get kid --string --unquote=-)"
        rlAssertEquals "Check that kid matches exc SHA-256 thumbprint" "${kid}" "${EXC_S256_THP}"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlServiceRestore tangd.socket"
        rlRun "rlFileRestore"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
