use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
use MIME::Base32 qw( RFC );
use Authen::OATH;
my $socket_path = "/tmp/artemis.sock";
my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socket_path,
) or die("Can't connect to server: $!\n");
print "Connected!\n";
print $socket pack("CCn/a*",128,1,"chat");
print $socket pack("CCn/a*",128,1,"auth");
my $buf;
print "Enter master key: ";
my $mkey;
{
	my $mkey_b32 = <STDIN>;
	chomp $mkey_b32;
	die "Need an RFC3548 Base32 key\n" unless $mkey_b32 =~ /^[A-Z2-7]+$/;
	$mkey = MIME::Base32::decode($mkey_b32);
	die "Something went wrong with the Base32 decode\n" unless $mkey;
}
my $lastotp = 0;
while(defined($socket->recv($buf,4)) && defined($buf)){
        my($version, $type, $length) = unpack("CCn",$buf);
	next unless $version == 128 && $type == 0;
        $socket->recv($buf, $length);
	my($id,$type,$sender,$returnpath,$message)=unpack("n C/a C/a n/a a*",$buf);
	if($type eq "chat" and $message =~ s/^authtest //){
		if($message =~ /^[A-Z2-7]+$/){
			my $key = MIME::Base32::decode($message);
			my $otp = Authen::OATH->new()->totp($key);
			print $socket pack("CCn/a*",128,4,pack("n C/a* n/a* a*",$id,$type,$returnpath,"TOTP for that key: ".$otp));
		}else{
			print $socket pack("CCn/a*",128,4,pack("n C/a* n/a* a*",$id,$type,$returnpath,"Invalid base32. Use RFC3548."));
		}
	}elsif($type eq "chat" and $message =~ s/^totp(eval|raw) (\d{6}) //){
		my($command, $otp) = ($1, $2);
		next unless $otp == Authen::OATH->new()->totp($mkey);
		next if $otp == $lastotp;
		$lastotp = $otp;
		if($command eq "eval"){
			my $return = eval($message) or $@;
			print $socket pack("CCn/a*",128,4,pack("n C/a* n/a* a*",$id,$type,$returnpath,$return || "0"));
		}elsif($command eq "raw"){
			print $socket pack("CCn/a*",128,4,pack("n C/a* n/a* a*",$id,"raw",$returnpath,$message));
		}
	}elsif($type eq "auth"){
		# TODO: framework for requesting authentication sessions
	}
}
