package XING::Admin::RepoMate;

use Moose;
with qw(XING::Admin::RepoMate::Roles::Config);
use vars qw($VERSION);
use File::Path qw(make_path remove_tree);
use File::Find::Rule;
use Data::Dumper;

our $VERSION = '0.01000';

has 'pools' => (
    auto_deref => 1,
    is         => 'ro',
    isa        => 'HashRef[Str]',
    builder    => 'read_pools'
);

sub read_pools {
    my ($self) = @_;

    my $pooldir = $self->config->{'global'}{'basepath'} . "/pool/";
    my %pools   = ();
    my @dirs =
      File::Find::Rule->maxdepth(1)->mindepth(1)->directory->in($pooldir);

    foreach my $dir (@dirs) {
        my ($poolname) = $dir =~ /.*\/(.*)$/;
        $pools{$poolname} = $dir;
    }

    return \%pools;
}

sub list_pools {
    my ($self) = @_;

    my %pools = %{ $self->pools };

    foreach my $poolname ( keys %pools ) {
        print "Name: $poolname, Path: $pools{$poolname}\n";
    }
}

sub add_pool {
    my ( $self, $poolname ) = @_;

    my $pooldir = $self->config->{'global'}{'basepath'} . "/pool/" . $poolname;

    die "Pool already exists!" if ( -d $pooldir );

    $pooldir = [$pooldir] unless ref $pooldir eq 'ARRAY';

    $self->makedir($pooldir);
}

sub del_pool {
    my ( $self, $poolname ) = @_;

    my %pools   = %{ $self->pools };
    my $pooldir = $pools{$poolname};

    die "Pool does not exist!" unless $pooldir;
    die "Pool is not empty" if $self->checkdir($pooldir) != 0;
    $pooldir = [$pooldir] unless ref $pooldir eq 'ARRAY';

    $self->removedir($pooldir);
}

sub setup_base {
    my ($self) = @_;

    my @dirs     = ();
    my @subdirs  = qw(archive pool dists);
    my $basepath = $self->config->{'global'}{'basepath'};

    foreach my $subdir (@subdirs) {
        push( @dirs, $basepath . "/" . $subdir );
    }

    $self->makedir( \@dirs );
}

sub checkdir {
    my ( $self, $dir ) = @_;

    my @files = <$dir/*>;
    my $size = $#files + 1;

    warn Dumper $size;
}

sub makedir {
    my ( $self, $dirs ) = @_;

    foreach my $dir ( @{$dirs} ) {
        make_path(
            "$dir",
            {
                verbose => 1,
                mode    => 0755,
            }
        );
    }
}

sub removedir {
    my ( $self, $dirs ) = @_;
    foreach my $dir ( @{$dirs} ) {
        remove_tree( "$dir", { verbose => 1, } );
    }
}

__PACKAGE__->meta->make_immutable;
