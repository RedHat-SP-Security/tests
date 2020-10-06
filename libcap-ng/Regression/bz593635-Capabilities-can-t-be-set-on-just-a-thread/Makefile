# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/libcap-ng/Sanity/bz593635-Capabilities-can-t-be-set-on-just-a-thread
#   Description: When changing capabilities on a thread, it actually changes the capabilities
#   Author: Eduard Benes <ebenes@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2010 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/libcap-ng/Regression/bz593635-Capabilities-can-t-be-set-on-just-a-thread
export TESTVERSION=1.0

BUILT_FILES=pthread-cap-test *.o

FILES=$(METADATA) runtest.sh Makefile PURPOSE pthread-cap-test.c

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build:
	test -x runtest.sh || chmod a+x runtest.sh

clean:
	rm -f *~ $(BUILT_FILES)

include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Eduard Benes <ebenes@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "Description:     When changing capabilities on a thread, it actually changes the capabilities" >> $(METADATA)
	@echo "Type:            Regression" >> $(METADATA)
	@echo "TestTime:        15m" >> $(METADATA)
	@echo "RunFor:          libcap-ng" >> $(METADATA)
	@echo "Requires:        libcap-ng libcap-ng-utils libcap-ng-devel gcc" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Bug:             593635" >> $(METADATA)
	@echo "Releases:        RHEL6" >> $(METADATA)

	rhts-lint $(METADATA)
