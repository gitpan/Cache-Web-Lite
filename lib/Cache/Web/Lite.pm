package Cache::Web::Lite;

# See POD at end for documentation

### Memory Overhead: 128K

require 5.005;
use strict;
use UNIVERSAL 'isa';
use Carp ();
use Clone ();
use List::Util ();
use HTML::Location ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.02';
}

# Define assertions
sub _SELF(@);
sub _CLASS(@);
sub _KEY($);
sub _DATA($);





#####################################################################
# Constructor

sub new {
	my $class   = _CLASS(shift);
	my $options = ref $_[0] eq 'HASH' ? shift : { @_ };

	# Create the basic object
	my $self = bless {
		cache_location  => undef,
		}, $class;

	# Set the cache root
	$self->_set_cache_location( $options->{cache_root} );

	$self;
}





#####################################################################
# Cache Properties

sub default_expires       { Carp::croak "default_expires is not implemented in Cache::Web::Lite" }
sub set_default_expires   { Carp::croak "default_expires is not implemented in Cache::Web::Lite" }

sub removal_strategy      { Carp::croak "removal_strategy is not implemented in Cache::Web::Lite" }

sub size_limit            { Carp::croak "size_limit is not implemented in Cache::Web::Lite" }

sub load_callback         { Carp::croak "load_callback is not implemented in Cache::Web::Lite" }
sub set_load_callback     { Carp::croak "load_callback is not implemented in Cache::Web::Lite" }

sub validate_callback     { Carp::croak "validate_callback is not implemented in Cache::Web::Lite" }
sub set_validate_callback { Carp::croak "validate_callback is not implemented in Cache::Web::Lite" }





#####################################################################
# Cache::File Properties

sub cache_root { $_[0]->{cache_location}->path }

sub _set_cache_location {
	my $self = _SELF(shift);
	my $location = isa( ref $_[0], 'HTML::Location' ) ? shift
		: Carp::croak "Constructor must be given a HTML::Location object for the cache_root option";

	# Check the location
	my $dir = $location->path;
	unless ( -e $dir ) {
		Carp::croak "Cache root HTML::Location does not exist";
	}
	unless ( -d $dir ) {
		Carp::croak "Cache root HTML::Location is not a directory";
	}
	unless ( -r $dir and -w $dir ) {
		Carp::croak "Cache root HTML::Location is not read/writable";
	}

	$self->{cache_location} = $location;
}

sub cache_depth { Carp::croak "cache_depth is not implemented in Cache::Web::Lite" }
sub cache_umask { Carp::croak "cache_umask is not implemented in Cache::Web::Lite" }
sub lock_level  { Carp::croak "lock_level is not implemented in Cache::Web::Lite"  }





#####################################################################
# Cache::Web::Lite Properties

sub cache_location { Clone::clone $_[0]->{cache_location} }





#####################################################################
# Cache Methods

# Purge all expired entries from the cache.
# As we do not support expiry, so this is a nullop
sub purge { 1 }

# Remove all entries from the cache
sub clear {
	my $self = _SELF(@_);
	my @entries = $self->get_keys;

	# Remove all the entries
	foreach my $key ( @entries ) {
		$self->remove($key);
	}

	1;
}

# Returns the number of entries in the cache
sub count {
	my $self = _SELF(@_);
	scalar ($self->get_keys);
}

# Returns the size (in bytes) of the cache
sub size {
	my $self = _SELF(shift);

	if ( @_ ) {
		# Find the size of a single entry
		my $file = $self->path(shift);
		my @s = stat $file or Carp::croak "Failed to stat $file";
		$s[7];

	} else {
		# Find the size of the entire cache
		List::Util::sum map { $self->size($_) } $self->get_keys;

	}
}
	




#####################################################################
# Cache::Web::Lite Methods

sub get_keys {
	my $self = _SELF(@_);

	# Open the cache directory and find all writable files
	opendir( CACHE, $self->cache_root ) or Carp::croak "opendir: $!";
	my @files = grep { -f $_ and -r $_ and -w $_ } readdir( CACHE );
	closedir( CACHE );

	@files;
}





#####################################################################
# Cache Shortcuts

# Returns a boolean value (1 or 0) to indicate whether there is any data present in the cache for this entry.
sub exists {
	my $self = _SELF(shift);
	my $file  = $self->path(shift);

	# Does the file exist and is it read/writable
	( -f $file and -r $file and -w $file ) ? 1 : 0;
}

sub set {
	my $self   = _SELF(shift);
	my $key    = $self->_key(shift);
	my $file   = $self->path($key);
	my $data   = $self->_data(shift);
	Carp::croak "Cache::Web::Lite does not support expiry" if @_;

	# We can't write the file if there is an existing,
	# non-readable or non-writable, file or directory in the way.
	if ( -e $file and ! (-r $file or -w $file) ) {
		Carp::croak "An unreplacable file/dir is blocking '$file'";
	}

	# Write the data to the file in one hit
	### FIXME - Use more robust locking/write code later
	open( ITEM, ">$file" ) or Carp::croak "open: $!";
	print ITEM $data       or Carp::croak "write: $!";
	close( ITEM )          or Carp::croak "close: $!";

	1;
}

# Returns the data from the cache, or undef if the entry doesn't exist.
sub get {
	my $self = _SELF(shift);
	my $key  = $self->_key(shift);

	# Return undef if the key does not exist
	$self->exists($key) or return undef;

	# Slurp in the file
	local $/ = undef;
	open( DATA, $self->path($key) ) or Carp::croak "open: $!";
	my $data = <DATA>;
	close DATA or Carp::croak "close: $!";

	$data;
}

# Clear the data for this entry from the cache.
sub remove {
	my $self = _SELF(shift);
	my $key  = $self->_key(shift);

	# Shortcut if it doesn't exist
	return 1 unless $self->exists($key);
	
	# Remove the file
	unlink $self->path($key) or Carp::croak "unlink: $!";
}

sub expiry       { Carp::croak "Cache::Web::Lite does not support expiry" }
sub set_expire   { Carp::croak "Cache::Web::Lite does not support expiry" }

sub handle       { Carp::croak "handle is not implemented in Cache::Web::Lite" }

sub validity     { Carp::croak "validity is not implemented in Cache::Web::Lite" }
sub set_validity { Carp::croak "validity is not implemented in Cache::Web::Lite" }

# Identical to 'set', except that data may be any complex data type that can be serialized via Storable.
sub freeze {
	my $self = _SELF(shift);
	my $key  = $self->_key(shift);
	require Storable; # Storable use is rare, so only load as needed
	$self->set( $key, Storable::nfreeze(shift), @_ );
}

# Identical to 'get', except that it will return a complex data type that was set via 'freeze'.
sub thaw {
	my $self = _SELF(shift);
	my $key  = $self->_key(shift);
	require Storable; # Storable use is rare, so only load as needed
	my $data = $self->get( $key );
	defined($data) ? Storable::thaw($data) : undef;
}





#####################################################################
# Cache::Web::Lite Methods

# Get the HTML::Location for a cached entry
sub location {
	my $self = shift;
	my $key  = $self->_key(shift);
	$self->{cache_location}->catfile( $key );
}

# Get the file path for the cached entry
sub path {
	my $self = shift;
	my $key  = $self->_key(shift);
	$self->{cache_location}->catfile( $key )->path;
}

# Get the URI for the cached entry in string form
sub uri {
	my $self = shift;
	my $key  = $self->_key(shift);
	$self->{cache_location}->catfile( $key )->uri;
}

# Get a copy of the URI object for the cached entry
sub URI {
	my $self = shift;
	my $key  = $self->_key(shift);
	$self->{cache_location}->catfile( $key )->URI;
}





#####################################################################
# Support Methods

# Is a sub being called as a static method.
# The first argument should be of the same class as our immediate caller.
# If called by _CLASS(@_) additionally checks there are no params.
sub _CLASS(@) {
	@_ == 1 or Carp::croak "Static method was passed params when none expected";
	defined $_[0] and ! ref $_[0] and isa( $_[0], (caller)[0] ) and return shift;
	Carp::croak "Static method was not called as such";
}

# Is a sub being called as an object method
# The first argument should be an object of the same class as our immediate caller.
# If called by _SELF(@_) additionally checks there are no params.
sub _SELF(@) {
	@_ == 1 or Carp::croak "Instance method was passed params when none expected";
	defined $_[0] and isa( ref $_[0], (caller)[0] ) and return shift;
	Carp::croak "Instance method was not called as such";
}

# Check that a key is valid
sub _KEY($) {
	my $self = shift;
	my $key = shift;
	( defined $key and ! ref $key and length $key and $key !~ m/(?:\.\.|\/|\\)/ )
		? return $key
		: Carp::croak "Invalid key name";
}

# Check for valid data
### FIXME - At this point, only check that it is defined
sub _DATA($) {
	defined $_[0] ? $_[0] : Carp::croak "Illegal data format";
}

1;

__END__

=pod

=head1 NAME

Cache::Web::Lite - Cache web content somewhere viewable by browsers ( Lite Version )

=head1 SYNOPSIS

  # Define the cache root
  my $cache_root = HTML::Location->new( '/var/www/blah', 'http://ali.as/blah' );
  
  # Create the cache handle
  my $Cache = Cache::Web::Lite->new( cache_root => $cache_root );
  
  # Add a graph to the cache
  $Cache->set( 'my_graph.gif', $graph_data );
  
  # Get the URI to tell a browser where to find it
  my $URI = $Cache->uri( 'my_graph.gif' );

=head1 DESCRIPTION

EXPERIMENTAL AND LARGELY UNTESTED - DO NOT USE THIS MODULE!

Cache::Web::Lite implements a slimline version of a Cache.pm compatible API
for caching generated web content in a location where we can retrieve it,
AND where a browser can get it directly, without having to launch another
script.

This is great for generating pages with images in them, as you can use a
single invocation of a script to generate both the page and any custom images
for it, and by the time the browser recieves the HTML page, the images are
in place ready for it to fetch directly from the web server, without having
to bother the script multiple times.

Due to it's ::Lite nature, Cache::Web::Lite implements a lookalike API, but
is not a direct descendant of Cache.pm. See Cache::Web ( if written yet )
for a fully compatible and fully feature-complete implementation.

Cache::Web::Lite also lacks many of the features of Cache.pm. It supports only
storage and retrieval of raw data and Storable objects. Expiry times, load and
validation callbacks, and most other extra features are not supported.

For the full Cache.pm API see L<Cache>. Additional properties and methods are
described below.

=head1 PROPERTIES

=head2 new cache_root => HTML::Location

The constructor takes a series of options in the same form as Cache.pm.
However, only the cache_root option is supported. Also, unlike Cache.pm,
the cache_root option MUST be a HTML::Location object which describes the
path/URI duality of the root of the web cache.

=head2 cache_location

Unlike C<cache_root>, which returns the root path of the cache, the
C<cache_location> method returns a copy of the actual
L<HTML::Location|HTML::Location> object for the root of the cache.

=head1 SHORTCUT METHODS

=head2 location $key

Returns a HTML::Location object for the location of the entry, if it exists.

=head2 path $key

Returns the path on the filesystem where the data is stored, if it exists.

=head2 uri $key

Returns a uri string for the web location of the entry, if it exists.

=head2 URI $key

Returns a URI object for the web location of the entry, if it exists.

=head1 TO DO

* Implement at least a few of the features from Cache.pm

* Write a more complete test suite.

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

  http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Cache%3A%3AWeb%3A%3ALite

For other issues, contact the author

=head1 AUTHORS

        Adam Kennedy ( maintainer )
        cpan@ali.as
        http://ali.as/

=head1 COPYRIGHT

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
