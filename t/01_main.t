#!/usr/bin/perl -w

# Formal testing for Cache::Web::Lite

use strict;
use File::Spec::Functions qw{:ALL};
use lib catdir( updir(), updir(), 'modules' ), # Development testing
        catdir( updir(), 'lib' );              # Installation testing
use UNIVERSAL 'isa';
use Test::More tests => 2;
use HTML::Location ();

# Check their perl version
BEGIN {
	$| = 1;
	ok( $] >= 5.005, "Your perl is new enough" );
}





# Does the module load
use_ok( 'Cache::Web::Lite' );




exit();
