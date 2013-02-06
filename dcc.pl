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
my $gid; # gateway ID, we should get this as one of our first messages.
while(my @ready = $s->can_read){
	for my $ready (@ready){
		if($ready == $socket){
		  my $buf;
		  $socket->recv($buf,4);
		  my($version, $type, $length) = unpack("CCn",$buf);
		  next unless $version == 128;
		  $socket->recv($buf, $length);
		  if($type == 4){ # reply
			my($id,$type,$returnpath,$message) = unpack("n C/a n/a a*",$buf);
			print STDERR "To $returnpath: $message\n" if DEBUG >= 2;
			next unless exists($clients{$returnpath});
			print {$clients{$returnpath}{conn}} "$message\r\n";
		  }elsif($type == 0){ # message
			my($id,$type,$nick,undef,$message)=unpack("n C/a C/a n/a a*",$buf); # signature kept the same as a chat message, intentionally.
			if($type eq "dcc" and $message =~ /^CHAT CHAT (\d+) (\d+)/){
				my $host = inet_ntoa(pack("N",$1));
				my $port = $2;
				next if $port == 0;
				print STDERR "Connecting to $host\n" if DEBUG >= 1;
				my $client = new IO::Socket::INET(Proto=>"tcp",PeerAddr=>$host,PeerPort=>$port) or next;
				$s->add($client);
				my $clientnick = exists($clients{$nick})?$nick."_":$nick;
				while(exists($clients{$clientnick})){
					$clientnick = $nick."_".rand();
				}
				print STDERR "Decided to call $host '$clientnick'\n" if DEBUG >= 1;
				@clients{$clientnick,$client} = ({conn => $client, nick => $clientnick})[0,0]; # Set both nickname and socketname in the clients hash
				print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","auth",$clientnick,"session","start $host:$port"));
			}
		  }elsif($type == 2){ # gateway ID
			$gid = unpack("n", $buf);
		  }
		}else{
			my $client = $clients{$ready};
			$_ = <$ready>;
			unless(defined){
				print STDERR "Removing client ", $client->{nick}, "\n" if DEBUG >= 1;
				print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","auth",$client->{nick},"session","end $!"));
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
