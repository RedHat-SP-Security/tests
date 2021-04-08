# Special Project Upstream Testing Repository

## componnets
* aide
* clevis
* fapolicyd
* jose
* libcap-ng
* luksmeta
* rsyslog
* sudo
* tang
* usbguard

This testsuite is supposed to be executed and maintained via Test Managament Tool (tmt).
The data are structured in flexible metadata format (fmf).

See:
* https://github.com/psss/tmt
* https://github.com/psss/fmf

## Commit / merge policy

Every important change to tests should undergo a review within a pull request.

### changes without a need of review
Small, trivialy changes may be committed directly the master branch.
As a typical trivial change one may considere a metadata update (updated tags, adjust, ..)
or typo fixes, updated to comments and formating changes.

### changes with a need of review
#### existing tests
All changes to the test logic (changes of expected output, expected exit codes) need to be reviewd.

#### new tests
It is recommended to push new tests via PR with review as well as a check for covering all the agreed acceptance criteria is more than welcome.

#### reviewer selection
The review can be done by any member of the team. However, it is recommended to ask the devel counterpart as they could judge the test expectations according to the actualy code change. Asking another QE person, on the other hand, will ansure to keep the test coding style as consistent as possible.

#### PR merge
The marge it self should be done based on the accepted reviews. It is recommended to let the original requestor to merge the PR as they may want to do some refinements, e.g. quash some commits which were added during the review process.

It is also important to make sure that the _Nitrate_ references are resynced (`tmt tests export --nitrate .`) to update the reflect the change form the previous location (branch) to the final one.
