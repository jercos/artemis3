#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use IO::Select;


#definitions
our @gateways;
our %gateways;
our %subscriptions = (chat => []);
sub DEBUG{3};
my $socket_path = '/tmp/artemis.sock';
sub registerGateway{
	my($connection, $data) = @_;
	my $id = scalar @gateways;
	my $gateway = $gateways{$connection} = $gateways[$id] = {id => $id, conn => $connection, sd => fileno($connection)};
	print $connection pack("CCnn",128,2,2,$gateway->{id}) # Send the assigned gateway ID back to the client
}
sub subscribeType{
	my($connection, $data) = @_;
	push @{$subscriptions{$data}}, $connection;
}
sub message{
	my($connection, $data) = @_;
	my($type,$sender,$returnpath,$message) = unpack("C/a C/a n/a a*",$data);
	my $id = $gateways{$connection}{id};
	for my $client (@{$subscriptions{$type}}){
		my $outgoing = pack("n C/a* C/a* n/a* a*",$id,$type,$sender,$returnpath,$message);
		print $client pack("CCn/a*",128,0,$outgoing);
	}
}
sub reply{
	my($connection, $data) = @_;
	my($id,$type,$returnpath,$message) = unpack("n C/a n/a a*",$data);
	return unless $gateways[$id]{conn};
	print {$gateways[$id]{conn}} pack("CCn/a*",128,4,$data)
	
}
sub subscribableTypes{
	my($connection, $data) = @_;
	my @types = unpack("(C/a*)*", $data);
	if(@types){
		1;	# TODO: Currently, routers can't talk to each other. We'll keep an inverted hash of seen types later.
	}else{	# Empty type list = request for type list. Make sure %subscriptions is never empty of keys :p
		print $connection pack("CCn/a*",128,5,pack("(C/a*)*", keys %subscriptions));
	}
}
sub lastGatewayId{
	my($connection, $data) = @_;
	my $count = unpack("N!", $data);
	if($count == -1){
		print $connection pack("CCnn",128,6,4,$#gateways);
	}else{
		1;	# TODO: Currently, routers can't talk to each other. We'll keep a max gateway ID for each router to avoid passing on invalid messages later.
	}
}

our @messageHandle = (
#0
	\&message,
	\&subscribeType,
	\&registerGateway,
	0, # return gateway ID
	\&reply,
#5
	\&subscribableTypes,
	\&lastGatewayId,
);

#init the socket

my $s = IO::Select->new();
my $listner = IO::Socket::UNIX->new(
	Type   => SOCK_STREAM,
	Local  => $socket_path,
	Listen => SOMAXCONN,
) or die("Can't create server socket: $!\n");
$s->add($listner);
$SIG{INT}=sub{print "\nCaught SIGINT, shutting down.\n";exit 0;};
END{unlink $socket_path}

#main loop
while(my @ready = $s->can_read){
	for my $ready (@ready){
		if($ready == $listner){
			my $incoming = $listner->accept();
			$s->add($incoming);
		}else{
			my $buf;
			$ready->recv($buf, 4);
			print STDERR "Short message... ",(eof($ready)?"":"not "),"eof\n" if length($buf) < 4;
			my($version, $type, $length) = unpack("CCn",$buf);
			unless(defined $version and $version == 128){
				print STDERR "Bad version, killing client.\n" if DEBUG >= 1;
				if(exists($gateways{$ready})){
					print STDERR "Destroying gateway (",$gateways{$ready}{sd},")\n";
					undef $gateways{$ready}{conn}; # Delete the connection entry in any gateways this client has
				}
				for my $clients (values %subscriptions){
					@$clients = grep{$_ != $ready}@$clients; # Remove any subscriptions this client has
				}
				$s->remove($ready); # Remove the client from the select loop
				close($ready);
				next; # We should now no longer have a reference to the dead socket
			}
			print STDERR "Got a message of type ",$type," with a message length of ",$length,"\n" if DEBUG >= 3;
			if($length){
				$ready->recv($buf, $length);
			}else{
				undef $buf;
			}
			if(length($buf) != $length){
				print STDERR "Message length: ",length($buf),", Expected length: $length.\n" if DEBUG >= 1;
			}
			next unless exists $messageHandle[$type];
			$messageHandle[$type]($ready, $buf);
		}
	}
}
