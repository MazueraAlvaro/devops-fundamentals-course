#!/usr/bin/env bash

declare orgPipeline=$1
declare newPipeline=""
declare tmpPipeline="tmpPipeline.json"

declare owner=""
declare configuration=""
declare branch="main"
declare pollForSourceChanges="false"

declare hasOptions=false

checkJQisInstalled(){
    if ! [ -x "$(command -v jq)" ]
    then
        echo "Error: The app cannot be built, jq is not installed"
        echo 'jq can be installed using on of the following commands according to your distibution:'
        echo 'yum install jq'
        echo 'apt install jq'
        exit 1
    fi
}

validateFile(){

    if ! [ -f "$orgPipeline" ]
    then
        echo "File $orgPipeline not found"
        exit 1
    fi

    if ! [ $(cat $orgPipeline | jq empty > /dev/null 2>&1; echo $?) -eq 0 ]
    then
        echo "Please provide a valid JSON file"
        exit 1
    fi
}

createNewFile(){
    newPipeline="pipeline-$(date +"%Y-%m-%d").json"
    rm -f $newPipeline
    cp $orgPipeline $newPipeline
    touch $tmpPipeline
}

removeMetadata(){
    jq 'del(.metadata)' $newPipeline > $tmpPipeline
    mv $tmpPipeline $newPipeline
}

incrementVersion(){
    
    jq '.pipeline.version += 1' $newPipeline > $tmpPipeline
    mv $tmpPipeline $newPipeline
}

retrieveAndValidateOptions(){
    options=$(getopt -l "configuration:,owner:,branch:,poll-for-source-changes:" -- "$@" 2> /dev/null)
    eval set -- "$options"

    if [ $# -eq 1 ]
    then
        return
    fi

    while [ $# -gt 0 ]
    do
        case $1 in
        --configuration)
            configuration=$2
            ;;
        --owner)
            owner=$2
            ;;
        --branch)
            branch=$2
            ;;
        --poll-for-source-changes)
            pollForSourceChanges=$2
            ;;
        esac
        shift
    done

    if [ -z $owner ]
    then
        echo "Please provide the option --owner with a value"
        exit 1
    fi

    if [ -z $configuration ]
    then
        echo "Please provide the option --configuration with a value"
        exit 1
    fi

    hasOptions=true
}

validateJSONFileProperties(){
    #Validate version property is present
    if [ $(jq '.pipeline|has("version")' $orgPipeline) = "false" ]
    then
        echo "The 'version' property is not present in the pipeline definition"
        exit 1
    fi

    #If the execution has not options don't validate
    if [ $hasOptions = false ]
    then
        return
    fi

    if [ $(jq '.pipeline.stages[] | select(.name == "Source") | .actions[].configuration | has("Owner")' $orgPipeline) = "false" ]
    then
        echo "The Owner property in the Source action's configuration is not present"
        exit 1
    fi

    if [ $(jq '.pipeline.stages[] | select(.name == "Source") | .actions[].configuration | has("Branch")' $orgPipeline) = "false" ]
    then
        echo "The Branch property in the Source action's configuration is not present"
        exit 1
    fi
    
    if [ $(jq '.pipeline.stages[] | select(.name == "Source") | .actions[].configuration | has("PollForSourceChanges")' $orgPipeline) = "false" ]
    then
        echo "The PollForSourceChanges property in the Source action's configuration is not present"
        exit 1
    fi


}

replaceSourceConfigurationActionProperties(){
    #Replace Owner Branch and PollForSourceChanges
    cat $newPipeline | jq --arg owner "$owner" \
        '(.pipeline.stages[] | select(.name == "Source")).actions[].configuration.Owner |= $owner' | \
        jq --arg branch "$branch" \
        '(.pipeline.stages[] | select(.name == "Source")).actions[].configuration.Branch |= $branch' | \
        jq --arg poll $pollForSourceChanges \
        '(.pipeline.stages[] | select(.name == "Source")).actions[].configuration.PollForSourceChanges |= ( $poll | test("true") )' \
        > $tmpPipeline
    mv $tmpPipeline $newPipeline
}

replaceEnvironmentVariables(){
    cat $newPipeline | jq \
        '(
            (
                ( .pipeline.stages[].actions[].configuration | select( has("EnvironmentVariables") ) )
            ).EnvironmentVariables |= fromjson
        )' | \
        jq --arg configuration "$configuration" \
        '(
            (
                (
                    ( .pipeline.stages[].actions[].configuration | select( has("EnvironmentVariables") ) )
                ).EnvironmentVariables[] | select(.name == "BUILD_CONFIGURATION") 
            ).value |= $configuration
        )' | \
        jq \
        '(
            (
                ( .pipeline.stages[].actions[].configuration | select( has("EnvironmentVariables") ) )
            ).EnvironmentVariables |= tojson
        )' > $tmpPipeline
    mv $tmpPipeline $newPipeline
}

#Get and validate options
retrieveAndValidateOptions $@
#Check if jq is installed
checkJQisInstalled
#Validate if file exists and is a JSON file
validateFile
#Validate the required properties for the proccess are present in the JSON file
validateJSONFileProperties
#Create the output JSON file
createNewFile
#Remove property metadata
removeMetadata
#Increment pipeline verision
incrementVersion

#If there's not options end the script
if [ $hasOptions = false ]
then
    exit 0
fi

#Replace Source configuration action properties
replaceSourceConfigurationActionProperties
#Replace Env vars for BUILD_CONFIGURATION
replaceEnvironmentVariables
