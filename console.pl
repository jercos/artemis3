use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
use IO::Select;
use Data::Dumper;
my $socket_path = "/tmp/artemis.sock";
my $socket = IO::Socket::UNIX->new(
	Type => SOCK_STREAM,
	Peer => $socket_path,
) or die("Can't connect to server: $!\n");
print "Connected!\n";
print $socket pack("CCn",128,2,0);
print $socket pack("CCn/a*",128,1,"chat");
print $socket pack("CCn/a*",128,1,"auth");
my $s = IO::Select->new();
my $buf;
$s->add($socket);
$s->add(\*STDIN);
my $gid;
while(my @ready = $s->can_read){
for my $ready (@ready){
	if($ready == \*STDIN){
		$_ = <STDIN>;
		chomp;
		if(/^\.types/){
			print $socket pack("CCn", 128, 5); # send a type list request
		}elsif(/^\.gateways/){
			print $socket pack("CCnN!", 128, 6, 4, -1); # send a gateway list request
		}else{ # just an ordinary message...
			print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","chat","root","#test",$_)); # Send input lines as "chat" type messages to #test.
		}
	}elsif($ready == $socket){
		$socket->recv($buf,4);
		my($version, $type, $length) = unpack("CCn",$buf);
		next unless $version == 128;
		$socket->recv($buf, $length);
		if($type == 4){
			my($id,$type,$returnpath,$message) = unpack("n C/a n/a a*",$buf);
			print "Got a reply for $id about $type headed for $returnpath carrying $message\n";
		}elsif($type == 2){
			$gid = unpack("n",$buf);
		}elsif($type == 0){
			my($id,$type,$sender,$returnpath,$message)=unpack("n C/a C/a n/a a*",$buf);
			print "Got a $type message from $id:$sender at $returnpath carrying $message\n"
		}else{
			$buf =~ s/([\0-\x1b])/'^'.('0','a'..'z','E')[ord $1]/ge;
			print Dumper {version => $version, type => $type, length => $length, message => $buf};
		}
	}
}
}
