" File:        chrome-devtools.vim
" Version:     0.0.1
" Description: Links VIM to the Chrome devtools for debugging
" Maintainer:  Jonathan Warner <jaxbot@gmail.com> <http://github.com/jaxbot>
" Homepage:    http://jaxbot.me/
" Repository:  https://github.com/jaxbot/chrome-devtools.vim 
" License:     Copyright (C) 2014 Jonathan Warner
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
			messagestr = ""
			if data["method"] == "Console.messageAdded":
				string = data["params"]["message"]["text"]
				line = data["params"]["message"]["line"]
				time = data["params"]["message"]["timestamp"]
				url = data["params"]["message"]["url"]

				messagestr = str(time) + ": " + string + " (" + url + "):" + str(line)

				ws.send("{ \"id\": 6, \"method\": \"Console.clearMessages\" }")
			if data["method"] == "Network.responseReceived":
				url = data["params"]["response"]["url"]
				time = data["params"]["response"]["timestamp"]
				status = data["params"]["response"]["status"]

				messagestr = str(time) + ": " + str(status) + " " + url

			if messagestr != "":
				for b in vim.buffers:
					if b.name == "chrome:\\\\console\\"+self.guid:
						b.append(messagestr)
		def on_close(ws):
			if can_close == 1:
				ws.run_forever()
		def on_open(ws):
			ws.send("{ \"id\": 5, \"method\": \"Console.enable\" }")
			# not implemented yet
			#ws.send("{ \"id\": 7, \"method\": \"Network.enable\" }")

		self.ws.on_message = on_message
		self.ws.on_close = on_close
		self.ws.on_open = on_open
		self.ws.run_forever()

can_close = 0

cachedTabData = ""

def disconnect():
	can_close = 1

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

def chromedevtools_choosetab(linestr):
	global cachedTabData

	data = json.loads(cachedTabData)

	for page in data:
		if page["title"] + " : " + page["url"] == linestr:
			url = page["webSocketDebuggerUrl"]
			guid = page["id"]
			break
	
	lws = websocket.WebSocketApp(url)
	lthread = ChromeDevThread(lws,page["id"])
	lthread.start()

	vim.eval("s:MakeConsoleBuffer('" + page["id"] + "')")

NOMAS

command! -nargs=0 ChromeDev call s:Start()
command! ChromeDevSelectTab call s:SelectTab()
command! ChromeDevDisconnectAll call s:Disconnect()

function! s:Start()
	" Make a hidden buffer for chrome
	silent hide edit chrome://tablist
	set buftype=nofile
	" erase old contents
	normal ggdG
	nnoremap <buffer> <cr> :ChromeDevSelectTab<cr>

	python chromedevtools_tablist()
endfunction

function! s:Disconnect()
	python disconnect()
endfunction

function! s:SelectTab()
	python chromedevtools_choosetab(vim.eval("getline('.')"))
endfunction

function! s:MakeConsoleBuffer(id)
	silent hide execute 'edit' "chrome://console/" . a:id
	set buftype=nofile
endfunction

au VimLeave * :ChromeDevDisconnectAll

