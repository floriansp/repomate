# RepoMate

Tool to manage debian repositories

### Examples

Setup base directory structure

    repomate --setup -s squeeze [ -c main ]

Add a package to the staging area

    repomate -A package.deb -s squeeze

Rublish all packages from the staging area. That means they will be linked to production

    repomate -P
    
Load a checkpoint

    repomate -L

Save a checkpoint

    repomate -S
    
List all packages in pool

    repomate -l -r pool

    



    

