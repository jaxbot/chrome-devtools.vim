" File:        chrome-devtools.vim
" Version:     0.0.1
" Description: Links VIM to the Chrome devtools for debugging
" Maintainer:  Jonathan Warner <jaxbot@gmail.com> <http://github.com/jaxbot>
" Homepage:    http://jaxbot.me/
" Repository:  https://github.com/jaxbot/chrome-devtools.vim 
" License:     Copyright (C) 2013 Jonathan Warner
"              Released under the MIT license 
"			   ======================================================================
"              

if exists("g:chrome_devtools_loaded") || &cp
    finish
endif

let g:chrome_devtools_loaded = 1

if !exists("g:chrome_debug_host") 
	let g:bl_serverpath = "http://127.0.0.1:9222"
endif

" The main logic part of the code is written in Python, because of 1)
" websockets and 2) me wanting to learn it some more. So here goes.

python <<NOMAS
import sys
import threading
import time
import vim
sys.path.append(vim.eval("expand('<sfile>:p:h')") + "/websocket_client-0.11.0-py2.7.egg")
import websocket
import json
import urllib2

class BrolinkLink(threading.Thread):

	def __init__ (self, ws):
		threading.Thread.__init__(self)
		self.ws = ws
	
	def run(self):
		def on_message(ws, message):
			for b in vim.buffers:
				if b.name == "chrome:\\\\console":
					b.append(message)
		def on_close(ws):
			if (can_close == 0):
				ws.run_forever()
		def on_open(ws):
			ws.send("{ \"id\": 5, \"method\": \"Console.enable\" }")
		def on_error(ws):
			vim.command("echo 'bl err'")
			ws.run_forever()

		ws.on_message = on_message
		ws.on_close = on_close
		ws.on_open = on_open
		ws.on_error = on_error
		ws.run_forever()

can_close = 0

#ws = websocket.WebSocketApp("ws://127.0.0.1:9001/")

def disconnect():
	can_close = 1
	ws.close()

def start_chromedevtools(guid):
	print guid
	content = urllib2.urlopen("http://localhost:9222/json").read()
	data = json.loads(content)
	for page in data:
		print page["url"]
	#ws = websocket.WebSocketApp("ws://localhost:9222/devtools/page/" + guid)
	#thread = BrolinkLink(ws)
	#thread.start()

NOMAS


function! s:Disconnect()
    if(g:bl_state == 1)
	    python disconnect()
	    let g:bl_state = 0
	endif
endfunction

function! s:Connect()
    if(g:bl_state == 0)
	    python startbrolink()
	    let g:bl_state = 1
	endif
endfunction

command!        -nargs=0 ChromeDevStart             call s:Start(<f-args>)

if !exists("g:bl_no_mappings")
    vmap <silent><Leader>be :BLEvaluateSelection<CR>
    nmap <silent><Leader>be :BLEvaluateBuffer<CR>
    nmap <silent><Leader>bf :BLEvaluateWord<CR>
    nmap <silent><Leader>br :BLReloadPage<CR>
    nmap <silent><Leader>bc :BLReloadCSS<CR>
endif

function! s:Start(guid)
	" Make a hidden buffer for chrome
	silent hide edit chrome://console
	set buftype=nofile
	silent execute "normal \<C-^>" 

	python start_chromedevtools(vim.eval("a:guid"))
endfunction

au VimLeave * :ChromeDevDisconnectAll
