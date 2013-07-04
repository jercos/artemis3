package Artemis::Router;

use strict;
use IO::Socket::UNIX qw/SOCK_STREAM/;
use Artemis::Message qw/:types :magic/;

sub new{
	my $class = shift;
	my $self = {
		sock => undef,
		path => "/tmp/artemis.sock",
		@_
	};
	$self->{sock} = IO::Socket::UNIX->new( Type => SOCK_STREAM, Peer => $self->{path} );
	return bless($self, $class);
}

sub message{
	my $self = shift;
	my %args = (
		type => "chat",
		sender => "Alice",
		returnpath => "jercos",
		message => "Help, I'm trapped in a message factory!",
		@_
	);
	$self->sendPacket(A_MESSAGE, pack("C/a* C/a* n/a* a*", @args{qw/type sender returnpath message/}) );
	return $self;
}

sub subscribe{
	my $self = shift;
	my $type = shift;
	$self->sendPacket(A_SUBSCRIBE, $type);
	return $self;
}

sub register{
	my $self = shift;
	$self->sendPacket(A_REGISTER);
	return $self;
}

sub reply{
	my $self = shift;
	my %args = (
		id => -1,
		type => "chat",
		returnpath => "jercos",
		message => "Help, I'm trapped in a reply factory!",
		@_
	);
	$self->sendPacket(A_REPLY, pack("n C/a n/a a*", @args{qw/id type returnpath message/}) );
	return $self;
}

sub replyto{
	my $self = shift;
	my $to = shift;
	$self->sendPacket(A_REPLY, $to->reply(@_));
	return $self;
}

sub types{
	my $self = shift;
	$self->sendPacket(A_TYPES);
	return $self;
}

sub lastGatewayId{
	my $self = shift;
	$self->sendPacket(A_LASTGATEWAYID);
}

sub sendPacket{
	my $self = shift;
	my $type = shift;
	my $data = shift || "";
	$self->{sock}->print( pack("CCn/a*", A_VERSION, $type, $data) );
}

sub block{
	my $self = shift;
	my $buf;
	return undef unless defined $self->{sock}->recv($buf, A_PREAMBLE_LENGTH);
	if (length($buf) != A_PREAMBLE_LENGTH) {
		warn "!!!DATA PROBABLY LOST!!! Short read, returning undef.";
		return undef;
	}
	my($version, $type, $length) = unpack("CCn",$buf);
	if ($version != A_VERSION) {
		warn "!!!DATA PROBABLY LOST!!! Mismatched version/magic. Doing recv(4096) and returning undef.";
		$self->{sock}->recv($buf, 4096);
		return undef;
	}
	my $packet = "";
	while ($length != length($packet)) {
		$self->{sock}->recv($buf, $length - length($packet));
		$packet .= $buf;
	}
	return Artemis::Message->new($type, $packet);
}

1;
