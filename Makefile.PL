require 5.000;
use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'         => 'Cache::Web::Lite',
	'VERSION_FROM' => 'lib/Cache/Web/Lite.pm',
	'PREREQ_PM'    => {
		Carp           => 0,
		Clone          => 0.13,
		HTML::Location => 0.3,
		List::Util     => 1.11,
		Storable       => 2.10,
		Test::More     => 0,
	},
	($] >= 5.005) ? (
		'AUTHOR'   => 'Adam Kennedy (cpan@ali.as)',
		'ABSTRACT' => 'Cache web content somewhere viewable by browsers ( Lite Version )',
	) : (),
);
