import os,socket,perlpack
from signal import signal, SIGINT
A_VERSION = 128
A_MESSAGE = 0
A_SUBSCRIBE = 1
A_REPLY = 4
frames = perlpack.Format("CCn")
def frame(ptype, message):
	return frames.pack(A_VERSION, ptype, len(message)) + message
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
signal(SIGINT, lambda sn,f: s.close())
s.connect("/tmp/artemis.sock")
s.send(frame(A_SUBSCRIBE, "chat"))
while True:
	version, ptype, length = frames.unpack(s.recv(4))
	print "version %s type %s length %s" % (version, ptype, length)
	if version != A_VERSION:
		raise Exception("Bad magic number in frame")
	message = s.recv(length)
	while len(message) < length:
		print "Current payload length %s too small, recv-ing until we have %s" % (len(message), length)
		message += s.recv(length - len(message))
	if ptype == A_MESSAGE:
		print "Message is " + ":".join("{0:02x}".format(ord(c)) for c in message)
		(id, ptype, sender, returnpath, content) = perlpack.Format("n C/a C/a n/a a*").unpack(message)
		print "A_MESSAGE(%s) from %s at %s (%s): '%s'" % (ptype, sender, id, returnpath, content)
	else:
		print "Message is " + ":".join("{0:02x}".format(ord(c)) for c in message)
