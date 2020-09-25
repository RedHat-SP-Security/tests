#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = ConditionalPhases
#   library-version = 2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_ConditionalPhases_LIB_VERSION=2
__INTERNAL_ConditionalPhases_LIB_NAME='distribution/ConditionalPhases'
: <<'=cut'
=pod

=head1 NAME

BeakerLib library distribution/condpahses

=head1 DESCRIPTION

Implements conditional phases to eficiently select test phases to be execute
using white and black lists.

To use this functionality you need to import library
distribution/ConditionalPhases and add following line to Makefile.

	@echo "RhtsRequires:    library(distribution/ConditionalPhases)" >> $(METADATA)

=head1 USAGE

=head2 Conditional phases

Each test phase can be conditionally skipped based on a bash regular expression
given in CONDITIONAL_PHASES_BL and/or CONDITIONAL_PHASES_WL variables.

=over

=item CONDITIONAL_PHASES_BL

It is a black list. If match phase name the respective phase should be skipped.

=item CONDITIONAL_PHASES_WL

It is a white list. If does B<not> match phase name the respective phase should
be skipped excluding phases contatning 'setup' or 'cleanup' in its name. Names
'setup' and 'cleanup' are matched case insenitively.

=back

Actual skipping has to be done in the test case itself by using return code of
functions I<rlPhaseStart>, I<rlPhaseStartSetup>, I<rlPhaseStartTest>, and
I<rlPhaseStartCleanup>.

Example:

    rlPhaseStartTest "bz123456" && {
      ...
    rlPhaseEnd; }

Evaluation of the phase relevancy works as follows:
    1. If CONDITIONAL_PHASES_BL is non-empty and matches phase name => return 2.
    2. If phase name contains word 'setup' or 'cleanup' or CONDITIONAL_PHASES_WL
       is empty => return 0.
    3. If CONDITIONAL_PHASES_WL is non-empty and matches phase name => return 0
       otherwise return 1.

Normaly Setup and Cleanup phases are not skipped unless hey are B<explicitly>
black-listed.

To make the test work properly with conditional phases it is necessary to
surround phase code with curly brackets and make it conditionally executed
based on rlPhaseStart* function's exit code the same way as it is demostrated in
the example above. To make the process easy you can use following command:

    sed 's/rlPhaseStart[^{]*$/& \&\& {/;s/rlPhaseEnd[^}]*$/&; }/'

This code can be embedded in Makefile by modifying build target to following
form:

    build: $(BUILT_FILES)
    	grep -Eq 'rlPhase(Start[^{]*|End[^}]*)$' runtest.sh && sed -i 's/rlPhaseStart[^{]*$/& \&\& {/;s/rlPhaseEnd[^}]*$/&; }/' testrun.sh
    	test -x runtest.sh || chmod a+x runtest.sh


=cut
#'
echo -n "loading library $__INTERNAL_ConditionalPhases_LIB_NAME v$__INTERNAL_ConditionalPhases_LIB_VERSION... "


# ConditionalPhasesLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
ConditionalPhasesLibraryLoaded() {
  if [[ -n "$CONDITIONAL_PHASES_BL" || -n "$CONDITIONAL_PHASES_WL" ]]; then
    __INTERNAL_ConditionalPhases_eval() {
      # check phases black-list
      [[ -n "$CONDITIONAL_PHASES_BL" && "$1" =~ $CONDITIONAL_PHASES_BL ]] && {
        rlLogWarning "phase '$1' should be skipped as it is defined in \$CONDITIONAL_PHASES_BL='$CONDITIONAL_PHASES_BL'"
        return 2
      }
      # always execute Setup, Cleanup and if no PHASES (white-list) specified
      [[ "$1" =~ $(echo "\<[Ss][Ee][Tt][Uu][Pp]\>") || "$1" =~ $(echo "\<[Cc][Ll][Ee][Aa][Nn][Uu][Pp]\>") ]] && {
        rlLogInfo "phase '$1' will be executed as 'setup' and 'cleanup' phases are allowed by default, these can be black-listed"
        return 0
      }
      [[ -z "$CONDITIONAL_PHASES_WL" ]] && {
        rlLogInfo "phase '$1' will be executed as there is no rule for it"
        return 0
      }
      [[ "$1" =~ $CONDITIONAL_PHASES_WL ]] && {
        rlLogInfo "phase '$1' will be executed as it is defined in \$CONDITIONAL_PHASES_WL='$CONDITIONAL_PHASES_WL'"
        return 0
      } || {
        rlLogWarning "phase '$1' should be skipped as it is not defined in \$CONDITIONAL_PHASES_WL='$CONDITIONAL_PHASES_WL'"
        return 1
      }
    }

    rlLogInfo "replacing rlPhaseStart by modified function with conditional phases implemented"
    :; rlPhaseStart() {
        if [ "x$1" = "xFAIL" -o "x$1" = "xWARN" ] ; then
            __INTERNAL_ConditionalPhases_eval "$2" && \
            rljAddPhase "$1" "$2"
            return $?
        else
            rlLogError "rlPhaseStart: Unknown phase type: $1"
            return 1
        fi
    }
  else
    rlLogInfo "Neither CONDITIONAL_PHASES_WL nor CONDITIONAL_PHASES_BL is defined, not applying modifications"
  fi
}; # end of ConditionalPhasesLibraryLoaded }}}


: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

echo 'done.'
