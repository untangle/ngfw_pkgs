#! /bin/bash

XTERM="urxvt"
DIALOG="/usr/bin/zenity"
OEM_NAME="Untangle"

if [ -f /etc/untangle/oem/oem.sh ] ; then
    source /etc/untangle/oem/oem.sh
fi

if sudo grep -qE '^root:(\*|YKN4WuGxhHpIw|$1$3kRMklXp$W/hDwKvL8GFi5Vdo3jtKC\.|CHANGEME):' /etc/shadow ; then
    tempfilePassword=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
    tempfileConfirmPassword=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
    trap "rm -f $tempfilePassword" 0 1 2 5 15  
    trap "rm -f $tempfileConfirmPassword" 0 1 2 5 15  
    
    ##
    ## Password
    ##
    $DIALOG \
        --entry \
        --title "Set a password" \
        --hide-text \
        --text \
"This is the first time accessing the terminal on this system.
A password needs to be set for the super-user (root) account.

Please choose a password that is not easily guessed,
especially if you plan on enabling ssh access to the system.

After you click Ok, you'll be asked to confirm the password you've typed here.
 
Password"  \
        --entry "Password" \
        > $tempfilePassword

    if [ $? -ne 0 ] ; then
        # Cancel Pressed
        $DIALOG \
            --info \
            --title "Cancelled" \
            --text "The setting of the password was cancelled." 
        exit
    fi
        
    ##
    ## Confirm Password
    ##
    $DIALOG \
        --entry \
        --title "Confirm password" \
        --hide-text \
        --text \
"Type the same password you previously specified to confirm it.
 
Confirm Password"  \
        --entry "Password" \
        > $tempfileConfirmPassword
        
    if [ $? -ne 0 ] ; then
        # Cancel Pressed
        $DIALOG \
            --info \
            --title "Cancelled" \
            --text "The setting of the password was cancelled." 
        exit
    fi
      
    password1=`cat $tempfilePassword | cut -f1 -d/`
    password2=`cat $tempfileConfirmPassword | cut -f2 -d/`
    if [ "$password1" == "" ] ; then
        $DIALOG \
            --info \
            --title "Password was not set" \
            --text "The password can not be blank." 
      exit
    fi
    if [ "$password1" != "$password2" ] ;  then
        $DIALOG \
            --info \
            --title "Password was not set" \
            --text "You did not type the same password twice." 
      exit
    fi
    sudo usermod -p `echo $password1 | openssl passwd -crypt -stdin -salt '$1'` root
fi

$DIALOG \
    --info \
    --title "Terminal Use Warning" \
    --no-wrap \
    --text \
"You will be prompted to enter the root password to proceed.

Note: this password is not the same as the web interface admin password.
It is set the first time the Terminal is opened.

WARNING:
Changes made via the command line are NOT supported and can seriously interfere with the proper operation of $OEM_NAME.
Changes made via the command line are NOT supported by $OEM_NAME and can severely limit your support options.
It is recommended to disable upgrades if any changes are made.

This feature is for advanced users only." 

${XTERM} -tn rxvt -T ${XTERM} -e su root &
