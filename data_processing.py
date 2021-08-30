from os import scandir


functions_list = open("Functions.txt", "r")                 # Open the functions file
content = []
for line in functions_list:
    tmp = line.strip()
    content.append(tmp)

files = ["data"]          # This list takes in the list of files we want to process
parsed_data_files = [0] * len(files)
for i in range(len(files)):
    parsed_data_files[i] = open(files[i] +".csv", "r")          # Open the .csv file(s) for processing.


function_inclusive = []

# This for loop gets the inclusive/exclusive time for the functions and stores it in a list
for i in range(len(files)):
    tmp = {}
    for line in parsed_data_files[i]:
        line = line.split(",")
        if ".TAU application" in line[3]:
            for j in range(len(content)):
                if content[j] in line[3]:
                    tmp[content[j]] = line[len(line) - 1].strip()
                    # function_inclusive[i][content[j]] = line[len(line) - 1].strip()
                    break
    dictionary_items = tmp.items()
    sorted_items = sorted(dictionary_items)
    function_inclusive.append(sorted_items)

# This code calculates the ratios for each size (128B, 256B, 512B, scalar).
if(len(files) == 4):
    results = []

    for j in range(len(content)):
        tmp = {}
        total = int(function_inclusive[0][j][1]) + int(function_inclusive[1][j][1]) + int(function_inclusive[2][j][1]) + int(function_inclusive[3][j][1])
        res_128B = int(function_inclusive[0][j][1])/int(total)
        res_256B = int(function_inclusive[1][j][1])/int(total)
        res_512B = int(function_inclusive[2][j][1])/int(total)
        res_scalar = int(function_inclusive[3][j][1])/int(total)

        tmp[content[j]] = [res_128B, res_256B, res_512B, res_scalar]
        results.append(tmp)

    print(results)          # A list of dictionaries containing the ratios with the function as the key, and ratios as the value. The values are in the following order: 128B, 256B, 512B, Scalar
else:
    print(function_inclusive)