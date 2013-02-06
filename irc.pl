use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
use IO::Socket;
use IO::Select;
use Data::Dumper;
my $socket_path = "/tmp/artemis.sock";
my $socket = IO::Socket::UNIX->new(
	Type => SOCK_STREAM,
	Peer => $socket_path,
) or die("Can't connect to router: $!\n");
print $socket pack("CCn",128,2,0);
my $irc = IO::Socket::INET->new(
	PeerAddr => "abacus.cluenet.org",
	PeerPort => 6667,
) or die("Can't connect to IRC server: $!\n");
print $irc "USER jercosbot * * :I'm artemis version 3's IRC module\r\nNICK artemis3\r\n";
my $s = IO::Select->new();
my $buf;
$s->add($socket);
$s->add($irc);
my %clients = ();
my $gid;
while(my @ready = $s->can_read){
for my $ready (@ready){
	if($ready == $irc){ # A line from IRC
		my $line = <$irc>;
		die "Socket closed" unless defined $line;
		$line =~ s/[\r\n]//g;
		my($special,$main,$longarg) = split(/^:| :/,$line,3);
		if($line =~ s/^PING/PONG/){
			print $irc "$line\r\n";
			next;
		}
		die "Hit an ERROR. Game over man, GAME OVER!\n" if /^ERROR/;
		my($mask,$command,@args) = split(/ +/,$main);
		my($nick, $user, $host) = ($mask,"@",$mask);
		if($mask =~ /!/){
			($nick, $user, $host) = $mask =~ /^([^!]+)!([^@]+)@(.*)$/;
		}
		if($command eq "PRIVMSG"){
			my $returnpath = $args[0] eq "artemis3" ? $nick : $args[0];
			if(my($CTCPcmd, $CTCParg) = $longarg =~ /^\x01([A-Z]+)(.*)\x01$/){
				if($CTCPcmd eq "VERSION"){
					print $irc "NOTICE $nick :\x01VERSION artemis3 IRC module\x01\r\n";
				}elsif($CTCPcmd eq "DCC"){
					$CTCParg =~ s/^\s+//; # ltrim
					print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","dcc",$nick,$returnpath,$CTCParg));
				}elsif($CTCPcmd eq "PING"){
					print $irc "NOTICE $nick :\x01PING$CTCParg\x01\r\n";
				}elsif($CTCPcmd eq "ACTION"){
					print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","chat",$nick,$returnpath,"* $nick$CTCParg"));
				}
			}else{
				print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","chat",$nick,$returnpath,$longarg));
			}
		}
		print $irc "JOIN #thoseguys\r\n" if $command eq "001";
	}elsif($ready == $socket){ # A frame from the router
		$socket->recv($buf,4);
		my($version, $type, $length) = unpack("CCn",$buf);
		$socket->recv($buf, $length);
		if($type == 4){ # reply
			my($id,$type,$returnpath,$message) = unpack("n C/a n/a a*",$buf);
			my $output = "";
			if($type eq "chat" || $type eq "autochat"){
				my $command = $type eq "chat"?"PRIVMSG":"NOTICE";
				$output = join "",map{"$command $returnpath :$_\r\n"}split(/[\r\n]+/,$message);
			}elsif($type eq "rawirc" || $type eq "raw"){
				$output = "$message\r\n";
			}else{
				next;
			}
			print $irc $output;
		}elsif($type == 2){ # gateway ID
			$gid = unpack("n", $buf);
		}else{
			$buf =~ s/([\0-\x1b])/'^'.('0','a'..'z','E')[ord $1]/ge;
			print STDERR Dumper {version => $version, type => $type, length => $length, message => $buf};
		}
	}
}
}
