package Artemis::Message;
use strict;
use warnings;

use base 'Exporter';

# a 'type' is a string identifier for messages and replies
# types can be subscribed to, and a subscription will cause all message crossing the router
# of that given type to be forwarded to that connection.
# gateways can receive replies, 

use constant A_MESSAGE => 0;	# a broadcast, targetting a type, coming from a gateway and return path.
# n C/a C/a n/a a* => gateway ID, type, sender, return path, message
use constant A_SUBSCRIBE => 1;	# a subscription request, asking to listen for a type.
# a* => type
use constant A_REGISTER => 2;	# a registration request, asking to become a gateway-
# or a response to the same giving the gateway ID
use constant A_GATEWAYID => 3;	# not currently used, gateway gets its ID as an A_REGISTER.
use constant A_REPLY => 4;	# a reply, targetting a gateway, type, and return path.
use constant A_TYPES => 5;	# a request for types, or a response giving a list of types.
use constant A_LASTGATEWAYID => 6;	# a request for the last gateway registered, or a response to same.

use constant A_PREAMBLE_LENGTH => 4;
use constant A_VERSION => 128;

# types for artemis packets
my @types = qw/A_MESSAGE A_SUBSCRIBE A_REGISTER A_GATEWAYID A_REPLY A_TYPES A_LASTGATEWAYID/;
# magic numbers for the protocol
my @magic = qw/A_VERSION A_PREAMBLE_LENGTH/;
our @EXPORT_OK = (@types, @magic);
our %EXPORT_TAGS = ( types => \@types, magic => \@magic );

sub new{
	my $class = shift;
	die "Incorrect argument count" unless @_ == 2;
	my $self = {
		type => $_[0],
		typename => "UNKNOWN($_[0])",
		raw => $_[1],
		parsed => 0,
	};
	return bless($self, $class);
}

sub type{shift->{type}}
sub raw{shift->{raw}}

sub parse{
	my $self = shift;
	my $parsed = {};
	if ($self->{type} == A_MESSAGE) {
		@{$parsed}{qw/id type sender returnpath message/} = unpack("n C/a C/a n/a a*", $self->{raw});
		$self->{typename} = "A_MESSAGE";
	}elsif($self->{type} == A_REGISTER){
		$parsed->{id} = unpack("n", $self->{raw});
		$self->{typename} = "A_REGISTER";
	}elsif($self->{type} == A_REPLY){
		@{$parsed}{qw/id type returnpath message/} = unpack("n C/a n/a a*", $self->{raw});
		$self->{typename} = "A_REPLY";
	}elsif($self->{type} == A_TYPES){
		$parsed->{types} = [unpack("(C/a)*", $self->{raw})];
		$self->{typename} = "A_TYPES";
	}elsif($self->{type} == A_LASTGATEWAYID){
		$parsed->{lastgatewayid} = unpack("n", $self->{raw});
		$self->{typename} = "A_LASTGATEWAYID";
	}else{
		warn "Invalid message type '$self->{type}'!";
	}
	$self->{parsed} = $parsed;
}

our $AUTOLOAD;
sub AUTOLOAD {
	my $self = shift;
	# Remove qualifier from original method name...
	return unless $AUTOLOAD =~ /.*::(.*)$/;
	my $called = $1;
	# Parse the packet if it hasn't already been parsed.
	$self->parse unless $self->{parsed};
	# Is there an attribute of that name?
	die "No such attribute: $called" unless exists $self->{parsed}{$called};
	# If so, return it...
	return $self->{parsed}{$called};
}
sub DESTROY {}

sub typeName{
	my $self = shift;
	$self->parse unless $self->{parsed};
	$self->{typename};
}

sub reply{
	my $self = shift;
	return unless $self->{type} == A_MESSAGE;
	my $message = shift || $self->message;
	return pack("n C/a* n/a* a*",$self->id,$self->type,$self->returnpath,$message);
}

1;
