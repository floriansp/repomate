# RepoMate

Tool to manage debian repositories

### Examples

Add a package to the staging area

    repomate -A /tmp/dsyslog_0.6.0+b1_amd64.deb -d squeeze

Rublish all packages from the staging area. That means they will be linked to production

    repomate -P
    
Load a checkpoint

    repomate -L

Save a checkpoint

    repomate -S
    
List all packages in squeeze

    repomate -l -d squeeze
    
or list all

    repomate -l



    

