Installer
=========

Install/remove tools and their dependencies:

| TOOL                   | VERSION | URL                                           |
|------------------------|---------|-----------------------------------------------|
| abi-tracker            | 1.11    | https://github.com/lvc/abi-tracker            |
| abi-monitor            | 1.12    | https://github.com/lvc/abi-monitor            |
| abi-dumper             | 1.1     | https://github.com/lvc/abi-dumper             |
| abi-compliance-checker | 2.2     | https://github.com/lvc/abi-compliance-checker |
| pkgdiff                | 1.7.2   | https://github.com/lvc/pkgdiff                |
| vtable-dumper          | 1.2     | https://github.com/lvc/vtable-dumper          |

Requires
--------

* Perl 5
* curl

Usage
-----

    make install   prefix=PREFIX target=TOOL
    make uninstall prefix=PREFIX target=TOOL

###### Example

    make install   prefix=/usr target=abi-tracker
    make uninstall prefix=/usr target=abi-tracker
