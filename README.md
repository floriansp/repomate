# RepoMate

Tool to manage debian repositories.

## This project is really new and not completely tested. Use it at your own risk.


## The idea

The idea was to create a small, leightweight and easy to use debian repository management tool that provides a staging area for jenkins package builds using fpm-cookery, basic gpg support and some custom features.

Every destructive action can be reverted.

It's roughly not finished yet!

### Package lifecycle

As mentioned before, RepoMate has a staging area. Every package you are trying to add through the commandline interface will be copied to the staging area. This action will not affect your production pool.
You have to publish a package or a set of packages to bring them into production. When you do, the selected packages will be moved from "stage" to "pool" (This is like an archive) and linked from the "pool" to "dists".
Note that "dists"" normally contains just all the metafiles like Packages or Packages.gz.
We like to have all what apt needs in just one directory.

newpackage -> (add) -> stage -> (publish) -> production


## Features

### Checkpoints

Checkpoints may help if you accidently published a bunch of packages to the wrong suite (lenny, squeeze,…) or component (main, contrib, non-free,…).

If you did:

    sbin/repomate load

Choose the last checkpoint and be happy again.

Note that checkpoints will be auto-saved before each publish sequence.

## Installation

### Repository server

dpkg is used to compare package versions. I tried to do it on my own, but debian uses very annoying version strings with a couple of variants.

Please make sure you have the following packages installed:

* ruby
* dpkg
* libsqlite3-dev

#### Get RepoMate
    
    cd /opt
    git clone git@github.com:floriansp/repomate.git
    
    gem install bundler
    bundle install
    
#### Configure RepoMate

GPG ist enabled by default. If you don't want it, just set the value of gpg_enable to "no" otherwise generate a gpg key and add the needed values to the configfile.

Create the config file if you don't want the default configuration.
    
    vi ~/.repomate.yml
    
Sample config:
       
    ---
    :rootdir: /var/lib/repomate/repository
    :logdir: /var/log/repomate
    :redolog: redo.log
    :database: repomate.db
    :dpkg: /usr/bin/dpkg
    :suites:
        - lenny
        - squeeze
    :components:
        - main
        - contrib
    :architectures:
        - all
        - amd64
    :origin: Repository
    :label: Repository
    :gpg_enable: yes
    :gpg_email: someone@example.net
    :gpg_password: secret
 
    
#### Configure webserver

Configure your favorite webserver by adding RepoMate's rootdirectory to a site or vhost.

#### Adding packages

    sbin/repomate add -s squeeze package.deb
    sbin/repomate publish


### Client

Add something like this to your machines /etc/apt/sources.list:
    
    deb [arch=all,amd64] http://server/repository squeeze main    
    

### Examples

Setup base directory structure (optional):

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
