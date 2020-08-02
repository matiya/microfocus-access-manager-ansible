#!/bin/bash

getNtpDaemonCmd()
{
	systemctl start ntpd > /dev/null 2>&1
    echo "systemctl start ntpd"
}

addNtpDaemonService()
{
	echo "" > /dev/null 2>&1
}
IS_THIS_UPGRADE=0
checkForUpgrade()
{
	local AG_RPM_INSTALLED=`rpm -qa novell-apache-gateway`
	local DEVMAN_RPM_INSTALLED=`rpm -qa novell-devman`
	local IDP_RPM_INSTALLED=`rpm -qa novell-nidp-server`

	if [ "$DEVMAN_RPM_INSTALLED" != "" ] 
	then
		IS_THIS_UPGRADE=1
	elif [ "$IDP_RPM_INSTALLED" != "" ] 
	then
		IS_THIS_UPGRADE=1
	elif [ "$AG_RPM_INSTALLED" != "" ]
	then
		IS_THIS_UPGRADE=1
	fi
}
installRPMs()
{
    local log_file_path=$1
    if [ -z "${log_file_path}" ]
    then
        log_file_path="/dev/null"
    fi
    RPM_LIST=$2
    INSTALL_RPM_LIST_WILDCARD=$3
    local validLowerMinorVersion=0
    local validUpperMinorVersion=99
    local validMajorVersion=7
    local majorVersion=`cat /etc/redhat-release | grep release | cut -d ' ' -f 7 | cut -d '.' -f 1`
    local minorVersion=`cat /etc/redhat-release | grep release | cut -d ' ' -f 7 | cut -d '.' -f 2`
    if [ -z "${majorVersion}"  -o -z "${minorVersion}" -o "${majorVersion}" -ne "${validMajorVersion}" -o "${minorVersion}" -lt "${validLowerMinorVersion}" -o "${minorVersion}" -gt "${validUpperMinorVersion}" ]
    then
        echo "\"`cat /etc/redhat-release`\", is not a supported version of Redhat. Terminating the installation."
        exit_installer "\"`cat /etc/redhat-release`\", is not a supported version of Redhat. Terminating the installation."  "${log_file_path}" 
    fi

    checkForUpgrade
    if [ $IS_THIS_UPGRADE -eq 0 ]
    then
	echo "Installing the latest version of the following dependant rpms." | tee -a "${log_file_path}"
	echo ""  | tee -a "${log_file_path}"
	for (( i=0; i<${#RPM_LIST[@]}; i++ ))
	do
            echo "${RPM_LIST[$i]}" | tee -a "${log_file_path}"
	done
	echo ""  | tee -a "${log_file_path}"
    fi

    localisoset=0 	
    all_rpm_installed=1;
    for (( i=0; i<${#RPM_LIST[@]}; i++ ))
    do
        echo "Checking if ${RPM_LIST[$i]} or a higher version is installed" >> "${log_file_path}"
        if [[ $( yum list installed | grep -w ${RPM_LIST[$i]} ) == "" ]]
        then
            echo "${RPM_LIST[$i]} is not installed. Trying to install it from the source online catalog or local repository." | tee -a "${log_file_path}"
            echo
            if [ "${localisoset}" -ne 1 ]
            then
    		    initializeLocalRepository "${log_file_path}"
	        fi	  
            yum install -q -y ${INSTALL_RPM_LIST_WILDCARD[$i]}  >> "${log_file_path}" 2>&1
            if [ $? -ne 0 ]
            then
		        all_rpm_installed=0
                exit_installer "Installation of rpm ${RPM_LIST[$i]} failed. Check the source catalog." "${log_file_path}" 
            fi
        else
            echo "${RPM_LIST[$i]} or its higher version is already installed." >> "${log_file_path}"
        fi
    done
	if [ "${all_rpm_installed}" -ne 1 ]
	then
        echo
		echo "Install the above missing rpms and run the NAM installation again."
		exit 1;
    else
	if [ $IS_THIS_UPGRADE -eq 0 ]
	then
		throwWarningForRPMs
	fi
    fi

}
install_dependent_rpms()
{
    RPM_LIST=( "apr.x86_64" "apr-util.x86_64" "libtool-ltdl.x86_64" "unixODBC.x86_64" "libdb.x86_64" "glibc.i686" "libesmtp.x86_64" "nss-softokn-freebl.i686" "patch.x86_64" "pcre.x86_64" "rsyslog.x86_64" "rsyslog-gnutls.x86_64" "bind-utils" "net-tools" "unzip" "psmisc" "zip" "net-snmp" )
    INSTALL_RPM_LIST_WILDCARD=( "apr*x86_64" "apr-util*x86_64" "libtool-ltdl*x86_64" "unixODBC*x86_64" "libdb*x86_64" "glibc*i686" "libesmtp*x86_64" "nss-softokn-freebl*i686" "patch*x86_64" "pcre*x86_64" "rsyslog*x86_64" "rsyslog-gnutls*x86_64" "bind-utils*x86_64" "net-tools*x86_64" "unzip*x86_64" "psmisc*x86_64" "zip*x86_64" "net-snmp*x86_64" )
    if [ -z $1 ]
    then
        logfile=""
    else
        logfile=$1
    fi
    installRPMs $logfile $RPM_LIST $INSTALL_RPM_LIST_WILDCARD

    if [ ! -f /lib64/libdb-4.5.so ]
    then
        ln -s /lib64/libdb-5.3.so /lib64/libdb-4.5.so 
    fi
    if [ ! -f /usr/lib64/libodbc.so.1 ]
    then
        ln -s /usr/lib64/libodbc.so.2.0.0 /usr/lib64/libodbc.so.1
    fi
    if [ ! -f /usr/lib64/libpcre.so.0 ]
    then
    	ln -s /usr/lib64/libpcre.so.1.2.0 /usr/lib64/libpcre.so.0	
	fi
    if [ ! -f /usr/lib64/libesmtp.so.5 ]
    then
    	ln -s /usr/lib64/libesmtp.so.6.1.6 /usr/lib64/libesmtp.so.5
    fi
    ldconfig
}

restartSyslog(){
	systemctl restart rsyslog > /dev/null 2>&1
}

registerServicesAC(){
	cp scripts/rhel_files/novell-ac.service /etc/systemd/system/
	cp scripts/rhel_files/novell-snmpd.service /etc/systemd/system/
	systemctl daemon-reload > /dev/null 2>&1
	systemctl enable novell-ac.service > /dev/null 2>&1
	systemctl enable novell-snmpd.service > /dev/null 2>&1
	systemctl start novell-snmpd.service > /dev/null 2>&1
}

registerServicesIDP(){
	cp scripts/rhel_files/novell-jcc.service /etc/systemd/system/
	cp scripts/rhel_files/novell-idp.service /etc/systemd/system/
	systemctl daemon-reload > /dev/null 2>&1
	systemctl enable novell-jcc.service > /dev/null 2>&1
	systemctl enable novell-idp.service > /dev/null 2>&1
}

registerServicesMAG(){
	cp scripts/rhel_files/*.service /etc/systemd/system/
	systemctl daemon-reload > /dev/null 2>&1
	systemctl enable novell-activemq.service > /dev/null 2>&1
	systemctl enable novell-apache2.service > /dev/null 2>&1
	systemctl enable novell-agscd.service > /dev/null 2>&1
	systemctl enable novell-jcc.service > /dev/null 2>&1
	systemctl enable novell-mag.service > /dev/null 2>&1
}
