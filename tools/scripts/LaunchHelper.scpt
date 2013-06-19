on run argv
tell application "System Events"
    if not (exists process "CopyHelper") then
        set shellScript to item 1 of argv & " > /dev/null 2>&1 &"
        do shell script shellScript with administrator privileges
--repeat 3 times
--            if not (exists process "CopyHelper") then
--                delay 1
--            end if
--        end repeat
    end if

end tell
end run