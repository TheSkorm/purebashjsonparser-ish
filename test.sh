#!/bin/bash
declare -a path #this stores where we are in the tree
declare -a path_type

string_buffer=""
last_key=""


exec 5<>/dev/tcp/query.yahooapis.com/80
echo -e "GET /v1/public/yql?q=select%20*%20from%20weather.forecast%20where%20woeid%20in%20(select%20woeid%20from%20geo.places(1)%20where%20text%3D%22nome%2C%20ak%22)&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys HTTP/1.1\nHost:query.yahooapis.com\n" >&5


function print_path {
    print_path=""
    for a in "${path_type[@]}"; do print_path+="->$a"; done
    echo "[PATH] root$print_path"
}

function print_path_data {
    print_path=""
    for a in "${path[@]}"; do print_path+="->$a"; done
    echo "[DATA] root$print_path=$1"
}

function clear_string_buffer {

        # check for values that are ints
    index=("${!path_type[@]}");
    last_elm=${path_type[${index[@]: -1}]}
    if [ "$last_elm" == 'value-expected' ] 
    then
        string_value_clean="$(echo -e "${string_value}" | tr -d '[:space:]')"
        # echo "[STRING CLEAN] $string_value_clean"
        string_value_len=${#string_value_clean}
        if (( $string_value_len > 0 ))
        then
            remove_type=path_type[index]
            unset 'path_type[${index[@]: -1}]';
            print_path
            echo "**1 [$last_elm] $string_value"
            if [ "$last_elm" == 'key' ]
            then
                path[${index[@]: -1}]="$string_value"
            elif [ "$last_elm" == 'value-expected' ]
            then
                print_path_data $string_value
            fi
            string_value=""
        fi
    fi

    #clear the value type if it's active
    index=("${!path_type[@]}");
    last_elm=${path_type[${index[@]: -1}]}
    if [ "$last_elm" == 'value-expected' ]
    then
        # echo $string_buffer
        string_buffer=""
        remove_type=path_type[index]
        unset 'path_type[${index[@]: -1}]';                    
    fi


    #clear the value type if it's active
    index=("${!path_type[@]}");
    last_elm=${path_type[${index[@]: -1}]}
    if [ "$last_elm" == 'value' ]
    then
        # echo $string_buffer
        string_buffer=""
        remove_type=path_type[index]
        unset 'path_type[${index[@]: -1}]';                    
    fi

    #clear the value type if it's active
    index=("${!path_type[@]}");
    last_elm=${path_type[${index[@]: -1}]}
    if [ "$last_elm" == 'key' ] 
    then
        # echo $string_buffer
        string_buffer=""
        remove_type=path_type[index]
        unset 'path_type[${index[@]: -1}]';                    
    fi

    #expect more from the array
    index=("${!path_type[@]}");
    last_elm=${path_type[${index[@]: -1}]}
    if [ "$last_elm" == 'array' ] 
    then
        path_type+=("value-expected")                
    fi
    
}

while read p; do #loop through each line (easier to debug)
    for (( i=0; i<${#p}; i++ )); do # loop through each char
        current_char="${p:$i:1}"
        #echo $current_char
        # TODO check if we need to check for escapped chars and skip over if required

        case "$current_char" in
            "{")
                clear_string_buffer
                path_type+=("object")
            ;;
            "}")
                clear_string_buffer
                index=("${!path_type[@]}");
                remove_type=path_type[index]
                unset 'path_type[${index[@]: -1}]';
            ;;
            "[")
                clear_string_buffer
                path_type+=("array")
                path_type+=("value-expected")
            ;;
            "]")
                index=("${!path_type[@]}");
                remove_type=path_type[index]
                unset 'path_type[${index[@]: -1}]';
            ;;
            "\"")
                index=("${!path_type[@]}");
                last_elm=${path_type[${index[@]: -1}]}
                if [ "$last_elm" == 'key' ] || [ "$last_elm" == 'value' ] #if the last thing in our path_type was a value but we found an object we want to delete the value out - we should probably error handle this instead
                then
                    remove_type=path_type[index]
                    unset 'path_type[${index[@]: -1}]';
                    echo "**2 [$last_elm] $string_value"
                    if [ "$last_elm" == 'key' ]
                    then
                        path[${index[@]: -1}]="$string_value"
                    elif [ "$last_elm" == 'value' ]
                    then
                        print_path_data $string_value
                    fi
                    string_value=""
                elif [ "$last_elm" == 'value-expected' ]
                then
                    clear_string_buffer                  
                    path_type+=("value")
                    string_value=""
                else
                    path_type+=("key")
                    string_value=""
                fi
            ;;
            ",")
                clear_string_buffer
            ;;
            ":")
                clear_string_buffer
                path_type+=("value-expected")
            ;;


            *)

                                
                # echo $current_char
                string_value+="$current_char"
                string_buffer+=$current_char




                #echo "unkown token" 
                #TODO check if we are in a string or value and add it to the buffer
                #TODO check if it's white space and ignore
                ;;
        esac
        #print_path
    done
    echo "[SOURCE] $p"
done <&5 

