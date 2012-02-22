package XING::Admin::RepoMate;

use Moose;
with qw(XING::Admin::RepoMate::Roles::Config);
use vars qw($VERSION);
use File::Path qw(make_path remove_tree);
use Data::Dumper;

our $VERSION = '0.01000';

has 'directories' => (
    auto_deref => 1,
    is         => 'ro',
    isa        => 'ArrayRef[Str]',
    builder    => 'b_directories'
);

sub b_directories {
    my ($self) = @_;

    my @dirs     = ();
    my @subdirs  = qw(archive pool dists);
    my $basepath = $self->config->{'global'}{'basepath'};

    foreach my $subdir (@subdirs) {
        push( @dirs, $basepath . "/" . $subdir );
    }

    return \@dirs;
}

sub setup_dirs {
    my ($self) = @_;

    foreach my $dir ( @{ $self->directories } ) {
        make_path(
            "$dir",
            {
                verbose => 1,
                mode    => 0755,
            }
        );
    }
}

__PACKAGE__->meta->make_immutable;
