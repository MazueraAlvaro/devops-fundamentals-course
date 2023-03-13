#!/usr/bin/env bash

declare DB_FILE="users.db"
declare DB_FILE_PATH="$(realpath $(dirname $(realpath "$0"))/../data)"
declare USER_INPUT=""

showHelp(){
   # Display Help
   echo "This script helps you to manage users database."
   echo
   echo "Syntax: db.sh [add|backup|restore|find|list|help]"
   echo "options:"
   echo "add        add a new user to the database."
   echo "backup     create a copy of the database."
   echo "restore    restore the last created database backup."
   echo "find       find a user by username."
   echo "list       Print users, the --inverse option can be provided to show the results in the opposite order."
   echo "help       Print this help."
   echo
}

validateDBFile(){
    if [ ! -f $DB_FILE_PATH/$DB_FILE ]
    then
        declare confirm=""
        while [ "$confirm" != "yes" ] && [ "$confirm" != "no" ] 
        do
            read -p "The db file doesn't exist, please confirm to create it. (yes|no) [yes] " confirm
            if [ -z $confirm ]
            then
                confirm="yes"
            fi
        done
        if [ $confirm = "yes" ]
        then
            mkdir -p $DB_FILE_PATH
            touch $DB_FILE_PATH/$DB_FILE
        else
            exit 1;
        fi
    fi
}

getInput(){
    local input=""
    while [[ ! $input =~ ^[[:alpha:]]+$ ]]
    do
        read -p "$1" input
    done

    USER_INPUT=$input
}

findUser(){
    getInput "Please enter the username: "
    local username=$USER_INPUT
    if grep -Fq "$username," $DB_FILE_PATH/$DB_FILE
    then
        grep "$username," "$DB_FILE_PATH/$DB_FILE" | while read line
        do
            echo "$line"
        done
    else
        echo "User not found"
    fi
    
}

addUser(){
    validateDBFile
    getInput "Please enter the username: "
    local username=$USER_INPUT
    getInput "Please enter the role: "
    local role=$USER_INPUT
    echo "$username, $role" >> $DB_FILE_PATH/$DB_FILE
    echo "User $username added to database succesfully"
}

listUsers(){
    local inverse=$(getopt -l "inverse" "$@")
    eval set -- "$inverse"
    if [ $1 = "--inverse" ]
    then
        cat --number $DB_FILE_PATH/$DB_FILE | tac
    else
        cat --number $DB_FILE_PATH/$DB_FILE
    fi

}

backupDb(){
    local backupFile="$(date +"%Y-%m-%d")-$DB_FILE.backup"
    cp  $DB_FILE_PATH/$DB_FILE  $DB_FILE_PATH/$backupFile;
    echo "Database with name $backupFile created successfully."
}

restoreDb(){
    local backupFile="$(ls $DB_FILE_PATH/*-$DB_FILE.backup 2> /dev/null | sort | tail -1)"
    if [ -z $backupFile ]
    then
        echo "No backup file found"
    else
        cat $backupFile > $DB_FILE_PATH/$DB_FILE
        echo "Backup file $backupFile restored successfully"
    fi
}

case $1 in
    help)       showHelp;;
    add)        addUser;;
    backup)     backupDb;;
    restore)    restoreDb;;
    find)       findUser;;
    list)       listUsers "$@";;
    *)          showHelp;;
esac 