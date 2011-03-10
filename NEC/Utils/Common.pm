#!/usr/bin/env perl

#
# Package
#
package NEC::Utils::Common;

BEGIN {
        use strict;
        use Exporter;
        our @ISA = qw(Exporter);
        our @EXPORT = qw( 
		&get_ports_data
		&exec_cmd_seq
	);
};

use NEC::API::Common;

*NEC::Utils::Common::s2ascii = \&NEC::API::Common::s2ascii;


sub get_ports_data(@) {
	my $c = $_[0];
	shift(@_);
	my %p = @_;
        my @port_ranges = (defined $p{ranges}) ? @{$p{ranges}} : (
		0..127,
		1000..1127,
		2000..2127,
		3000..3127
	);
        my $ports_data = {};
        for my $port (@port_ranges) {
		$p{print_progress} && print ".";
                $c->send(
                        cmd => "14",
                        param => sprintf('%05d', $port)
                );
                my $r = $c->read( );
                if ( $r->{type} eq 4 ) {
			if( $p{data_filter} && $r->{value} !~ /$p{data_filter}/i) {
				next;
			}
                        $ports_data->{sprintf('%05d',$port)} = $r->{value};
                }
        }
	$p{print_progress} && print "\n";
        return $ports_data;
}

sub get_virtual_numbers($) {
	my $n = [ ];
	my $c = shift(@_);
	for my $i ( 0..1020 ) {
		$c->send(
			cmd => "11",
			param => sprintf('%04d', $i)
		);
		my $r = $c->read( );
		push(@{$n},$r->{value})
			if ( $r->{type} eq 4 && $r->{value} !~ /NONE/ );
	}
	return $n;
}

sub exec_cmd_seq (@){
        my $c = shift;
        my %p = @_;
        my $cmd = defined $p{commands} ? $p{commands} :
                        defined $p{cmd} ? $p{cmd} :
                        defined $p{seq} ? $p{seq} :
                        shift;
        for my $c_cmd (@$cmd) {
                my $r = $c->send(
                        cmd     => $c_cmd->[0],
                        param   => $c_cmd->[1],
                        value   => $c_cmd->[2],
                        read    => 1
                ) || die "Failed to exec a commands sequence.\n";

                if ( $p{debug} ) {
                        print "----------\n";
                        print 'Entered command: ',join('-', @$c_cmd),"\n";
                        print 'Response type: ',$r->{type},"\n";
                        print 'Response data: ',$r->{data},"\n";
                        if ( defined $r->{type} && $r->{type} eq RTYPE_DATA_READ_OK ) {
                                print 'Returned cmd: '.$r->{cmd}."\n";
                                print 'Returned param: '.$r->{param}."\n";
                                print 'Returned value: '.$r->{value}."\n";
                        }
                }
        }
}

1;

__END__

=head1 NEC::Utils::Common

=head2 Procedures

=over

get_ports_data (
	CONNECTION_OBJECT_REF, 
	ranges => RANGES_LIST_REF, 
	filter => COMPILED_REGEX
)

=back

=head3 Params

=over

B<CONNECTION_OBJECT_REF> is a scalar holding a reference to a NEC::API::Connection class object

B<ranges> param ponts to a structure like I<[ 100..1024, 2048..4096 ]> denoting port ranges to be scanned.

B<filter> helps you filter results by matching returned data with the regex like eg. I<qr'^F'>

=back

=head3 Returns

Returns a hash of elements 
B<PORTYPE_NUMBER> => B<PHONE_NUMBER>



