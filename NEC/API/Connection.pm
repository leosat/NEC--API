#!/usr/bin/env perl

=head1 NEC::API::Connection

__________________________________________ ______________ ________ ______ ___ _  _

=head2 About.

This is an B<O>bjectB<O>riented module representing B<a class for connection to the telephone station>.

Currently only B<inet> type of connection is supported. 

See examples section for more details.

=head2 Examples.

=head3 Create a connection object and establish the connection.

	use NEC::API::Connection;
	use NEC::API::Common;	# import constants and some functions

	my $c = NEC::API::Connection->new( 
		remote_ip	=> "1.2.3.4",
		remote_port	=> 12345,
		# password	=> "123"
	);

	$c->connect( ) || die "Failed to connect.\n";

=head3 Send a B<"get"> command

	my $r = $c->send(
		cmd	=> "770",
		param	=> "1234",
		read	=> 1
	);

	#
	# Print the answer data if read operation completed successfully ...
	#
	if ( $r->{type} eq RTYPE_DATA_READ_OK ) {
		print "Returned data string is: ",$r->{data},"\n";
		print "Value field of the data string contains the following: ",$r->{value},"\n";
	}
	#
	# ... or print some diagnostical message if it failed.
	#
	else {
		print " [warning] Failed to read data, answer type was ",$r->{type},"\n";
	}

=head3 Send a B<"set"> command

	my $r = $c->send(
		cmd	=> "770",
		param	=> "0102",
		value	=> "SomeName",
		read	=> 1
	);

or...

	my $r = $c->send(
		cmd	=> "770",
		param	=> "0102",
		value	=> NEC::API:Common::s2ascii("Some Special Name"),
		read	=> 1
	);

Note the B<read> param in the previous examples... or, other way you might say:

	$c->send(
		cmd	=> "770",
		param	=> "0102",
		value	=> "SomeName",
	);
	my $r = $c->read( );


This is the same as in the first example of the previous case.

_______________________________________________ _______ ____ _

=head2 The answer hash/structure.

In all the examples B<$r> variable gets a reference to the answer structure (a hash), which
has the following keys/fields:

=over

=over

=item I<type>

The type of the stations' answer (see constatns in B<NEC::API::Common> module).

=item I<data>

The textual part of the answer.

=back

=back

And if the B<type> equals B<RTYPE_DATA_READ_OK> constant value, the answer structure also contains fields 
holding parts of the parsed B<data> field: B<I<cmd, param, value>>.

_______________________________________________ _______ ____ _

=cut
#
# Package
#
package NEC::API::Connection;

use strict;
use warnings;
use NEC::API::MainProto;
use NEC::API::Common;
use IO::Socket;

$| = 1;

sub new {
	my $class = shift;
	my $self = { 
		socket		=> 0,
		mode		=> 0,
		remote_ip	=> '127.0.0.1',
		remote_port	=> 60000,
		type		=> 'inet',
		read_on_send	=> 0,
		@_ ,
	};
	bless $self, $class;
	return $self;
};

sub read {
	my $self = shift;
	# BINARY MODE
	if(!$self->{mode}) {
		my $br;		# Response data
		# IF INET TYPE CONNECTION
		if($self->{type} eq 'inet') {
			$self->{socket}->recv($br,1024);
		}
		my $r = parse_bin_response($br);
		return NEC::API::MainProto::parse_response_data($r);
	}
}

sub send {
	my $self = shift;
	my %p = @_;
	my $read = (defined $p{read}) ? 1 : 0;
		undef $p{read} if defined $p{read};
	# BINARY MODE
	if(!$self->{mode}) {
		my $cmd_bin = compile_bin_cmd (@_);
		# IF INET TYPE CONNECTION
		if($self->{type} eq 'inet') {
			$self->{socket}->print($cmd_bin);
		}
	}
	return $self->read( ) if $read;
	return 1;
}

sub connect {
	my $self = shift;
	# IF INET TYPE CONNECTION
	if($self->{type} eq 'inet') {
		$self->{socket} = IO::Socket::INET->new(
			PeerAddr	=> $self->{remote_ip},
			PeerPort	=> $self->{remote_port},
			Proto		=> 'tcp'
		);
		unless ( $self->{socket} ) {
			warn "Could not create socket: $!\n";
			return 0;
		}
		return 1;
	}
	if ( $self->{password} ) {
		$self->send( cmd => "E9", param => "9" );
		my $r = $self->read( );
		if( $r->{value} eq "0" ) {
			$self->send( cmd => "03", param => "7", value => $self->{password} );
			my $r = $self->read( );
			if ( $r->{type} ne RTYPE_OK  ) {
				warn "[w] Station responded to the entered password with type $r->{type} message: $r->{data}","\n";
				# TODO: in what case should we return false here?
			}
		} else {
			warn "[n] No password required.\n";	
		}
	}
	return 1;
}

sub close {
	my $self = shift;
	if($self->{type} eq 'inet') {
		close($self->{socket});
	}
}

1;

=head2 See Also.

	NEC::API::Common
	NEC::API::MainProto

=cut
