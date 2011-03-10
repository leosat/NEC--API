=head1 NEC::API::Common

=head2 Comments.

	Defines and exports constants and common routines used in other parts of the API code.
	The file defines the following constatns which are usefull for the
	end-user:...

=head2 Response type constants (prefixed with RTYPE_).

B<RTYPE_ENTER_COMMAND>

	The "COMMAND> " prompt recieved.
	(usefull for text-mode communication)

B<RTYPE_OK>

	Just OK, usually when the (modification) 
	operation was successfull.

B<RTYPE_DATA_ERROR>

	Error on the data input/output.

B<RTYPE_DATA_READ_OK>

	Data read successful.

=head2 See Also.

	NEC::API::Connection
	NEC::API::MainProto

=cut

#
# Common functionality.
#
package NEC::API::Common;

BEGIN {
	use strict;

	#
	# Station response types
	#
	use constant RTYPE_ENTER_COMMAND => 1;
	use constant RTYPE_OK => 6;
	use constant RTYPE_DATA_ERROR => 132;
	use constant RTYPE_DATA_READ_OK => 4;

	#
	# Param parsing results
	#
	use constant PARAM_PARSE_FAILED => 1;

	use Exporter;
	our @ISA = qw(Exporter);
	our @EXPORT = qw (
		&s2ascii

		RTYPE_ENTER_COMMAND
		RTYPE_OK
		RTYPE_DATA_ERROR
		RTYPE_DATA_READ_OK

		PARAM_PARSE_FAILED
	);
}

# Custom: convert string to ASCII codes
sub s2ascii(@) {
        my $out = '';
        my $sep = '';
	my $max_length = $_[1] || 16;
        for(my $i = 0; $i < length($_[0]); $i ++ ) {
                last if ( $i == $max_length );
                $out .= $sep if $i > 0;
                $out .= sprintf( '%X', ord ( substr($_[0],$i,1) ) );
        }
        return $out;
}

1;
