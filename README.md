# RepoMate

Tool to manage debian repositories

## Installation

    cd /opt
    git clone git@github.com:floriansp/repomate.git

### Examples

Setup base directory structure:

    repomate setup -s squeeze [ -c main ]

Add a package to the staging area:

    repomate add -s squeeze <path_to_packagefile>

Publish all packages from the staging area. That means they will be linked to production:

    repomate publish

Load a checkpoint:

    repomate load

Save a checkpoint:

    repomate save

List all packages in pool:

    repomate listpackages -r pool

List all packages in stage:

    repomate listpackages -r stage
