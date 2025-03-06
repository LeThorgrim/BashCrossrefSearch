#!/bin/bash

# https://github.com/LeThorgrim/BashCrossrefSearch

echo -e "\e[31mWelcome to the Crossref search tool!\e[0m"
echo "By Thorgrim"
echo -e "github.com/LeThorgrim/BashCrossrefSearch\n"

#verifications of dependancies (basicly search in "PLUGS" what plugins we dont have) (needs to be put manually tho)
PLUGS=("curl" "jq" "fzf")

for cmd in "${PLUGS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error : $cmd not installed: sudo apt install $cmd"
        exit 1
    fi
done

#search choice by the user + stylisation
echo -e "\e[31mChoose how to search :\e[0m"
echo "1/ By title"
echo "2/ By autor"
echo "3/ By DOI"
read -p "Your choice (1/2/3) : " choice

#query
case "$choice" in
    1)  read -p "Enter the title's keyword: " query
        query=$(echo "$query" | sed 's/ /%20/g')  # Replace spaces with %20 (spaces are a problem if not)
        url="https://api.crossref.org/works?query=$query" ;;
    2)  read -p "Enter the author's name: " query
        query=$(echo "$query" | sed 's/ /%20/g')  # Replace spaces with %20 (spaces are a problem if not)
        url="https://api.crossref.org/works?query.author=$query" ;;
    3)  read -p "Enter the article's DOI: " query
        query=$(echo "$query" | sed 's/ /%20/g')  # Replace spaces with %20 (spaces are a problem if not)
        url="https://api.crossref.org/works/$query" ;;
    *)  echo "Invalid choice."; 
        exit 1 ;;
esac
#result
echo -e "\e[31mWait for the result...\e[0m\n" #might take some time
response=$(curl -s "$url")

# if by DOI, simply have to get it (only one item will be returned by API)
if [ "$choice" -eq 3 ]; then
    selected_json="$response"
# else we have to use fzf to select
else
    # check if result > 0
    if [ "$(echo "$response" | jq '.message.items | length')" -eq 0 ]; then
        echo "No results found."
        exit 1
    fi

    #we show only 20 first items (it's the maximum that the API sends anyway)
    selected_json=$(echo "$response" | jq -r '.message.items[:20] | map({title: (.title[0] // "Unknown Title"), doi: .DOI}) | .[] | "\(.title) (\(.doi))"' | fzf)
    #extract chosen item's DOI
    selected_doi=$(echo "$selected_json" | awk -F'(' '{print $NF}' | tr -d ')')
    #selected DOI get's us selected json
    selected_json=$(curl -s "https://api.crossref.org/works/$selected_doi")
fi

#print of the json 
echo -e "\e[32mHere is the result:\e[0m"
echo "$selected_json" | jq '{
    "Title": (.message.title[0] // "not available"),
    "Volume": (.message.volume // "not available"),
    "URL": (.message.URL // "not available"),
    "DOI": (.message.DOI // "not available"),
    "Article-s Number": (.message.issue // "not available"),
    "Article-s Pages": (.message.page // "not available"),
    "Journal": (.message["container-title"][0] // "not available"),
    "Publisher": (.message.publisher // "not available"),
    "Author List": (if .message.author then 
        [.message.author[] | {Surname: (.family // "not available"), Name: (.given // "not available")}] 
    else 
        "not available" 
    end),
    "Year of publication": (.message.issued["date-parts"][0][0] | tostring // "not available"),

    # BibTeX Key (last name of first author + year in lowercase) (im not sure if it is the way to do it)
    # not sure why but didnt worked if : if else not in line
    "BibTeX Key": (
        (if .message.author then (.message.author[0].family // "unknown") else "unknown" end) +
        (if .message.issued then (.message.issued["date-parts"][0][0] | tostring) else "yyyy" end) #tbf the else is useless because of tostring
    ) | ascii_downcase
    #there are many articles without author or year of publication, so a lot of bibtex key are unusable
}'
