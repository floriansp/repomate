package XING::Admin::RepoMate::Cli;

use Moose;
with qw(MooseX::Getopt XING::Admin::RepoMate::Roles::Config);
use vars qw($VERSION);
use XING::Admin::RepoMate;
use Data::Dumper;

our $VERSION = '0.01000';

has '_repomate' => (
    accessor => 'repomate',
    default  => sub {
        return XING::Admin::RepoMate->new();
    },
    is  => 'rw',
    isa => 'XING::Admin::RepoMate',
);

has 'pool' => (
    cmd_flag      => 'pool',
    documentation => 'Define the pool',
    is            => 'rw',
    isa           => 'Str',
    traits        => [qw(Getopt)],
);

has 'addpool' => (
    cmd_flag      => 'addpool',
    documentation => 'Add a pool e.g. etch, lenny, stable',
    is            => 'rw',
    isa           => 'Str',
    traits        => [qw(Getopt)],
);

has 'delpool' => (
    cmd_flag      => 'delpool',
    documentation => 'Delete a pool e.g. etch, lenny, stable',
    is            => 'rw',
    isa           => 'Str',
    traits        => [qw(Getopt)],
);

has 'listpools' => (
    cmd_flag      => 'listpools',
    documentation => 'List all pools directories',
    is            => 'rw',
    isa           => 'Bool',
    traits        => [qw(Getopt)],
);

has 'addpackage' => (
    cmd_flag      => 'addpackage',
    documentation => 'Add a package to a pool',
    is            => 'rw',
    isa           => 'Str',
    traits        => [qw(Getopt)],
);

sub start {
    my ($self) = @_;

    $self->repomate->setup_base;

    if ( $self->addpackage && !$self->pool) {
        print "You need to specify a pool for adding a package\n";
        exit 1;
    }

    #$self->repomate->add_package( $self->addpackage )

    $self->repomate->list_pools if $self->listpools;
    $self->repomate->add_pool( $self->addpool ) if $self->addpool;

    $self->repomate->del_pool( $self->delpool ) if $self->delpool;

}

__PACKAGE__->meta->make_immutable;
