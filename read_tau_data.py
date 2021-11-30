#!/usr/bin/env python3

import sys
from tau_profile_parser import TauProfileParser
import pandas

def getFunction( fn ):
    fd = open( fn, 'r' )
    lines = []
    for name in fd:
        lines.append(name.strip())
    fd.close()
    return lines

def getTime( fun, pd ):
    profile = TauProfileParser.parse( pd )
#    df = profile.interval_data().loc[0,0,1:,fun] # remove the header
    df = profile.interval_data().loc[0,0,0:,fun] 
    time = df[ 'Inclusive' ].max() # This should be fine
    return time

def getData( ff, pd ):
    functionname = getFunction( ff )
    time = []
    for function in functionname:
        time_temp = getTime( function, pd )
        time.append(time_temp)
    return time

def main():
    if len( sys.argv ) < 2:
        print( "Please provide the file containing the function name" )
        print( "and the path to the directory containing the profile files (optional)" )
        return
    if len( sys.argv ) == 2:
        profiledir = "."
    else:
        profiledir = sys.argv[2]
    filename = sys.argv[1]
    
    time = getData( filename, profiledir )
    print( "time: ", time )

    return

if __name__ == "__main__":
    main()