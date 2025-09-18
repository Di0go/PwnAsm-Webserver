# WebServer (x86-64 assembly) — pwn.college web server assembly module

A tiny educational web server written in x86-64 Linux assembly (Intel syntax).  
Created as a learning/exercise piece for the pwn.college web server assembly module.

## Repository layout
```
├── build.sh
├── src/
│ └── webserver.s
└── bin/
│ └── obj/
```

*(Note that bin/ and bin/obj will automatically be created when running the build.sh script)*

## What it does
- Implements a minimal TCP server that `accept()`s connections and forks for each connection.
- Performs a very small HTTP parsing to detect `GET` vs `POST`.
  - `GET /path` → opens the file at `/path` and returns its contents preceded by `HTTP/1.0 200 OK\r\n\r\n`.
  - `POST /path` → extracts the HTTP message body and writes it into the file at `/path`, then responds `200 OK`.
- Intended for hands-on learning: syscalls, sockets, forking, manual HTTP parsing, buffer management.

> **Important:** This project is intentionally minimal and insecure, I built it out of curiosity about how things really
work behind the curtains.

---

## Building

This repo contains a simple `build.sh`. It expects `as`/`ld` (GNU binutils) on a Linux x86_64 host.

```bash
chmod +x build.sh
./build.sh
```
