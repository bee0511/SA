#!/bin/sh

help="\
hw2.sh -i INPUT -o OUTPUT [-c csv|tsv] [-j]

Available Options:

-i: Input file to be decoded
-o: Output directory
-c csv|tsv: Output files.[ct]sv
-j: Output info.json"

while getopts "i:o:c:j" op 2>/dev/null; do
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

echo input: "$input"
echo output: "$output"

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
    name=$(yq '.name' "${input}" | sed 's/"//g')
    author=$(yq '.author' "${input}" | sed 's/"//g')
    date=$(yq eval '.date' "$input")
    formatted_date=$(awk -v ts="$date" 'BEGIN { cmd="date -d @"ts" --rfc-3339=seconds"; cmd | getline rfc_date; close(cmd); sub(" ", "T", rfc_date); print rfc_date }')
    # json="{\n\t\"name\": \"$name\",\n\t\"author\": \"$author\",\n\t\"date\": \"$formatted_date\"\n}"
    printf "{\n\t\"name\": \"%s\",\n\t\"author\": \"%s\",\n\t\"date\": \"%s\"\n}" "$name" "$author" "$formatted_date" > "${output}/info.json"
    cat "${output}"/info.json
fi

if [ "$xsv_flg" = "tsv" ]; then 
  printf "filename\tsize\tmd5\tsha1\n" > "$output/files.$xsv_flg"
fi

if [ "$xsv_flg" = "csv" ]; then 
  echo  "filename,size,md5,sha1"> "$output/files.$xsv_flg"
fi

file_count=$(yq '.files | length' "$input" |  sed 's/"//g')
ERROR_FILES=0

for i in $(seq 0 $((file_count - 1))); do

    name=$(yq ".files[$i].name" "$input" | sed 's/"//g')
    type=$(yq ".files[$i].type" "$input" |  sed 's/"//g')
    data=$(yq ".files[$i].data" "$input" |  sed 's/"//g')
    md5=$(yq ".files[$i].hash.md5" "$input" |  sed 's/"//g')
    sha_1=$(yq ".files[$i].hash.\"sha-1\"" "$input" |  sed 's/"//g')

    
    echo -------
    echo "Name: $name"
    echo "Type: $type"
    echo "Data: $data"
    echo "MD5: $md5"
    echo "SHA-1: $sha_1"
    echo -------
    file_dir="$output/$name"
    test -f "$file_dir" && rm "$file_dir" # Remove file if it already exists

    mkdir -p "$(dirname "$file_dir")"

    decoded_data=$(echo "$data" | base64 -d)
    echo "$decoded_data" >> "$file_dir"

    size=$(echo "$decoded_data" | wc -c | tr -d ' ')


    if [ "$xsv_flg" = "tsv" ]; then 
    printf "%s\t%d\t%s\t%s\n" "$name" "$size" "$md5" "$sha_1" >> "$output/files.$xsv_flg"
    fi
    if [ "$xsv_flg" = "csv" ]; then 
    echo "$name,$size,$md5,$sha_1" >> "$output/files.$xsv_flg"
    fi

    verify_md5=$(md5sum "$file_dir" | cut -f1 -d " ")
    verify_sha1=$(sha1sum "$file_dir" | cut -f1 -d " ")
    if [ ! "$xsv_flg" ] &&  [ ! "$j_flg" ] && [ "$type" = "hw2" ] ; then
      # The type is "hw2"; recursively run the script on the file
      sh ./hw2.sh -i "$file_dir" -o "$output"
      ERROR_FILES=$((ERROR_FILES+$?))
    fi

    if [ "$md5" != "$verify_md5" ] || [ "$sha_1" != "$verify_sha1" ]; then
        ERROR_FILES=$((ERROR_FILES+1))
        echo Invalid md5 or sha-1: "$file_dir"
    fi

done

# echo The total number of error files: "$ERROR_FILES"
exit $ERROR_FILES
