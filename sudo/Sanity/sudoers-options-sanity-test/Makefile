# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Makefile of /CoreOS/sudo/Sanity/sudoers-options-sanity-test
#   Description: This sanity test checks pre-defined (some are commented) options (examples) in sudoers file.
#   Author: Ales Marecek <amarecek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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

export TEST=/CoreOS/sudo/Sanity/sudoers-options-sanity-test
export TESTVERSION=1.0

BUILT_FILES=

FILES=$(METADATA) runtest.sh Makefile PURPOSE

.PHONY: all install download clean

run: $(FILES) build
	./runtest.sh

build: $(BUILT_FILES)
	test -x runtest.sh || chmod a+x runtest.sh

clean:
	rm -f *~ $(BUILT_FILES)


include /usr/share/rhts/lib/rhts-make.include

$(METADATA): Makefile
	@echo "Owner:           Ales Marecek <amarecek@redhat.com>" > $(METADATA)
	@echo "Name:            $(TEST)" >> $(METADATA)
	@echo "TestVersion:     $(TESTVERSION)" >> $(METADATA)
	@echo "Path:            $(TEST_DIR)" >> $(METADATA)
	@echo "RhtsRequires:    library(distribution/tcf)" >> $(METADATA)
	@echo "RhtsRequires:    library(distribution/Cleanup)" >> $(METADATA)
	@echo "RhtsRequires:    library(distribution/ConditionalPhases)" >> $(METADATA)
	@echo "RhtsRequires:    library(distribution/testUser)" >> $(METADATA)
	@echo "Description:     This sanity test checks pre-defined (some are commented) options (examples) in sudoers file." >> $(METADATA)
	@echo "Type:            Sanity" >> $(METADATA)
	@echo "TestTime:        30m" >> $(METADATA)
	@echo "RunFor:          sudo" >> $(METADATA)
	@echo "Requires:        sudo grep coreutils postfix /usr/bin/unbuffer" >> $(METADATA)
	@echo "Priority:        Normal" >> $(METADATA)
	@echo "License:         GPLv2" >> $(METADATA)
	@echo "Confidential:    no" >> $(METADATA)
	@echo "Destructive:     no" >> $(METADATA)
	@echo "Bug:             839705" >> $(METADATA)
	@echo "Bug:             1200253" >> $(METADATA)
	@echo "Bug:             1247230" >> $(METADATA)
	@echo "Bug:             1247231" >> $(METADATA)
	@echo "Bug:             1389735" >> $(METADATA)
	@echo "Bug:             1308789" >> $(METADATA)
	@echo "Bug:             1413160" >> $(METADATA)
	@echo "Bug:             1796518" >> $(METADATA)

	rhts-lint $(METADATA)
