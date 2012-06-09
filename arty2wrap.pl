# WARNING: this is a hack :D
# requires artemis2 code, specifically an artemis2 module and Artemis::Message to function.
# use: perl arty2wrap.pl Module
# Module.pm should be in the current directory.
use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
use Artemis::Message;
my $socket_path = "/tmp/artemis.sock";
my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socket_path,
) or die("Can't connect to server: $!\n");
print "Connected!\n";
print $socket pack("CCn/a*",128,1,"chat");
do $ARGV[0].".pm";
my $mod = "Artemis::Plugin::".$ARGV[0];
$mod = $mod->new();
my $buf;
while(defined($socket->recv($buf,4)) && defined($buf)){
        my($version, $type, $length) = unpack("CCn",$buf);
	next unless $version == 128 && $type == 0;
        $socket->recv($buf, $length);
	my($id,$type,$sender,$returnpath,$message)=unpack("n C/a C/a n/a a*",$buf);
	$mod->input(Artemis::Connection::Wrapped->new($id,$type,$returnpath),Artemis::Message->new(text=>$message,to=>$returnpath,nick=>"artemis3",user=>$sender))
}

package Artemis::Connection::Wrapped;
sub new{
	my $class = shift;
	my($id, $type, $returnpath) = @_;
	my $self = {id=> $id, type=> $type, returnpath=> $returnpath};
	bless($self,$class);
	return $self;
}

sub connect{
	return 1;
}

sub disconnect{
	return 0;
}

sub Process{
	return 0;
}

sub message{
	my $self = shift;
	my($replyto, $msg) = @_;
	print "Sending message to '$replyto' of type $self->{type} over id $self->{id}: '$msg'\n";
	print $socket pack("CCn/a*",128,4,pack("n C/a* n/a* a*",$self->{id},$self->{type},$replyto,$msg));
}
