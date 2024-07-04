# Establish default values for critical variables.  Any of these may be overridden
# on the command line or via the make environment configuration in an IDE
O ?= build
ARCH1 ?= native/default_cpu1
ARCH2 ?= native/default_cpu2
BUILDTYPE ?= debug
INSTALLPREFIX ?= /exe
DESTDIR ?= $(O)

# The "DESTDIR" variable is a bit more complicated because it should be an absolute
# path for CMake, but we want to accept either absolute or relative paths.  So if
# the path does NOT start with "/", prepend it with the current directory.
ifeq ($(filter /%, $(DESTDIR)),)
DESTDIR := $(CURDIR)/$(DESTDIR)
endif

# The "LOCALTGTS" defines the top-level targets that are implemented in this makefile
# Any other target may also be given, in that case it will simply be passed through.
LOCALTGTS := doc usersguide osalguide prep all clean install distclean test lcov cpu1 cpu2
OTHERTGTS := $(filter-out $(LOCALTGTS),$(MAKECMDGOALS))

# As this makefile does not build any real files, treat everything as a PHONY target
# This ensures that the rule gets executed even if a file by that name does exist
.PHONY: $(LOCALTGTS) $(OTHERTGTS)

# If the target name appears to be a directory (ends in /), do a make all in that directory
DIRTGTS := $(filter %/,$(OTHERTGTS))
ifneq ($(DIRTGTS),)
$(DIRTGTS):
	$(MAKE) -C $(O)/$(patsubst $(O)/%,%,$(@)) all
endif

# For any other goal that is not one of the known local targets, pass it to the arch build
# as there might be a target by that name.  For example, this is useful for rebuilding
# single unit test executable files while debugging from the IDE
FILETGTS := $(filter-out $(DIRTGTS),$(OTHERTGTS))
ifneq ($(FILETGTS),)
$(FILETGTS):
	$(MAKE) -C $(O)/$(ARCH1) $(@)
	$(MAKE) -C $(O)/$(ARCH2) $(@)
endif

# The "prep" step requires extra options that are specified via environment variables.
# Certain special ones should be passed via cache (-D) options to CMake.
# These are only needed for the "prep" target but they are computed globally anyway.
PREP_OPTS :=

ifneq ($(INSTALLPREFIX),)
PREP_OPTS += -DCMAKE_INSTALL_PREFIX=$(INSTALLPREFIX)
endif

ifneq ($(VERBOSE),)
PREP_OPTS += --trace
endif

ifneq ($(BUILDTYPE),)
PREP_OPTS += -DCMAKE_BUILD_TYPE=$(BUILDTYPE)
endif

all: cpu1 cpu2

cpu1:
	$(MAKE) --no-print-directory -C "$(O)/cpu1" mission-all

cpu2:
	$(MAKE) --no-print-directory -C "$(O)/cpu2" mission-all

install:
	$(MAKE) --no-print-directory -C "$(O)/cpu1" DESTDIR="$(DESTDIR)" mission-install
	$(MAKE) --no-print-directory -C "$(O)/cpu2" DESTDIR="$(DESTDIR)" mission-install

prep $(O)/cpu1/.prep $(O)/cpu2/.prep:
	mkdir -p "$(O)/cpu1"
	(cd "$(O)/cpu1" && cmake $(PREP_OPTS) "$(CURDIR)/cfe")
	echo "$(PREP_OPTS)" > "$(O)/cpu1/.prep"

	mkdir -p "$(O)/cpu2"
	(cd "$(O)/cpu2" && cmake $(PREP_OPTS) "$(CURDIR)/cfe")
	echo "$(PREP_OPTS)" > "$(O)/cpu2/.prep"

clean:
	$(MAKE) --no-print-directory -C "$(O)/cpu1" mission-clean
	$(MAKE) --no-print-directory -C "$(O)/cpu2" mission-clean

distclean:
	rm -rf "$(O)"

# Grab lcov baseline before running tests
test:
	lcov --capture --initial --directory $(O)/$(ARCH1) --output-file $(O)/$(ARCH1)/coverage_base.info
	(cd $(O)/$(ARCH1) && ctest -O ctest.log)
	lcov --capture --initial --directory $(O)/$(ARCH2) --output-file $(O)/$(ARCH2)/coverage_base.info
	(cd $(O)/$(ARCH2) && ctest -O ctest.log)

lcov:
	lcov --capture --rc lcov_branch_coverage=1 --directory $(O)/$(ARCH1) --output-file $(O)/$(ARCH1)/coverage_test.info
	lcov --rc lcov_branch_coverage=1 --add-tracefile $(O)/$(ARCH1)/coverage_base.info --add-tracefile $(O)/$(ARCH1)/coverage_test.info --output-file $(O)/$(ARCH1)/coverage_total.info
	genhtml $(O)/$(ARCH1)/coverage_total.info --branch-coverage --output-directory $(O)/$(ARCH1)/lcov
	@/bin/echo -e "\n\nCoverage Report Link: file:$(CURDIR)/$(O)/$(ARCH1)/lcov/index.html\n"
	lcov --capture --rc lcov_branch_coverage=1 --directory $(O)/$(ARCH2) --output-file $(O)/$(ARCH2)/coverage_test.info
	lcov --rc lcov_branch_coverage=1 --add-tracefile $(O)/$(ARCH2)/coverage_base.info --add-tracefile $(O)/$(ARCH2)/coverage_test.info --output-file $(O)/$(ARCH2)/coverage_total.info
	genhtml $(O)/$(ARCH2)/coverage_total.info --branch-coverage --output-directory $(O)/$(ARCH2)/lcov
	@/bin/echo -e "\n\nCoverage Report Link: file:$(CURDIR)/$(O)/$(ARCH2)/lcov/index.html\n"

doc:
	$(MAKE) --no-print-directory -C "$(O)/cpu1" mission-doc
	$(MAKE) --no-print-directory -C "$(O)/cpu2" mission-doc

usersguide:
	$(MAKE) --no-print-directory -C "$(O)/cpu1" cfe-usersguide
	$(MAKE) --no-print-directory -C "$(O)/cpu2" cfe-usersguide

osalguide:
	$(MAKE) --no-print-directory -C "$(O)/cpu1" osal-apiguide
	$(MAKE) --no-print-directory -C "$(O)/cpu2" osal-apiguide

# Make all the commands that use the build tree depend on a flag file
# that is used to indicate the prep step has been done.  This way
# the prep step does not need to be done explicitly by the user
# as long as the default options are sufficient.
$(filter-out prep distclean,$(LOCALTGTS)): $(O)/cpu1/.prep $(O)/cpu2/.prep
