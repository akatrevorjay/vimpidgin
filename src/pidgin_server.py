# -*- encoding: utf-8 -*-
import re
import gobject
import dbus
import dbus.service
import dbus.mainloop.glib

class PidginServer (dbus.service.Object):
	def __init__ (self, session_bus, path):
		self.string = ""

		dbus.service.Object.__init__ (self, session_bus, path)
		session_bus.add_signal_receiver (self.message_received, 
				dbus_interface = "im.pidgin.purple.PurpleInterface",
				signal_name = "ReceivedImMsg")

	@dbus.service.method ("com.pidgin.service", 
			in_signature='', out_signature='s')
	def retrieve_message (self):
		tmp = self.string;
		self.string = ""
		return tmp.encode ("utf-8")

	@dbus.service.method ("com.pidgin.service",
			in_signature='', out_signature='')
	def exit (self):
		mainloop.quit ()

	def message_received (self, account, sender, message, conversation, flags):
		tmp = "%s said: %s\n" % (sender, message)
		tmp = re.sub ("<.*?>", "", tmp)
		self.string += tmp
		

if __name__ == "__main__":
	dbus.mainloop.glib.DBusGMainLoop (set_as_default=True)
	session_bus = dbus.SessionBus ()
	name = dbus.service.BusName ("com.pidgin.service", session_bus)
	object = PidginServer (session_bus, '/PidginService')
	mainloop = gobject.MainLoop ()
	mainloop.run ()
