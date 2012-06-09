use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
my $socket_path = "/tmp/artemis.sock";
my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socket_path,
) or die("Can't connect to server: $!\n");
print "Connected!\n";
print $socket pack("CCn/a*",128,1,"chat");
my $buf;
while(defined($socket->recv($buf,4)) && defined($buf)){
        my($version, $type, $length) = unpack("CCn",$buf);
	next unless $version == 128 && $type == 0;
        $socket->recv($buf, $length);
	my($id,$type,$sender,$returnpath,$message)=unpack("n C/a C/a n/a a*",$buf);
	if($message =~ s/^say //){
		print $socket pack("CCn/a*",128,4,pack("n C/a* n/a* a*",$id,$type,$returnpath,$message));
	}elsif($message =~ s/^test//){
		print $socket pack("CCn/a*",128,4,pack("n C/a* n/a* a*",$id,$type,$returnpath,"Test passed."));
	}
}
