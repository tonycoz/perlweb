package Combust::StaticFiles;
use strict;
use base qw(Class::Accessor::Class);
use List::Util qw(first max);
use JSON qw(2.0 from_json);
use Carp qw(cluck);
use Combust::Config;

use Rose::Object::MixIn();
our @ISA = qw(Rose::Object::MixIn);
__PACKAGE__->export_tag(all => [ qw(find_static_path setup_static_files static_url static_base) ]);

my $config = Combust::Config->new;

my $startup_time = time;

my $static_file_paths = {}; 


unless ($Combust::StaticFiles::setup) {
    my @sites = $config->sites_list;
    for my $site (@sites) {
        __PACKAGE__->setup_static_files($site);
    }
}

sub find_static_path {
    my ($class, $site) = @_;
    my $root_dir = $config->root_docs;

    my @static_dirs = ($root_dir . "/$site/static",
                       $root_dir . "/static",
                      );
    return first { -e $_ && -d _ } @static_dirs;
}

sub setup_static_files {
    my ($class, $site) = @_;

    my $static_directory = $class->find_static_path($site);
    return unless $static_directory;

    $static_file_paths->{$site}->{path} = $static_directory;

    my $static_files = 
        eval { retrieve("${static_directory}/.static.versions.store") }
        || eval { 
            local $/ = undef;
            my $file = "${static_directory}/.static.versions.json";
            open my $fh, $file or die "Could not open $file: $!";
            my $versions = <$fh>;
            from_json($versions)
        };

    $static_file_paths->{$site}->{files} = $static_files;
}

sub static_file_paths {
    return $static_file_paths;
}

sub static_base {
    my ($class, $site) = @_;
    my $base = $class->config->site->{$site} && $class->config->site->{$site}->{static_base};
    $base ||= '/static';
    $base =~ s!/$!!;
    $base;
}

sub static_url {
    my ($self, $file) = @_;
    $file or cluck "no filename specified to static_url" and return "";
    $file = "/$file" unless $file =~ m!^/!;
    my $regexp = qr/(\.(js|css|gif|png|jpg|ico))$/;
    if ($file =~ m/$regexp/ and my $static_files = $static_file_paths->{$self->site}) {
        my $version;
        if ($self->deployment_mode eq 'devel') {
            my $static_directory = $static_files->{path};
            $version = max($startup_time, (stat("${static_directory}$file"))[9]);
        }
        else {
            $version = $static_files->{files}->{$file};
        }

        $file =~ s!$regexp!.v$version$1! if $version;
    }

    return $self->static_base($self->site) . $file;
}



1;