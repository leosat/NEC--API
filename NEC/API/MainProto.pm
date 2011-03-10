#!/usr/bin/env perl

#
# Package
#
=pod

=head1 NEC::API::MainProto

	________________________________________ _____ ___ __ _ _ 


=head2 Authors.

=over 

The binary protocol was reverse-engineered by B<Alexey Y. Smirnov> (myth@mail.ru),
the module was originally written by B<Leonid E. Satanovsky> (satanovskyl@mail.ru).

=back

=head2 Summary.

=over

The module provides functionality to compile and parse a binary form 
of a B<subset> of the protocol used by the NEC telephone station.
It is B<supposed to be used by the superior-level code> and, generally, 
is not expected to be used by the final user, while it doesn't
handle such abstractions as eg. a connection to the phonestation.

=back	

=cut

=head2 Contents.

=cut

package NEC::API::MainProto;

BEGIN {
	use strict;
	use Exporter;
	use NEC::API::Common;
	our @ISA = qw(Exporter);
	our @EXPORT = qw( &compile_bin_cmd &parse_bin_response );
}

# Commands database
our $commands = {
	'771' => {
		help => "This command does something... "
	},
	'9000' => {
		param_fmt => {
			regex => qr '^(\d{1,8}),(\d{2})$',
			on_regex_no_match => 0,
		},
		help => "This command does something too... "
	}
};

# Get command's property
sub query_cmd_db(@) {
	my ($cmd_code, $prop_name) = @_;
	return $commands->{$cmd_code}->{$prop_name} || 0;
}

=over 

=item sub get_xor_checksum($)

=over

This function gets one scalar argument: some string of data and returns a 1-byte long
sequential checksum of all the bytes in the string.

=back

=cut

# Compute a checksum of a bytes sequence
sub get_xor_checksum($) {
        my $cs = 0;
        foreach my $byte (unpack("C*" ,$_[0])) {
                $cs ^= $byte;
        }
        return $cs;
}

=item sub compile_bin_cmd(@)

=over

This function expects a hash of named arguments: cmd, param, value (optional) and 
returns a scalar string representing its' binary form (see code for binary format details).

	__________________________________ ________ _____ __ _


	Binary request format to read a param value:

	#-------------------------------------------------------------
	# LENGTH IN BITS        | CONTENTS      | COMMENT
	#-------------------------------------------------------------
	# 8                     | 0x11          | BEGIN SIGN
	# 8*1-8*5               | VAR           | ASCII string: command name
	# 8                     | 0x12          | SEPARATOR
	# VAR                   | VAR           | ASCII string: param name
	# 1                     | 0x20          | WHITESPACE CHAR
	# 8			| VAR		| Sequential XOR of all the previous bites.
	#-------------------------------------------------------------

	Binary request format to set a param value:

	#-------------------------------------------------------------
	# LENGTH IN BITS	| CONTENTS	| COMMENT
	#-------------------------------------------------------------
	# 8			| 0x11		| BEGIN SIGN
	# 8*1-8*5		| VAR		| ASCII string: command name
	# 8			| 0x12		| SEPARATOR
	# VAR			| VAR		| ASCII string: param name
	# 8			| 0x12		| SEPARATOR
	# VAR			| VAR		| ASCII string: param value
	# 8			| 0x2e		| SEPARATOR
	# 8			| VAR		| Sequential XOR of all the previous bites.
	#-------------------------------------------------------------

=back

=cut

# Get "binary" representation of the command.
sub compile_bin_cmd(@) {

	my %p = @_;

	if ( ! $p{cmd} || ! defined $p{param} ) {
		return undef;
	}

	my $read_cmd_fmt_no_cs = "CA*CA*C";
	
	my $write_cmd_fmt_no_cs = "CA*CA*CA*C";

	# print $p{param},"\n";
	my $bin;
	my $ctype = query_cmd_db($p{cmd},'type');

	$ctype = (defined $p{value})? 'w' : 'r' 
		if ! $ctype;

	if ( $ctype eq 'r' ) {
		# If this is a read type command
		my @a = (0x11,$p{cmd},0x12,$p{param},0x20);
                push ( @a, get_xor_checksum (
                                pack ( $read_cmd_fmt_no_cs, @a )
                        )
                );
		$bin = pack ( 
			$read_cmd_fmt_no_cs.'C',
			@a
		);
	} elsif ( $ctype eq 'w' ) {
		# If this is a write type command
		my @a = ( 0x11,$p{cmd},0x12,$p{param},0x12,$p{value},0x2e );
		push ( @a, get_xor_checksum (
				pack ( $write_cmd_fmt_no_cs, @a )
			)
		);
		$bin = pack (
			$write_cmd_fmt_no_cs.'C', 
			@a
		)
	}
	return $bin;
}

=item sub parse_bin_response($)

=over

This function expects a binary representation of the command (see source for details) 
as its' only scalar argument and returns a reference to a structure 
of the following form:

	{ 
		type	=> RESPONSE_TYPE, 
		data	=> RESPONSE_DATA,
		cs	=> CHECKSUM
	}

	__________________________________ ________ _____ __ _

	Binary response format: 

	#-------------------------------------------------------------
	# LENGTH IN BITS	| CONTENTS	| COMMENT
	#-------------------------------------------------------------
	# 8			| VAR		| A number of the following bytes
	# 8			| -		| UNKNOWN
	# 8			| VAR		| Response type
	# 8			| -		| UNKNOWN
	# VAR			| VAR		| ASCII string: Response data
	# 8			| VAR		| Sequential XOR of all the previous bites.
	#-------------------------------------------------------------

=back

=cut

# Parse station's response, "binary phase", step 1.
sub parse_bin_response($) {

	our $answer_fmt = "CCCCA(DATA_LENGTH)C";

	# Response structure
	my $r = { 
		type	=> undef, 
		data	=> undef,
		cs	=> undef
	};
	my $bytes_c = unpack('C',$_[0]);
	my $data_l = $bytes_c - 4;
	my $fmt = $answer_fmt;
	$fmt =~ s/\(DATA_LENGTH\)/$data_l/g;
	(undef,undef,$r->{type},undef,$r->{data},$r->{cs}) = unpack (
		$fmt,
		$_[0]
	);
	return $r;
}

=item sub parse_response_data($)

=over

Takes a reference to a structure of the following type:

	{ 
		type	=> RESPONSE_TYPE, 
		data	=> RESPONSE_DATA,
		cs	=> CHECKSUM
	}

as its only argument and if the "type" is of B<RTYPE_DATA_READ_OK> value,
parses the "data" field and adds to the hash the following keys:

=over 

	cmd
	param	
	value

=back

Returns the same reference it takes as the argument.

=back

=cut

# Parse response data, step 2.
sub parse_response_data($) {
        if( $_[0]->{type} eq RTYPE_DATA_READ_OK ){
                $_[0]->{data} =~ /^(.*?)>(.*?):(.*?)-$/;
                $_[0]->{cmd}    = $1;
                $_[0]->{param}  = $2;
                $_[0]->{value}  = $3;
                ## chomp($_[0]->{value});
        }
        return $_[0];
}

1;

=head2 See Also.

	NEC::API::Connection
	NEC::API::Common

=head2 License.

	The code is distributed under the GPL 2 license.

=cut
