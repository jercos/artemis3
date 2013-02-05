use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
use Data::Dumper;
my $socket_path = "/tmp/artemis.sock";
my $socket = IO::Socket::UNIX->new(
	Type => SOCK_STREAM,
	Peer => $socket_path,
) or die("Can't connect to server: $!\n");
print "Connected!\n";
print $socket pack("CCn",128,2,0);
my $buf;
my $fork = fork;
if($fork > 0){
	$SIG{INT}=sub{print "\nCaught SIGINT, shutting down.\n";exit 0;};
	END{kill 1, $fork}
	while(<>){
		chomp;
		if(/^\.types/){
			print $socket pack("CCn", 128, 5); # send a type list request
		}elsif(/^\.gateways/){
			print $socket pack("CCnN!", 128, 6, 4, -1); # send a gateway list request
		}else{ # just an ordinary message...
			print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","chat","root","#test",$_)); # Send input lines as "chat" type messages to #test.
		}
	}
}elsif($fork == 0){
while(defined($socket->recv($buf,4)) && defined($buf)){
	my($version, $type, $length) = unpack("CCn",$buf);
	$socket->recv($buf, $length);
	if($type == 4){
		my($id,$type,$returnpath,$message) = unpack("n C/a n/a a*",$buf);
		print "Got a message for $id about $type headed for $returnpath carrying $message\n";
	}else{
		$buf =~ s/([\0-\x1b])/'^'.('0','a'..'z','E')[ord $1]/ge;
		print Dumper {version => $version, type => $type, length => $length, message => $buf};
	}
}
}else{
	print STDERR "Fork failed. Weird."
}
