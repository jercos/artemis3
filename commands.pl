use strict;
use Artemis::Router;
use Artemis::Message qw/:types/;

my $router = Artemis::Router->new()->subscribe("chat");
while(defined(my $packet = $router->block)){
	print "Commands got a message...\n";
	next unless $packet->type == A_MESSAGE;
	my $message = $packet->message;
	print "Commands message is '$message'\n";
	if ($message =~ s/^say //){
		$router->replyto($packet, $message);
	}elsif($message =~ /^test/){
		$router->replyto($packet, "Test passed.");
	}
}
