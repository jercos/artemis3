use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
use IO::Socket::INET;
use IO::Select;
sub DEBUG{1};
my $socket_path = "/tmp/artemis.sock";
my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socket_path,
) or die("Can't connect to server: $!\n");
print "Connected!\n";
print $socket pack("CCn",128,2,0); # register as a gateway
print $socket pack("CCn/a*",128,1,"dcc"); # and listen for dcc mesages
my $s = IO::Select->new();
my $buf;
$s->add($socket);
my %clients = ();
while(my @ready = $s->can_read){
	for my $ready (@ready){
		if($ready == $socket){
		  my $buf;
		  $socket->recv($buf,4);
		  my($version, $type, $length) = unpack("CCn",$buf);
		  next unless $version == 128;
		  if($type == 4){ # reply
		  	$socket->recv($buf, $length);
			my($id,$type,$returnpath,$message) = unpack("n C/a n/a a*",$buf);
			print STDERR "To $returnpath: $message\n" if DEBUG >= 2;
			next unless exists($clients{$returnpath});
			print {$clients{$returnpath}{conn}} "$message\r\n";
		  }elsif($type == 0){ # message
			$socket->recv($buf, $length);
			my($id,$type,$subtype,$host,$message)=unpack("n C/a C/a n/a a*",$buf); # signature kept the same as a chat message, intentionally.
			if($type eq "dcc" and $subtype eq "chat"){
				print STDERR "Connecting to $host\n" if DEBUG >= 1;
				my $client = new IO::Socket::INET(Proto=>"tcp",PeerAddr=>$host) or next;
				$s->add($client);
				my $clientnick = exists($clients{$message})?$message."_":$message;
				while(exists($clients{$clientnick})){
					$clientnick = $message."_".rand();
				}
				print STDERR "Decided to call $host '$clientnick'\n" if DEBUG >= 1;
				@clients{$clientnick,$client} = ({conn => $client, nick => $clientnick})[0,0]; # Set both nickname and socketname in the clients hash
			}
		  }
		}else{
			my $client = $clients{$ready};
			$_ = <$ready>;
			unless(defined){
				print STDERR "Removing client ", $client->{nick}, "\n" if DEBUG >= 1;
				$s->remove($ready);
				delete @clients{$client->{nick},$client->{conn}};
				close $ready;
				next;
			}
			s/[\r\n]//g;
			print STDERR "From ",$client->{nick},": $_\n" if DEBUG >= 2;
			print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","chat",$client->{nick},$client->{nick},$_));
		}
	}
}
print STDERR "No more sockets, closing up shop.\n";
