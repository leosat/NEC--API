#!/usr/bin/env perl

#
# Use connection abstraction
#
use NEC::API::Connection;
use NEC::API::Common;
use NEC::Utils::Common;
use warnings;
use strict;

$| = 1;
my $data_export_file="/m/bin/SyncFromActiveDirectory.pl NECExport |";

#---------------------------------------------
1 && do {

my $erase_first = 0;

my $stations = [
	{ ip => '192.168.125.10' , numrange => [ 100..700 ] },
	{ ip => '192.168.31.210' , numrange => [ 100..1000 ] },
];

for my $station_data (@{$stations}) {

	print "\nPhone station IP is $station_data->{ip}\n";

	my $c = NEC::API::Connection->new( 
		remote_ip	=> $station_data->{ip},
	);

	$c->connect( ) || exit 1;

	print "\nConnected\n";

	if( $erase_first ) {

		#
		# A range of phone numbers.
		# Warning: 100 is one hundreed in decimal, while 0100 is sixty four in octal =), so be careful...
		#
		my @numrange = @{$station_data->{numrange}};
	
		## print @numrange; next;

		#
		# Loop through the telephone numbers in the range.
		#
		for my $num ( @numrange ) {
			my $r = $c->send(
			        cmd => 770,
			        param => sprintf('%04d',$num),
			        value   => NEC::API::Common::s2ascii(" "),
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
	} # end if

	open(my $fh, $data_export_file);
	while(<$fh>) {	
		/(\w+),(\w+)/;
		print $1,' ',$2,"\n";
		my $r = $c->send(
			cmd	=> "770",
			param	=> "$1",
			value	=> "$2",
			read	=> 1
		);
		print "Response type was: ",$r->{type},"\n";
		print "Response was: ",$r->{data},"\n";
		print "Response checksum: ",$r->{cs},"\n";
	}
	close($fh);
}

exit;

};
