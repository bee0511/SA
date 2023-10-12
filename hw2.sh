#!/bin/sh

help="\
hw2.sh -i INPUT -o OUTPUT [-c csv|tsv] [-j]

Available Options:

-i: Input file to be decoded
-o: Output directory
-c csv|tsv: Output files.[ct]sv
-j: Output info.json"

while getopts "i:o:c:j" op; do
  case $op in
    i)
      input=$OPTARG
      ;;
    o)
      output=$OPTARG
      ;;
    c)
      xsv_flg=$OPTARG
      ;;
    j)
      j_flg=1
      ;;
    *)
      >&2 echo "$help"
      exit 255
  esac
done

if [ ! "${input}" ] || [ "${input}" != "${input%.hw2}.hw2" ]; then
  >&2 echo "Input file must end with .hw2 ($input)"
  >&2 echo "$help"
  exit 255
fi

mkdir -p "${output}"
if [ ! "${output}" ] || [ ! -d "${output}" ]; then
  >&2 echo "Output is not a directory ($output)"
  >&2 echo "$help"
  exit 255
fi

if [ "$j_flg" ]; then
    name=$(yq eval '.name' "${input}")
    author=$(yq eval '.author' "${input}")
    date=$(yq eval '.date' "${input}")
    formatted_date=$(date -d "@$date" "+%Y-%m-%d %H:%M:%S")
    json="{\"name\": \"$name\", \"author\": \"$author\", \"date\": \"$formatted_date\"}"
    echo "$json" > "${output}/info.json"
fi

if [ "$XSV" ]; then
    if [ "$XSV" = "tsv" ]; then XSVSPL='\t'; fi
    if [ "$XSV" = "csv" ]; then XSVSPL=','; fi
    echo "filename${XSVSPL}size${XSVSPL}md5${XSVSPL}sha1" > "$output/files.$XSV"
fi

file_count=$(yq eval '.files | length' "$input")

for i in $(seq 0 $((file_count - 1))); do
    name=$(yq eval ".files[$i].name" "$input")
    type=$(yq eval ".files[$i].type" "$input")
    data=$(yq eval ".files[$i].data" "$input")
    md5=$(yq eval ".files[$i].hash.md5" "$input")
    sha_1=$(yq eval ".files[$i].hash.sha-1" "$input")

    echo "File $i:"
    echo "Name: $name"
    echo "Type: $type"
    echo "Data: $data"
    echo "MD5: $md5"
    echo "SHA-1: $sha_1"
done