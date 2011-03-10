#!/usr/bin/env perl
#
# What this script does:
#	Print all the names behind the telephone numbers in some range.
#

use strict;
use warnings;

#
# Use connection abstraction
#
use NEC::API::Connection;
#
# We'll need this for constants denoting stations' answer types
#
use NEC::API::Common;

$| = 1;

#
# Create the connection (to the phonestation) object
#
my $c = NEC::API::Connection->new( 
	remote_ip	=> "192.168.125.10",
	password	=> "12345",
);


# Connect or exit on connection failture
$c->connect( ) || exit 1;

#
# A range of phone numbers. 
# Warning: 100 is one hundreed in decimal, while 0100 is sixty four in octal =), so be careful...
#
my @numrange = ( defined $ARGV[0] ) ? eval $ARGV[0] : 
	( 100..1000 )
;

#
# Loop through the telephone numbers in the range.
#
for my $num ( @numrange ) {

	#
	# What is the name?
	#
	my $r = $c->send(
		cmd => 770,
		param => sprintf('%04d',$num),
		read => 1
	);

	#
	# If we've got some interesting results... 
	#
	if ( $r->{type} eq RTYPE_DATA_READ_OK &&
		$r->{value} !~ /NONE/i) {

		#
		# Output 'em.
		#
		print sprintf('%04d',$num)," ",$r->{type}," ",$r->{value},"\n";
	}
}

#
# Close the connection
#
$c->close( );

#
# Return a success code to the OS (it is 0 on UNIX).
#
0;
