package XING::Admin::RepoMate::Cli;

use Moose;
with qw(MooseX::Getopt XING::Admin::RepoMate::Roles::Config);
use vars qw($VERSION);
use XING::Admin::RepoMate;

our $VERSION = '0.01000';


has '_repomate' => (
    accessor => 'repomate',
    default  => sub {
        return XING::Admin::RepoMate->new();
    },
    is  => 'rw',
    isa => 'XING::Admin::RepoMate',
);

sub start {
	my ($self) = @_;
	
	$self->repomate->dumpcfg
}

__PACKAGE__->meta->make_immutable;
