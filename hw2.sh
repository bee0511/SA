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

if [ "$xsv_flg" ]; then
    if [ "$xsv_flg" = "tsv" ]; then XSVSPL='\t'; fi
    if [ "$xsv_flg" = "csv" ]; then XSVSPL=','; fi
    echo "filename${XSVSPL}size${XSVSPL}md5${XSVSPL}sha1" > "$output/files.$xsv_flg"
fi

file_count=$(yq eval '.files | length' "$input")
error_files=0
for i in $(seq 0 $((file_count - 1))); do
    name=$(yq eval ".files[$i].name" "$input")
    type=$(yq eval ".files[$i].type" "$input")
    data=$(yq eval ".files[$i].data" "$input")
    md5=$(yq eval ".files[$i].hash.md5" "$input")
    sha_1=$(yq eval ".files[$i].hash.sha-1" "$input")

    file_dir="$output/$name"
    mkdir -p "$(dirname "$file_dir")"

    decoded_data=$(echo "$data" | base64 -d)
    echo "$decoded_data" >> "$file_dir"

    size=$(echo "$decoded_data" | wc -c | tr -d ' ')
    
    if [ "$XSVSPL" ]; then
      echo "$name${XSVSPL}$size${XSVSPL}$md5${XSVSPL}$sha_1" >> "$output/files.$xsv_flg"
    fi
    # echo "File $i:"
    # echo "Name: $name"
    # echo "Type: $type"
    # echo "Data: $data"
    # echo "MD5: $md5"
    # echo "SHA-1: $sha_1"
    # echo "Decoded data: $decoded_data"
    # echo "Size: $size"
    echo "file_dir: $file_dir"
    verify_md5=$(md5sum "$file_dir" | cut -f1 -d " ") 
    verify_sha1=$(sha1sum "$file_dir" | cut -f1 -d " ") 
    # echo verify_md5: "$verify_md5", md5: "$md5"
    # echo verify_sha1: "$verify_sha1", sha1: "$sha_1"
    if [ "$md5" != "$verify_md5" ] || [ "$sha_1" != "$verify_sha1" ]; then
        # rm "$file_dir"
        error_files=$((error_files+1))
        echo "$file_dir"
    fi
done

exit $error_files