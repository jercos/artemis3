use strict;
use Artemis::Router;
use Artemis::Message qw/:types/;

my $router = Artemis::Router->new()->subscribe("chat")->subscribe("time");
while(defined(my $packet = $router->block)){
	print "Commands got a message...\n";
	next unless $packet->ptype == A_MESSAGE;
	my $message = $packet->message;
	print "Commands message is '$message'\n";
	if($packet->type eq "time"){
		$router->replyto($packet, scalar localtime)
	}
	next unless $packet->type eq "chat";
	if ($message =~ s/^say //){
		$router->replyto($packet, $message);
	}elsif($message =~ /^test/){
		$router->replyto($packet, "Test passed.");
	}
}
