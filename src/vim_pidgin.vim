if !exists ("g:python_pidgin_plugin_path")
	let g:python_pidgin_plugin_path = './pidgin_server.py'
endif

command! -nargs=? Chat call Start_Chat ()

python << EOFPython
# -*- encoding: utf-8 -*-
import os
import dbus, gobject
import thread
import time
import dbus.mainloop.glib

obj = None
reobj = None
bus = None
rebus = None

def init ():
	global obj, reobj, bus, rebus

	bus = dbus.SessionBus ()

	rebus = dbus.SessionBus ()
	obj = bus.get_object ("im.pidgin.purple.PurpleService", "/im/pidgin/purple/PurpleObject")

	try:
		reobj = rebus.get_object ("com.pidgin.service", "/PidginService")
	except dbus.DBusException:
		thread.start_new (server_thread, (None, ))
	time.sleep (0.5)
	reobj = rebus.get_object ("com.pidgin.service", "/PidginService")
	
def get_buddy_list ():
	acc_list = obj.PurpleAccountsGetAllActive ()
	buddy_list = []
	for acc in acc_list:
		buddy_list += obj.PurpleFindBuddies (acc, "")
	buddy_names = []
	for item in buddy_list:
		online = "|"
		if (obj.PurpleBuddyIsOnline (item)):
			online = "O|"
		buddy_names.append (online + obj.PurpleBuddyGetName (item))

	return buddy_names

def get_account_via_buddy_name (buddy_name):
	acc_list = obj.PurpleAccountsGetAllActive ()
	for acc in acc_list:
		if (obj.PurpleFindBuddy (acc, buddy_name)):
			return acc

	return 0

def server_thread (data):
	path = vim.eval ("g:python_pidgin_plugin_path")
	os.system ("python "+path)

def request_msg ():
	msg = reobj.retrieve_message ()
	return msg
#print msg.encode ("utf-8")

EOFPython

function! Start_Chat ()
	call Pidgin_Ready ()
	call Toggle_Buddy_List ()

	command! -nargs=? Rmsg call Retrieve_Message ()
	command! -nargs=? Blist call Toggle_Buddy_List ()
	command! -nargs=? NoChat call Stop_Chat ()

	set updatetime=1000
	autocmd! CursorHold * call Retrieve_Message ()
endfunction

function! Stop_Chat ()
autocmd! CursorHold
python << EOFPython
reobj.exit ()
EOFPython

let index = bufnr ("__Pidgin_Buddy_List__")
if (index != -1)
	exe index."bd!"
endif

let index = bufnr ("__Pidgin_Chat_Window__")
if (index != -1)
	exe index."bd!"
endif
endfunction

function! Pidgin_Ready ()
python << EOFPython
init ()
EOFPython
endfunction

function! Buddy_List_Key_Map ()
	nnoremap <silent> <buffer> <CR> :call Open_Message_Send_Window () <CR>
endfunction

function! Chat_Window_Key_Map ()
	nnoremap <silent> <buffer> <CR> :call Post_Message ()<CR>
endfunction

function! Toggle_Buddy_List ()
" The __Pidgin_Buddy_List__ buffer does not exist
let i = bufwinnr ("__Pidgin_Buddy_List__") 
if i == -1
	exe "botright 30vsplit __Pidgin_Buddy_List__"
	call Buddy_List_Key_Map ()
	setlocal nobuflisted
else
	exe i." wincmd w"
endif
python << EOFPython
buddy_names = get_buddy_list ()
index = int (vim.eval ("bufnr ('__Pidgin_Buddy_List__')")) - 1

vim.buffers[index][:] = None
for name in buddy_names:
	vim.buffers[index].append (str (name))

vim.command ("set nomodified")
EOFPython

let i = bufwinnr ("__Pidgin_Chat_Window__")
if i == -1
	exe "20split __Pidgin_Chat_Window__"
	setlocal nobuflisted
endif

endfunction


function! Retrieve_Message ()
call feedkeys ("f\e")
python<<EOFPython
msg = request_msg ()
index = int (vim.eval ("bufnr ('__Pidgin_Chat_Window__')")) - 1

if (msg != ""):
	if (index >= 0):
		msg = msg.split ('\n')
		for line in msg:
			vim.buffers[index][:] = [line.encode ("utf-8")] + vim.buffers[index][:]
	else:
		print msg.encode ("utf-8")
EOFPython
endfunction

function! Open_Message_Send_Window ()
	let name = getline ('.')
	if name == ""
		return
	endif

	let name = escape (name, '|')
	let i = bufwinnr (name)
	if i == -1
		exe "botright 10split ".name
		call Chat_Window_Key_Map ()
		setlocal nobuflisted
	else
		exe i." wincmd w"
	endif
endfunction

function! Post_Message ()
python << EOFPython
index = int (vim.eval ("bufnr('__Pidgin_Chat_Window__')")) - 1
msg = ""
buddy_name = vim.eval ("bufname('%')")
buddy_name = buddy_name.split ("|")[1]
for line in vim.current.buffer:
	vim.buffers[index][:] = ["To: " + buddy_name + " " + line] + vim.buffers[index][:]
	msg += "%s\n" % line
account = get_account_via_buddy_name (buddy_name)
conv = obj.PurpleConversationNew (1, account, buddy_name)
im = obj.PurpleConversationGetImData (conv)
obj.PurpleConvImSend (im, msg)
EOFPython
exe "bd!"
endfunction
