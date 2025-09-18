#!/bin/bash

BIN_PATH="bin/"

if [ ! -d "$BIN_PATH" ]; then
	mkdir bin/
	mkdir bin/obj/
fi

as -o bin/obj/webserver.o src/webserver.s && ld -o bin/WebServer bin/obj/webserver.o
