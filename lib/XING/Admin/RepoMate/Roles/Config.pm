package XING::Admin::RepoMate::Roles::Config;

use Moose::Role;
use Config::JFDI;
use FindBin;

has '_config' => (
    accessor => 'config',
    default  => sub {
        return Config::JFDI->new(
            name              => "repomate",
            path              => "$FindBin::Bin/../etc/",
            quiet_deprecation => 1,
        )->get;
    },
    is   => 'rw',
    isa  => 'HashRef',
    lazy => 1,
);

1;
