#!/usr/bin/env perl

#
# Package
#
package NEC::Console;

use strict;
use Term::ReadLine;
use NEC::API::MainProto;
use NEC::API::Connection;

BEGIN {
	use strict;
};

sub new {
	my $class = shift;
	my $self = 
	{
		prompt		=> 'NEC@%C$ ',
		connections	=> [ ],
		active_connection_id => 1,
		myip		=> 0,
		user_cmd	=> '',
		tokens		=> [],
		term 		=> ( new Term::ReadLine 'Term' ),
		active_connection_id => 0
	};
	bless $self, $class; 
	return $self;
};

sub print_prompt {
	my $self = shift;
	my $p = $self->{prompt};
	my $c = $self->{connections}[$self->{active_connection_id}]->{ID} || "NotConnected";
	$p =~ s/%C/$c/;
	return $p;
}

sub run {
	my $self = shift;

	# THE MAIN LOOP
	MAINLOOP:
	while ( defined ( $self->{user_cmd} = $self->{term}->readline($self->print_prompt()) ) ) {
		$self->{tokens} = [ $self->{user_cmd} =~ /\S+/g ];
		if($self->{tokens}[0] eq 'connect') {
			$self->connect( );
		}		
		if($self->{tokens}[0] eq 'eval') {
			$self->{user_cmd} =~ s/eval//;
			eval "$self->{user_cmd}";
		}		
		if($self->{tokens}[0] =~ /^2h/) {
			my $bin = &compile_bin_cmd (
				cmd	=> $self->{tokens}[1],
				param	=> $self->{tokens}[2],
				value	=> ( join ' ', @{$self->{tokens}}[3..(@{$self->{tokens}} - 1)] )
			);
			print "\t", unpack('H*', $bin),"\n";
			print "\t";
			for my $s (unpack('a*', $bin)) {
				if( $s =~ /[\w\d]/ ) { print $s } else { print '_' }
			}
			print "\n";
		}
	}

}

sub connect {
	my $self = shift;

	$self->{active_connection_id} ++;

	print "Connecting to a tel. station (new connection ID is $self->{active_connection_id})\n";

	my $ip 	 = $self->{term}->readline(" [?] IP: ");
	my $port = $self->{term}->readline(" [?] Port [60000]: ") || 60000;

	$self->{connections}[$self->{active_connection_id}] = { };
	$self->{connections}[$self->{active_connection_id}]->{obj} =
		NEC::API::Connection->new( 
			remote_ip	=> $ip,
			remote_port	=> $port 
		);

	$self->{connections}[$self->{active_connection_id}]->{obj}->connect( ) || do {
		warn "Couldn't connect.\n";
		$self->{connections}[$self->{active_connection_id}] = {};
		return 0;
	};

	$self->{connections}[$self->{active_connection_id}]->{ID} = "$ip:$port";
	return 1;
}

1;
