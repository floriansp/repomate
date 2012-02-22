package XING::Admin::RepoMate;

use Moose;
with qw(MooseX::Getopt XING::Admin::RepoMate::Roles::Config);
use vars qw($VERSION);
use Data::Dumper;

our $VERSION = '0.01000';

sub dumpcfg {
    my ($self) = @_;

    warn Dumper $self->config;
}

__PACKAGE__->meta->make_immutable;
