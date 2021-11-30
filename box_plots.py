import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import sys

fileName = sys.argv[1]
f = open(fileName + '.csv', "r")
l = []
tmp = []
for line in f:
    line = line.strip()
    if line != 'Exclusive':
        line = int(line)
        tmp.append(line)
    else:
        l.append(tmp)
        tmp = []
l.append(tmp)
del l[0]

# dic = {'OpenMP GCC': l[0],'OpenMP ICC': l[1], 'TBB GCC': l[2], 'TBB ICC': l[3]}
dic = {'TBB GCC': l[0]}

df = pd.DataFrame(dic)
length = len(df)

# print(df['OpenMP GCC'].quantile([0.25,0.5,0.75]))
# print(df['OpenMP ICC'].quantile([0.25,0.5,0.75]))
# print(df['TBB GCC'].quantile([0.25,0.5,0.75]))
# print(df['TBB ICC'].quantile([0.25,0.5,0.75]))

sns.boxplot(x="variable", y="value", data=pd.melt(df))

data = fileName.split('_')
functionName = data[len(data) - 1]
counterName = data[len(data) - 3] + '_' + data[len(data) - 2]



plt.ylim(0, 800000)
plt.ylabel('Time (msec)', fontsize=8)
plt.xlabel('Mode and Compiler', fontsize=8)
plt.title(str(length) + ' Threads - ' + functionName)
plt.savefig('Plots/' + str(length) + ' Threads - ' + functionName)

# plt.title(str(length) + ' Threads - ' + counterName + ' - ' + functionName)
# plt.savefig('Plots/' + str(length) + ' Threads - ' + counterName + ' - ' + functionName)
