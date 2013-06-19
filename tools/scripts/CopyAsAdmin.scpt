on run argv
set shellScript to "open -W copyhelper:" & item 1 of argv & " > /dev/null 2>&1 &"
do shell script shellScript
end run