use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
use IO::Socket;
use Data::Dumper;
my $socket_path = "/tmp/artemis.sock";
my $socket = IO::Socket::UNIX->new(
	Type => SOCK_STREAM,
	Peer => $socket_path,
) or die("Can't connect to router: $!\n");
print "Connected to router\n";
print $socket pack("CCn",128,2,0);
my $irc = IO::Socket::INET->new(
	PeerAddr => "abacus.cluenet.org",
	PeerPort => 6667,
) or die("Can't connect to IRC server: $!\n");
print $irc "USER jercosbot * * :I'm artemis version 3's IRC module\r\nNICK artemis3\r\n";
my $buf;
my $fork = fork;
if($fork > 0){
	$SIG{INT}=sub{print STDERR "\nCaught SIGINT, shutting down.\n";exit 0;};
	END{kill 1, $fork}
	select($irc);
	while(<$irc>){
		s/[\r\n]//g;
		print STDERR "$_\n";
		my($special,$main,$longarg) = split(/^:| :/,$_,3);
		print "$_\n" && next if s/^PING/PONG/;
		printf STDERR "%02d:%02d:%02d special data: '%s'\n",(localtime)[2,1,0],$_ if $special;
		die "$_\n" if /^ERROR/;
		my($mask,$command,@args) = split(/ +/,$main);
		my($nick, $user, $host) = ($mask,"@",$mask);
		if($mask =~ /!/){
			($nick, $user, $host) = $mask =~ /^([^!]+)!([^@]+)@(.*)$/;
		}
		my $returnpath = $args[0] eq "artemis3" ? $nick : $args[0];
		if($command eq "PRIVMSG"){
			if($longarg =~ /^\x01([A-Z]+)(.*)\x01$/){
				my($CTCPcmd, $CTCParg) = ($1, $2);
				print STDERR "Got CTCP $CTCPcmd: '$CTCParg'\n";
				if($CTCPcmd eq "VERSION"){
					print $irc "NOTICE $nick :\x01VERSION artemis3 IRC module\x01\r\n";
				}elsif($CTCPcmd eq "DCC"){
					if($CTCParg =~ /^ CHAT CHAT (\d+) (\d+)/){
						my $host = inet_ntoa(pack("N",$1));
						my $port = $2;
						print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","dcc","chat","$host:$port",$nick));
					}
				}elsif($CTCPcmd eq "PING"){
					print $irc "NOTICE $nick :\x01PING$CTCParg\x01\r\n";
				}
			}else{
				print $socket pack("CCn/a*",128,0,pack("C/a* C/a* n/a* a*","chat",$nick,$returnpath,$longarg)) if $command eq "PRIVMSG";
			}
		}
		print "JOIN #thoseguys\r\n" if $command eq "001";
	}
}elsif($fork == 0){
while(defined($socket->recv($buf,4)) && defined($buf)){
	my($version, $type, $length) = unpack("CCn",$buf);
	$socket->recv($buf, $length);
	if($type == 4){
		my($id,$type,$returnpath,$message) = unpack("n C/a n/a a*",$buf);
		my $privmsg = "PRIVMSG $returnpath :$message\r\n";
		print $privmsg;
		print $irc $privmsg;
	}else{
		$buf =~ s/([\0-\x1b])/'^'.('0','a'..'z','E')[ord $1]/ge;
		print Dumper {version => $version, type => $type, length => $length, message => $buf};
	}
}
}else{
	print STDERR "Fork failed. Weird.\n"
}
