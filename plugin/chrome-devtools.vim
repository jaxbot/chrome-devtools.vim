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

class ChromeDevThread(threading.Thread):
	def __init__ (self, ws, guid):
		threading.Thread.__init__(self)
		self.ws = ws
		self.guid = guid
	
	def run(self):
		def on_message(ws, message):
			data = json.loads(message)
			if data["method"] == "Console.messageAdded":
				#string = data["params"]["message"]["text"]
				#line = data["params"]["message"]["line"]
				#time = data["params"]["message"]["timestamp"]
				#url = data["params"]["message"]["url"]

				messagestr = ": " + string + " (" + url + ":" + line + ")"
				#print messagestr

				for b in vim.buffers:
					#print b.name
					if b.name == "chrome:\\\\console\\"+self.guid:
						b.append(message)
				ws.send("{ \"id\": 6, \"method\": \"Console.clearMessages\" }")
		def on_close(ws):
			print "clonne"
			if (can_close == 0):
				ws.run_forever()
		def on_open(ws):
			print "conne"
			ws.send("{ \"id\": 5, \"method\": \"Console.enable\" }")
		def on_error(ws):
			vim.command("echo 'bl err'")
			ws.run_forever()

		self.ws.on_message = on_message
		#ws.on_close = on_close
		self.ws.on_open = on_open
		#ws.on_error = on_error
		self.ws.run_forever()

can_close = 0

#ws = websocket.WebSocketApp("ws://127.0.0.1:9001/")

cachedTabData = ""

def disconnect():
	can_close = 1
	ws.close()

def chromedevtools_tablist():
	global cachedTabData
	buf = 0
	for b in vim.buffers:
		if b.name == "chrome:\\\\tablist":
			buf = b
	content = urllib2.urlopen("http://localhost:9222/json").read()
	data = json.loads(content)
	for page in data:
		buf.append(page["title"] + " : " + page["url"])
	
	cachedTabData = content
	#ws = websocket.WebSocketApp("ws://localhost:9222/devtools/page/3C2ECC59-D3E7-44C9-9569-A5DAA89DB130")
	#thread = ChromeDevThread(ws)
	#thread.start()

def chromedevtools_choosetab(linestr):
	global cachedTabData
	print linestr

	data = json.loads(cachedTabData)

	for page in data:
		if page["title"] + " : " + page["url"] == linestr:
			print "Found GUID=" + page["id"]
			url = page["webSocketDebuggerUrl"]
			guid = page["id"]
			break
	
	print url
	lws = websocket.WebSocketApp(url)
	lthread = ChromeDevThread(lws,page["id"])
	lthread.start()

	vim.eval("s:MakeConsoleBuffer('" + page["id"] + "')")

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

command!        -nargs=0 ChromeDevStart             call s:Start()
command! ChromeDevChooseTab             call s:ChooseTab()

if !exists("g:bl_no_mappings")
    vmap <silent><Leader>be :BLEvaluateSelection<CR>
    nmap <silent><Leader>be :BLEvaluateBuffer<CR>
    nmap <silent><Leader>bf :BLEvaluateWord<CR>
    nmap <silent><Leader>br :BLReloadPage<CR>
    nmap <silent><Leader>bc :BLReloadCSS<CR>
endif

function! s:Start()
	" Make a hidden buffer for chrome
	silent hide edit chrome://tablist
	set buftype=nofile
	nnoremap <buffer> <cr> :ChromeDevChooseTab<cr>

	python chromedevtools_tablist()
endfunction

function! s:ChooseTab()
	python chromedevtools_choosetab(vim.eval("getline('.')"))
endfunction

function! s:MakeConsoleBuffer(id)
	silent hide execute 'edit' "chrome://console/" . a:id
	set buftype=nofile
	"silent execute "normal \<C-^>" 
endfunction

au VimLeave * :ChromeDevDisconnectAll
