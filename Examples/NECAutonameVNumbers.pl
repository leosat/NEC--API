#!/usr/bin/env perl

#
# Use some NEC::* modules
#
use NEC::API::Connection;
use NEC::API::Common;
use NEC::Utils::Common;

my $force_renaming = 1; 

my $stations = [
        { ip => '192.168.125.10' , numrange => [ 100..700 ],  portrange => [ 0..127, 1000..1127 ] },
        { ip => '192.168.31.210' , numrange => [ 100..1000 ], portrange => [ 0..127, 1000..1127 ] },
];

#################################################
# CYCLE OVER PBX STATIONS.
#
for my $station_data (@{$stations}) {


print "-----------------------------------------------------------\n";
print "Connecting to PBX station $station_data->{ip}\n\n";

#
# Create the connection object.
#
$c = NEC::API::Connection->new(
	remote_ip	=> $station_data->{ip},
);

$c->connect( ) 
	|| exit 1;

#
# Get all digital ports/phones.
#
my $d =  NEC::Utils::Common::get_ports_data ( 
	$c,
	ranges		=> $station_data->{portrange},
	data_filter	=> qr'^F'i,
	print_progress	=> 1,
);

print "Digital phones data:\n";

#
# For all digital phones...
#
for my $k ( sort keys %$d ) { 

	my $r;
		
	print "Port: $k,"," Number: ",$d->{$k},", ";
		
	# 
	# Save the number in $num var and remove unnesessary chars from it.
	#
	( my $num = $d->{$k} ) =~ s/^F//;
		
	#
	# What is the name behind the number?
	#
	my $name = $c->send( 
		cmd	=> "770",
		param	=> "$num",
		read	=> 1
	)->{value};

	print "Name: ",$name,"\n";
	
	## next;

	#
	# Loop through the keys of the digital phone
	#
	for my $key (1..24) {
		
		#
		# Read the phone behind the key
		#
		my $num_under_the_key = $c->send( 
			cmd	=> "9000",
			param	=> sprintf('%s,%02d',$num,$key),
			read	=> 1
		)->{value};
			
		#
		# If it is not a functional key or NONE
		#
		if ( $num_under_the_key !~ /(^F|NONE)/ ) {

			print "\tKey: $key, Num: ",$num_under_the_key,"\n";
				
			#
			# Read and print the name behind the key assosiated phone number
			#
			my $name_under_the_key = $c->send( 
				cmd	=> "770",
				param	=> $num_under_the_key,
				read	=> 1
			)->{value};

			print "\t\tName under the key: ", $name_under_the_key,"\n" if ( defined $name_under_the_key );
				
			#
			# Check if the number is virtual...
			#
			$r = $c->send( 
				cmd	=> "E401", 
				param	=> $num_under_the_key,
				read	=> 1
			);
				
			#
			# If it is virtual
			#
			if ( $r->{type} eq RTYPE_DATA_READ_OK && $r->{value} =~ /^_/ ) {

	      		        print "\t\t\tVirtual number.\n";
					
				#
				# Check if the virtual number is unnamed
				#
				if( $name !~ /(NONE|^$)/ && ( $name_under_the_key =~ /(NONE|^$)/ || $force_renaming )) {
					if ($force_renaming) {
						print "\t\t\tForced renaming...\n";
					} else {
						print "\t\t\tIt is unnamed, so name it...\n";
					}
					#
					# Name it!
					#
					$c->send(
						cmd	=> "770",
						param	=> $num_under_the_key,
						value	=> NEC::API::Common::s2ascii($name),
						read	=> 1
					);
				}
			}
		}
	}
};

$c->close( );

}

0;
