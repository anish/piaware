#
# fa_adept_client - open data exchange protocol server
#
# Copyright (C) 2014 FlightAware LLC, All Rights Reserved
#

package require tls

#
# logger - log a message
#
proc logger {text} {
	#::bsd::syslog log info $text
    puts stderr "[clock format [clock seconds] -format "%D %T" -gmt 1] $text"
}

#
# greetings - issue a startup message
#
proc greetings {} {
	logger "****************************************************"
	logger "piaware version $::piawareVersion is running, process ID [pid]"
	logger "your system info is: [exec /bin/uname --all]"
}

#
# user_check - require us to be run as a specific user
#
proc user_check {} {
	if {[id user] != "root"} {
		puts stderr "$::argv0 must be run as user 'root'"
		exit 4
	}
}

#
# setup_adept_client - adept client-side setup
#
proc setup_adept_client {} {
    ::fa_adept::AdeptClient adept -port $::params(serverport)

    adept connect
}

#
# load_adept_config_and_setup - load config and massage if necessary
#
proc load_adept_config_and_setup {} {
	load_adept_config

	if {[info exists ::adeptConfig(user)]} {
		set ::flightaware_user $::adeptConfig(user)
	}

	if {[info exists ::adeptConfig(password)]} {
		set ::flightaware_password $::adeptConfig(password)
	}

	return 1
}

#
# user_password_sanity_check - return 0 if either of the variables
#  flightaware_user and flightaware_password don't exist or are
#  empty, else 1.
#
proc user_password_sanity_check {} {
	foreach var "::flightaware_user ::flightaware_password" {
		if {![info exists $var]} {
			return 0
		}

		if {[set $var] == ""} {
			return 0
		}
	}

	return 1
}

#
# confirm_nonblank_user_and_password_or_die - either we have existant, non-blank
#  passwords or we die
#
proc confirm_nonblank_user_and_password_or_die {} {
	if {![user_password_sanity_check]} {
		puts stdout "FlightAware account user and password settings are empty or missing"
		puts stdout "Please run piaware-config to update"
		exit 1
	}
}

# log_stdout_stderr_to_file - redirect stdout and stderr to a log file
#
proc log_stdout_stderr_to_file {} {
	# log to /tmp/piaware.out
	set fp [open /tmp/piaware.out w]
	fconfigure $fp -buffering line
	dup $fp stdout
	dup $fp stderr
	close $fp
}

#
# create_pidfile - create a pidfile for this process if possible if so
#   configured
#
proc create_pidfile {} {
	set file $::params(p)
	if {$file == ""}  {
		return
	}

	logger "creating pidfile $file"

	set fp [open $file w]
	puts $fp [pid]
	close $fp
}

#
# remove_pidfile - remove the pidfile if it exists
#
proc remove_pidfile {} {
	set file $::params(p)
	if {$file == ""}  {
		return
	}

	logger "removing pidfile $file"
	if {[catch {file delete $file} catchResult] == 1} {
		logger "failed to remove pidfile: $catchResult, continuing..."
	}
}

#
# setup_signals - arrange for common signals to shutdown the program
#
proc setup_signals {} {
	signal trap HUP "shutdown %S"
	signal trap TERM "shutdown %S"
	signal trap INT "shutdown %S"
}

#
# shutdown - shutdown signal handler
#
proc shutdown {{reason ""}} {
	logger "shutdown signal $reason received, shutting down..."
	cleanup_and_exit
}

#
# cleanup_and_exit - stop faup1090 if it is running and remove the pidfile if
#  we created one
#
proc cleanup_and_exit {} {
	stop_faup1090
	remove_pidfile
	logger "$::argv0 is exiting..."
	exit 0
}

# vim: set ts=4 sw=4 sts=4 noet :