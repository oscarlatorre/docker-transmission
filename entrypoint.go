package main

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"syscall"
)

func init() {
	runtime.GOMAXPROCS(1)
	runtime.LockOSThread()
}

const sysSetUID = 0x69
const sysSetGID = 0x6a
const program = "/transmission-daemon"

func setuid(uid int) (err error) {
	if _, _, err := syscall.RawSyscall(sysSetUID, uintptr(uid), 0, 0); err != 0 {
		return err
	}
	return nil
}

func setgid(gid int) error {
	if _, _, err := syscall.RawSyscall(sysSetGID, uintptr(gid), 0, 0); err != 0 {
		return err
	}
	return nil
}

func getEnvInt(name string, def int) int {
	n, err := strconv.Atoi(os.Getenv(name))
	if err != nil {
		return def
	}

	return n
}

func logerr(msg string, err error) {
	fmt.Fprintf(os.Stderr, "%s: %v\n", msg, err)
}

func main() {

	// Get external uid & gid from the environment
	uid := getEnvInt("EUID", 0) // Default to root (0)
	gid := getEnvInt("EGID", 0) // Default to root (0)

	// Make sure that the files we need are accessible to the new uid
	os.Chown("/config/", uid, gid)
	os.Chown("/config/settings.json", uid, gid)
	os.Chown("/downloads/", uid, gid)

	// Change GID then UID, order matters
	if err := setgid(gid); err != nil {
		logerr("Error setting gid", err)
		os.Exit(1)
	}

	if err := setuid(uid); err != nil {
		logerr("Error setting uid", err)
		os.Exit(1)
	}

	// First argument must be the program being executed
	args := append([]string{program}, os.Args[1:]...)

	fmt.Printf("Starting %v\n", args)

	if err := syscall.Exec(program, args, os.Environ()); err != nil {
		logerr("Error during exec", err)
		os.Exit(1)
	}
}
