# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/rsyslog/Regression/bz740420-Add-a-etc-rsyslog-d-config-directory
#   Description: Test for bz740420 (Add a /etc/rsyslog.d config directory)
#   Author: Dalibor Pospisil <dapospis@dapospis.redhat>
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

export TEST=/CoreOS/rsyslog/Regression/bz740420-Add-a-etc-rsyslog-d-config-directory
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	test -x runtest.sh || chmod a+x runtest.sh
	@if [ -e /usr/share/beakerlib/plugins/try-check-final.sh ]; then \
	  /usr/share/beakerlib/plugins/try-check-final.sh verify_plugin; \
	elif [ -e /mnt/tests/CoreOS/beaker/plugin-tcf/try-check-final.sh ]; then \
	  /mnt/tests/CoreOS/beaker/plugin-tcf/try-check-final.sh verify_plugin; \
	elif [ -e /mnt/qa/scratch/dapospis/try-check-final.sh ]; then \
	  /mnt/qa/scratch/dapospis/try-check-final.sh verify_plugin; \
	fi;

clean:
	rm -f *~ $(BUILT_FILES)


include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Dalibor Pospisil <dapospis@dapospis.redhat>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     Test for bz740420 (Add a /etc/rsyslog.d config directory)" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        5m" >> $(METADATA)
	@echo "RunFor:          rsyslog" >> $(METADATA)
	@echo "Requires:        rsyslog" >> $(METADATA)
	@echo "RhtsRequires:    library(rsyslog/basic)" >> $(METADATA)
	@echo "RhtsRequires:    test(/CoreOS/beaker/plugin-tcf)" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Bug:             740420" >> $(METADATA)

	rhts-lint $(METADATA)
