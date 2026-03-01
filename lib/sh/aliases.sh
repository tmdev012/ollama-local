#!/bin/bash
# aliases.sh — Single source of all sashi shell aliases
# Source from .bashrc / .zshrc:  source ~/ollama-local/lib/sh/aliases.sh
# sashi v3.2.3

_SASHI_DIR="${_SASHI_DIR:-$HOME/ollama-local}"

# ── Core sashi shortcuts ──────────────────────────────────────────────
alias s='$_SASHI_DIR/sashi'
alias sask='$_SASHI_DIR/sashi ask'
alias scode='$_SASHI_DIR/sashi code'
alias slocal='$_SASHI_DIR/sashi local'
alias schat='$_SASHI_DIR/sashi chat'
alias sstatus='$_SASHI_DIR/sashi status'
alias shistory='$_SASHI_DIR/sashi history'
alias smodels='$_SASHI_DIR/sashi models'
alias schangelog='$_SASHI_DIR/sashi changelog'
alias sgmail='$_SASHI_DIR/sashi gmail'
alias skanban='$_SASHI_DIR/sashi kanban board'

# ── Online / cloud ────────────────────────────────────────────────────
alias sonline='$_SASHI_DIR/sashi online'
alias scloud='$_SASHI_DIR/sashi cloud'
alias shf='$_SASHI_DIR/sashi hf'

# ── 8B model ──────────────────────────────────────────────────────────
alias s8b='$_SASHI_DIR/sashi 8b'

# ── USB / WiFi debugging ──────────────────────────────────────────────
# bare commands (what the user types directly)
alias usb='$_SASHI_DIR/sashi usb'
alias wifi='$_SASHI_DIR/sashi wifi'
alias hf='$_SASHI_DIR/sashi hf'
alias android-studio='$_SASHI_DIR/sashi android-studio'
# subcommand shortcuts
alias usb-scan='$_SASHI_DIR/sashi usb scan'
alias usb-watch='$_SASHI_DIR/sashi usb watch'
alias usb-storage='$_SASHI_DIR/sashi usb storage'
alias wifi-init='$_SASHI_DIR/sashi wifi init'
alias wifi-connect='$_SASHI_DIR/sashi wifi connect'
alias wifi-scan='$_SASHI_DIR/sashi wifi scan'
alias wifi-status='$_SASHI_DIR/sashi wifi status'
alias wifi-logcat='$_SASHI_DIR/sashi wifi logcat'

# ── ADB shortcuts ─────────────────────────────────────────────────────
alias sadb='$_SASHI_DIR/sashi adb'
alias sdev='$_SASHI_DIR/sashi adb devices'
alias slogcat='$_SASHI_DIR/sashi adb logcat'

# ── gRPC ──────────────────────────────────────────────────────────────
alias sgrpc='$_SASHI_DIR/sashi grpc'
alias sgrpc-start='$_SASHI_DIR/sashi grpc start'
alias sgrpc-status='$_SASHI_DIR/sashi grpc status'
alias sprobe='$_SASHI_DIR/sashi probe'
alias sprobe-list='$_SASHI_DIR/sashi probe list'
alias sprobe-sync='$_SASHI_DIR/sashi probe sync'

# ── Ollama control ────────────────────────────────────────────────────
alias ollama-up='ollama serve &>/dev/null &'
alias ollama-down='pkill -f "ollama serve" 2>/dev/null; echo "Ollama stopped"'
alias ollama-restart='ollama-down; sleep 1; ollama-up; echo "Ollama restarted"'
alias ollama-logs='journalctl -u ollama -f 2>/dev/null || tail -f /tmp/ollama*.log 2>/dev/null'
alias ollama-boost='bash $_SASHI_DIR/scripts/ollama-boost.sh'

# ── Navigation ────────────────────────────────────────────────────────
alias cds='cd $_SASHI_DIR'
alias cdp='cd $HOME/persist-memory-probe'
alias cdk='cd $HOME/kanban-pmo'
alias cdf='cd $HOME/football-telemetry'

# ── Smart push ────────────────────────────────────────────────────────
alias smartpush='bash $_SASHI_DIR/scripts/smart-push.sh'
alias sp='bash $_SASHI_DIR/scripts/smart-push.sh'
alias gpush='bash $_SASHI_DIR/scripts/smart-push.sh'

# ── Git shortcuts ─────────────────────────────────────────────────────
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline -20'
alias gla='git log --all --graph --oneline -30'
alias ga='git add'
alias gaa='git add -A'
alias gap='git add -p'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'
alias gco='git checkout'

# ── Quick AI shortcuts ────────────────────────────────────────────────
alias ai='$_SASHI_DIR/sashi ask'
alias aihelp='$_SASHI_DIR/sashi help'

# ── IDE ───────────────────────────────────────────────────────────────
alias side='$_SASHI_DIR/sashi android-studio'


# ── Advanced Filesystem — Find & Filter ──────────────────────────────
alias ff='find . -type f -name'                        # ff "*.log"
alias ffd='find . -type d -name'                       # ffd "build*"
alias ffl='find . -type l'                             # list all symlinks
alias fmod='find . -type f -mmin'                      # fmod -60 (last 60 min)
alias fsize='find . -type f -size'                     # fsize +100M
alias fnew='find . -type f -newer'                     # fnew ref-file
alias fdup='find . ! -empty -type f -exec md5sum {} + | sort | uniq -w32 -dD'  # find duplicates
alias fempty='find . -type f -empty'                   # find zero-byte files
alias fdangling='find . -type l ! -exec test -e {} \; -print'  # broken symlinks

# ── Advanced Filesystem — Disk Analysis ──────────────────────────────
alias duh='du -sh * 2>/dev/null | sort -rh'            # sizes sorted, current dir
alias dua='du -ah --max-depth=1 2>/dev/null | sort -rh' # all entries depth 1
alias dut='du -sh */ 2>/dev/null | sort -rh'           # dirs only, sorted
alias dfh='df -hT --exclude-type=tmpfs --exclude-type=devtmpfs'  # real disks only
alias dfio='df -i'                                     # inode usage

# ── Advanced Filesystem — Directory Listing ───────────────────────────
alias lsl='ls -lahF --color=always'                    # full listing
alias lst='ls -lath --color=always'                    # sorted by modified time
alias lsz='ls -laSh --color=always'                    # sorted by size desc
alias lsd='ls -lah --group-directories-first --color=always'  # dirs first
alias lsr='ls -lahR --color=always'                    # recursive listing

# ── Advanced Filesystem — Archive Operations ──────────────────────────
alias tarc='tar -czf'                                  # tarc out.tar.gz dir/
alias tarx='tar -xzf'                                  # tarx archive.tar.gz
alias tarxv='tar -xzvf'                                # extract verbose
alias tarl='tar -tzf'                                  # list contents
alias tarbz='tar -cjf'                                 # bzip2 compress
alias zipr='zip -r'                                    # zip recursively

# ── Advanced Filesystem — Copy / Move / Delete ────────────────────────
alias cpv='rsync -ah --progress'                       # cp with progress bar
alias cpvr='rsync -ahr --progress --delete'            # mirror dir with progress
alias mvv='mv -v'                                      # move verbose
alias rmv='rm -iv'                                     # rm interactive + verbose
alias rmrf='rm -rf'                                    # rm -rf (explicit intent)

# ── Advanced Filesystem — Permissions & Ownership ─────────────────────
alias chmodr='chmod -R'                                # recursive chmod
alias chownr='chown -R'                                # recursive chown
alias mkexec='chmod +x'                                # make file executable
alias fixperms='find . -type f -exec chmod 644 {} \; && find . -type d -exec chmod 755 {} \;'

# ── Advanced Filesystem — Symlink Management ──────────────────────────
alias lnr='ln -sr'                                     # create relative symlink
alias lna='ln -sf'                                     # create/force absolute symlink
alias lslinks='find . -type l -exec ls -lah {} \;'    # show all symlinks + targets

# ── Advanced Filesystem — Checksum & Compare ─────────────────────────
alias fhash='sha256sum'                                # hash a file
alias fcheck='sha256sum -c'                            # verify checksum file
alias mdiff='diff -rq'                                 # compare two directories
alias mdiffu='diff -ru'                                # unified diff of dirs

# ── Advanced Filesystem — Watch & Monitor ────────────────────────────
alias fwatch='watch -n1 "ls -lah"'                    # watch dir listing every 1s
alias fwatchp='inotifywait -rm -e modify,create,delete,move'  # inotify on path

# ── Sashi WAL log ─────────────────────────────────────────────────────
alias swallog='$_SASHI_DIR/sashi wallog'               # Modelfile ↔ SQL WAL changelog


# ── Sashi LLM Write System (v3.2.3) ───────────────────────────────────
alias swrite='$_SASHI_DIR/sashi write'                          # prompt → file
alias swrite-read='$_SASHI_DIR/sashi write --read'              # file → llama → file
alias swrite-append='$_SASHI_DIR/sashi write --append'          # append AI output
alias swrite-batch='$_SASHI_DIR/sashi write --batch'            # batch process files
alias swrite-json='$_SASHI_DIR/sashi write --fmt json'          # validated JSON output
alias swrite-csv='$_SASHI_DIR/sashi write --fmt csv'            # validated CSV output
alias swrite-md='$_SASHI_DIR/sashi write --fmt md'              # markdown output
alias swrite-sh='$_SASHI_DIR/sashi write --fmt sh'              # bash script output
alias swrite-safe='$_SASHI_DIR/sashi write --safe'              # retry with fallback
alias swrite-pipe='$_SASHI_DIR/sashi write --pipe'              # cat file | swrite-pipe

# ── Sashi File Operations (v3.2.3) ────────────────────────────────────
alias sfile='$_SASHI_DIR/sashi file'                   # file ops root
alias sfile-info='$_SASHI_DIR/sashi file info'         # full info card
alias sfile-detect='$_SASHI_DIR/sashi file detect'     # detect op-type + size class
alias sfile-check='$_SASHI_DIR/sashi file check'       # integrity/corrupt check
alias sfile-read='$_SASHI_DIR/sashi file read'         # size-aware read
alias sfile-write='$_SASHI_DIR/sashi file write'       # atomic write
alias sfile-append='$_SASHI_DIR/sashi file append'     # flock-safe append
alias sfile-parse='$_SASHI_DIR/sashi file parse'       # csv/json/jsonl/text
alias sfile-copy='$_SASHI_DIR/sashi file copy'         # rsync + sha256 verify
alias sfile-move='$_SASHI_DIR/sashi file move'         # cross-device safe move
alias sfile-delete='$_SASHI_DIR/sashi file delete'     # trash-first delete
alias sfile-batch='$_SASHI_DIR/sashi file batch'       # parallel batch ops
alias sfile-recover='$_SASHI_DIR/sashi file recover'   # backup|git|truncate recovery
alias sfile-stream='$_SASHI_DIR/sashi file stream'     # real-time tail -f
alias sfile-split='$_SASHI_DIR/sashi file split'       # split large files
alias sfile-join='$_SASHI_DIR/sashi file join'         # join split parts
alias sfile-rotate='$_SASHI_DIR/sashi file rotate'     # log rotation

export _SASHI_DIR
