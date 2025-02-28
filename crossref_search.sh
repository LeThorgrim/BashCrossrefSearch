#!/bin/bash

#verifications of dependancies
PLUGS=("curl" "jq" "fzf")

for cmd in "${PLUGS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error : $cmd not installed: sudo apt install $cmd"
        exit 1
    fi
done

#search choice by the user
echo "Choose how to search :"
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
response=$(curl -s "$url")

# if by DOI, simply have to get it (only one item will be returned by API)
if [ "$choice" -eq 3 ]; then
    selected_json="$response"
# else we have to use fzf to select
else
    #we show only 30 first items (to long if +)
    selected_json=$(echo "$response" | jq -r '.message.items[:30] | map({title: (.title[0] // "Titre inconnu"), doi: .DOI}) | .[] | "\(.title) (\(.doi))"' | fzf)
    #extract chosen item's DOI
    selected_doi=$(echo "$selected_json" | awk -F'(' '{print $NF}' | tr -d ')')
    #selected DOI get's us selected json
    selected_json=$(curl -s "https://api.crossref.org/works/$selected_doi")
fi

#print of the json 
echo "$selected_json" | jq -r '

.message.items[0] // . |
"Titre: \((.title | if . then .[0] else "Non disponible" end))
DOI: \(.DOI // "Non disponible")
URL: \(.URL // "Non disponible")
Éditeur: \(.publisher // "Non disponible")
Auteurs: \((.author // []) | map("\(.given // "Inconnu") \(.family // "Inconnu")") | join(", "))
Année de publication: \((.issued."date-parts"[0][0] | if . then . else "Non disponible" end))"
'
