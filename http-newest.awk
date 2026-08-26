#!/usr/bin/gawk -f
{
    match($0, /<a href="([^"]+\.zip[^"]*)">[^<]*<\/a>/, a)
    match($0, /([0-9]{1,2}-[A-Za-z]{3}-[0-9]{4})[[:space:]]+([0-9]{2}:[0-9]{2})/, t)
    
    fn = a[1]
    dt = t[1] " " t[2]

    if (fn != "" && dt != "") {
        # Convert to epoch using GNU date.
        cmd = "date -d \"" dt "\" +%s";
        cmd | getline epoch;
        close(cmd);

        if (epoch ~ /^[0-9]+$/) {
            print epoch, fn
        }
        fn=""; dt=""
    }
}
