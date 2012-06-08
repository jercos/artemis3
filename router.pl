#!/usr/bin/perl
use strict;
use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use IO::Select;


#definitions
our @gateways;
our %gateways;
our %subscriptions;
sub DEBUG{3};
my $socket_path = '/tmp/artemis.sock';
sub registerGateway{
	my($connection, $data) = @_;
	my $gateway = $gateways{$connection} = $gateways[@gateways] = {id=> scalar @gateways, conn => $connection};
	print $connection pack("CCnn",128,2,2,$gateway->{id})
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
	print {$gateways[$id]{conn}} pack("CCn/a*",128,4,$data)
	
}

our @messageHandle = (
#0
	\&message,
	\&subscribeType,
	\&registerGateway,
	0, # return gateway ID
	\&reply,
#5
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
		print STDERR "Operating on $ready\n" if DEBUG >= 3;
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
				$s->remove($ready);
				close($ready);
				next;
			}
			print STDERR "Got a message version ",$version," of type ",$type," with a message length of ",$length,"\n" if DEBUG >= 3;
			if($length){
				$ready->recv($buf, $length);
			}else{
				undef $buf;
			}
			next unless exists $messageHandle[$type];
			$messageHandle[$type]($ready, $buf);
		}
	}
}
