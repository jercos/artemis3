import struct, socket

class Format:
	def __init__(self, fmt):
		self.fmt = fmt
	def pack(self, *args):
		fmtpos = 0
		argpos = 0
		width = 1
		output = ""
		while len(self.fmt) > fmtpos:
			print "Handling format char %s, and argument %s" % (self.fmt[fmtpos], args[argpos])
			if len(self.fmt) > fmtpos + 1 and self.fmt[fmtpos + 1] == '/':
				input = len(args[argpos])
				width = 0
			else:
				input = args[argpos]
				width = 1
			if self.fmt[fmtpos] == 'n':
				output += struct.pack("!H", input)
				argpos += width
			elif self.fmt[fmtpos] == 'C':
				output += struct.pack("B", input)
				argpos += width
			elif self.fmt[fmtpos] == 'a':
				if self.fmt[fmtpos + 1] == '*':
					fmtpos += 1
					return output + args[argpos]
			elif self.fmt[fmtpos] == '/':
				if self.fmt[fmtpos + 1] == 'a':
					output += args[argpos]
					argpos += 1
					fmtpos += 1
			fmtpos += 1
		return output
	def unpack(self, buffer):
		bufpos = 0
		fmtpos = 0
		repeat = None
		output = []
		while len(self.fmt) > fmtpos:
			if self.fmt[fmtpos] == 'n':
				output += struct.unpack_from("!H", buffer, bufpos)
				bufpos += 2
			elif self.fmt[fmtpos] == 'C':
				output += struct.unpack_from("B", buffer, bufpos)
				bufpos += 1
			elif self.fmt[fmtpos] == 'a':
				fmtpos += 1
				if self.fmt[fmtpos] == '*':
					return output + [buffer[bufpos:]]
			elif self.fmt[fmtpos] == '/':
				length = output.pop()
				fmtpos += 1
				if self.fmt[fmtpos] == 'a':
					output += (buffer[bufpos:bufpos+length],)
					bufpos += length
			fmtpos += 1
		return output
