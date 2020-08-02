#!/bin/bash 
#!/bin/bash -xf

##############################################################################
#
# Novell Access Manager (Single Box) Umbrella Installer
#
# common/pre_install.sh
#
# @Begin
#
# This script is called by the umbrella installer. 
#
# This script will perform the following checks :
# - ntp is running
# - dependent rpms are running
# - required input parameters have been provided
# - check the memory contraints
#
# @End
#
##############################################################################

#Declare all default/global variables here. These variables can be overridden
# by the derivied install classes

#Initialize the log directory and log files
INST_TIME=`date +"%F_%T"`
export INST_TIME
export INST_LOG_DIR="/tmp/novell_access_manager"
export MAIN_INSTALL_LOG="${INST_LOG_DIR}/install_main_${INST_TIME}.log"

#Minimum memory required for installing
REQUIRED_MIN_MEM=1800
RECOMMENDED_MIN_MEM=3800

#Minimum disk space required in various directories for installing
DIRS_TO_CHECK=( "/opt/novell" "/opt/volera" "/var/opt/novell" "/var" "/usr" "/etc" "/tmp/novell_access_manager" "/tmp" "/")
#               1GB             5MB         1GB                 512MB  25MB 1MB     10MB                        10MB   512MB
SPACE_NEEDED=( "1073741824" "5242880" "1073741824" "536870912" "26214400" "1048576" "10485760" "10485760" "536870912" )

# List the packages required for install program. 
#   This list can be appended by subsequent pre_install scripts
#   REQUIRED_PKGS="${REQUIRED_PKGS} newpkg"
REQUIRED_PKGS=`echo {\
python,\
curl\
}`

#Generate an unique id and name that will be used for installing components
date '+%N' > /dev/urandom
if [ -z "$UNIQUE_ID" ]
then
    export UNIQUE_ID=`head -c8 /dev/urandom | od -An -tx8 | tr -d "[:space:]" | tr "[:lower:]" "[:upper:]"`
fi

# Discover values from the system
export UNIQUE_NAME=`uname -n |cut -d '.' -f 1 | sed -e "s/[^[:alnum:]]/_/g"`
export XMLMOD="${SCRIPT_DIR}/utils/xmlmod"


#------------------------------------------------------------------
# Setup Install Logger
#------------------------------------------------------------------
setup_install_log_dir()
{
	exit_unless_create_directory ${INST_LOG_DIR}
	backup_log_files #TODO After unit-testing, can remove the following lines of backing up the logs

}


#------------------------------------------------------------------
# Back up log files if present
#------------------------------------------------------------------
backup_log_files()
{
	if mkdir -p "${INST_LOG_DIR}/backup" > /dev/null 2>&1
	then
		mv "${INST_LOG_DIR}"/*.log "${INST_LOG_DIR}/backup/" > /dev/null 2>&1
	fi
}


# Checks to make sure the local hostname is resolvable
verify_hostname_resolution()
{
	echo "Verifying hostname resolution..." 
        # Validate the hostname and make sure it is resolvable
        HOSTNAME_RETRY_COUNT=0
        HOSTNAME_NOT_SET=0

        while [ "$HOSTNAME_NOT_SET" -eq 0 ]
        do
            HOSTNAME_ERROR_MSG=""
            sleep 2

           #check for host name
            if [ -e "/etc/HOSTNAME" ]
              then
                 hostname=`sed -n 1p /etc/HOSTNAME`
              else
                 hostname=`/bin/hostname`
            fi

            if [ -z $hostname ]
            then
                # if /etc/HOSTNAME file is empty, try reading the environment variable
                if [ ! -z $HOSTNAME ]
                then
                    hostname=$HOSTNAME
                else
                    HOSTNAME_ERROR_MSG="Hostname is not set. Set the hostname in YaST"
                fi
            fi

            echo "hostname = $hostname"

            if [ ! -z $hostname ]
            then
                #check for default hostname
                # Edirectory installation fails sometimes if hostname is linux
                if [ $hostname == "linux" ]
                then
                	HOSTNAME_ERROR_MSG="Default Hostname set. Set the hostname in YaST"
               	fi

                #check for resolution
                ping -c 1 ${hostname} >>/tmp/out.txt 2>&1

                if [ $? -ne 0 ]
                then
                    HOSTNAME_ERROR_MSG="Hostname cannot be resolved. Set host entry in YaST"
                fi
                rm /tmp/out.txt
            fi
            if [ -z "$HOSTNAME_ERROR_MSG" ]
            then
                echo "Hostname validation succeeded."
                HOSTNAME_NOT_SET=1
            fi

            HOSTNAME_RETRY_COUNT=$(( ${HOSTNAME_RETRY_COUNT} + 1 ))
            if [ ${HOSTNAME_RETRY_COUNT} -gt 10 ]
            then
                echo "$HOSTNAME_ERROR_MSG"
                exit 1
            fi
        done
	echo 
}

verify_hostname_length()
{
	local ip_addr=$1
	local log_file=$2
	echo "Verifiying the hostname length for ${ip_addr}..." >> "${log_file}" 2>&1
	
	local ip_hostname=""
	if host "${ip_addr}" > /dev/null 2>&1
	then
		ip_hostname=`host "${ip_addr}" | tail -n1 | awk '{print $5}'`
		#TODO What if the host name value could not be obtained
		if [ -z ${ip_hostname} ]
		then
			echo "Could not get hostname using 'host' command. Continuing... " >> "${log_file}" 2>&1
			return
		elif [ ${#ip_hostname} -gt 54 ]
		then
			exit_installer "The hostname for the IP address $ip_addr has been identified via Domain Name Services as "$ip_hostname", which will not work as it exceeds the 54 character limit. A long hostname can cause problems during the creation of encryption certificates. use a shorter hostname before proceeding with the installation." "${log_file}"
		fi
	fi
	echo "Hostname $ip_hostname is valid" >> "${log_file}" 2>&1
}


# Find and run ntpdate
# First, is ntpq available?
# TODO , check if this can be customized for Singlebox
check_ntp()
{
	echo "Starting ntp daemon..." 
	addNtpDaemonService 
	NTPQ_CMD="`which ntpq 2>/dev/null`"
	NTPDATE_CMD="`which ntpdate 2>/dev/null`"
	NTPDAEMON_CMD=""
	NTPDAEMON_CMD=$(getNtpDaemonCmd)
	NTPSTARTUP_COUNT=0

	if [ -z "$NTPQ_CMD" -o -z "$NTPDATE_CMD" -o -z "$NTPDAEMON_CMD" ]
	then
        	echo
        	echo "The necessary package xntp has not been installed. The Access Manager requires the tools provided by xntp for time synchronization. Install NTP tools and run this installer again."
        	echo "Terminating the installation."
        	echo
        	# exit 1
	fi

	while [ ! -z "`$NTPQ_CMD -pn 2>&1 | sed -ne 's/.*\(connection refused\).*/\1/ip'`" ]
	do
        	if [ $NTPSTARTUP_COUNT -gt 0 ]
        	then
                	echo
                	echo "The NTP daemon is not working. Fix the problem with the NTP tools and run this installer again."
                	echo "gettext 'Terminating the installation."
                	echo
                	# exit 1
        	fi
        	let 'NTPSTARTUP_COUNT++'

        	${NTPDAEMON_CMD} start > /dev/null 2>&1
        	# Give NTP a second to start up
        	sleep 1
            break
	done
	if [ $NTPSTARTUP_COUNT -gt 0 ]
	then
       		echo
        	echo "The installer has started the NTP daemon. It made no effort to determine if the NTP configuration is correct. The Access Manager may not work if the NTP configuration is invalid. Ensure that the NTP configuration is correct before continuing this installation."
        	echo
        	#read -es -p "`gettext 'PRESS ENTER TO CONTINUE:'`"
        	echo
	fi

	${NTPDATE_CMD} "pool.ntp.org" >> /dev/null 2>&1
}

#put a cron job to sync time with ntp every 5 minutes
#Refer http://www.novell.com/support/php/search.do?cmd=displayKC&docType=kc&externalId=7002468&sliceId=2&docTypeID=DT_TID_1_1&dialogID=282892144&stateId=0%200%20282890657
updateCron(){
    local log_file_path=$1
    if [ -z "${log_file_path}" -o ! -f  "${log_file_path}" ]
    then
        log_file_path="/dev/null"
	fi
    grep "/usr/sbin/sntp" /etc/crontab >> "${log_file_path}" 2>&1
    if [ $? -ne 0 ]
    then
            echo "*/5 * * * * root /usr/sbin/sntp -P no -r ${NTPSERVER} >/dev/null 2>&1" >>/etc/crontab
    fi
    /etc/init.d/cron restart >> "${log_file_path}" 2>&1
}

pre_install_upgrade()
{
        exit_unless_root
        exit_unless_granted_perm

        export MAIN_INSTALL_LOG="${INST_LOG_DIR}/upgrade_main_${INST_TIME}.log"

        setup_install_log_dir
        start_logger "${MAIN_INSTALL_LOG}"

#        install_dependent_rpms

        exit_if_not_enough_memory "${REQUIRED_MIN_MEM}" "${MAIN_INSTALL_LOG}" "${RECOMMENDED_MIN_MEM}"
        exit_if_not_enough_diskspace "${MAIN_INSTALL_LOG}"
        exit_if_binaries_missing "${REQUIRED_PKGS}" "${MAIN_INSTALL_LOG}"
	
	checkEtcLocalhostEntry
	verifyHostnameResolution "${MAIN_INSTALL_LOG}"
	checkEtcHostEntry
}


pre_install()
{
	exit_unless_root
	exit_unless_granted_perm

	setup_install_log_dir
	start_logger "${MAIN_INSTALL_LOG}"

	install_dependent_rpms "${MAIN_INSTALL_LOG}"

	exit_if_not_enough_memory "${REQUIRED_MIN_MEM}" "${MAIN_INSTALL_LOG}" "${RECOMMENDED_MIN_MEM}"
	exit_if_not_enough_diskspace "${MAIN_INSTALL_LOG}"
	exit_if_binaries_missing "${REQUIRED_PKGS}" "${MAIN_INSTALL_LOG}"

#	echo "todo-verify hostname"
        #verify_hostname_resolution

# TODO	echo "todo-warn about missing rpms"
        # Detect Optional missing rpms
        # Detect Graphics Library
        # check_missing_optional_rpm "xorg-x11-libs" "Notice: The xorg-x11-libs rpm is not installed on your system. Until it is installed, the Statistics Graphing feature will be disabled."

#	echo "todo-warn about conflicting rpms"
        # Detect dependencies
        # Detect openLDAP
        # check_conflicting_optional_rpm "openldap2" "OpenLDAP v2 has been detected on this system. This conflicts with the configuration store, which is necessary for this install. Continuing the unsupported installation."

        # check_ntp
}

checkMemory()
{

MEMPROMPT='n'
PHYS_MEM_AVAIL=`free -m | awk '/^Mem/ {print $2}'`
if [ ${PHYS_MEM_AVAIL} -gt ${REQUIRED_MIN_MEM} -a ${PHYS_MEM_AVAIL} -lt ${RECOMMENDED_MIN_MEM} ]
then
	echo 
	echo_text "`eval_gettext 'The system has $PHYS_MEM_AVAIL MB of memory.'`"
	echo_text "`eval_gettext 'WARNING: This computer reports ${PHYS_MEM_AVAIL} MB of memory and does not meet the recommended minimum of $RECOMMENDED_MIN_MEM MBs. You may continue, but Access Manager may not function properly on this computer until all recommendations are met.'`"	
	read -e -p "`eval_gettext 'Would you like to continue (y/n) ? [$MEMPROMPT]:'`" MEMPROMPT

		if [ -z "${MEMPROMPT}" ]; then MEMPROMPT='n'; fi
		if [ "${MEMPROMPT}" != 'y' -a "${MEMPROMPT}" != 'Y' ]
		then
			echo
			echo_text "`gettext 'Terminating the installation...'`"
			echo
			exit 1
		fi
elif [ ${PHYS_MEM_AVAIL} -lt ${REQUIRED_MIN_MEM} ]
then
	echo_text "`eval_gettext 'The system has $PHYS_MEM_AVAIL MB of memory. Upgrade the memory to at least $REQUIRED_MIN_MEM MB.'`"
	echo_text "`gettext 'Terminating the installation...'`"
	echo
	exit 1
fi

}

