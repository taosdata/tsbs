import os,sys
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.pyplot import figure
import numpy as np 
import csv
import pandas as pd
import subprocess

if( len(sys.argv)>1 ):
    inputfile=sys.argv[1]
else:
    inputfile="/tmp/bulk_result_query/query_input.csv"

if( len(sys.argv)>2 ):
    xLableName=sys.argv[2]
else:
    xLableName="NUM_WORKER"


if( len(sys.argv)>3 ):
    pngName=sys.argv[3]
else: 
    pngName="test_query.png"


df = pd.read_csv(inputfile,header=None)  # read file
arrt=np.array(df.T)   #　transpose and  transfer to array
arr=np.array(df)      #　  transfer to array


nshape=arr.shape[0]  # arr rows , arr.shape[1] is column
sortdbformate=np.unique(arrt[0])  # sort db formate 
numformate=int(len(np.unique(arrt[0]))) #sort formate length
numgroup=int(nshape/numformate) # group by db formate


fig=figure(figsize=(12, 10), dpi=300,layout='constrained')    
ax=plt.subplot(1,1,1)
xticks=[]
timescaledbMetrics=[]
influxMetrics=[]
tdengineMetrics=[]
bar_width = 0.5
xinfluxtype=[]
xtimescaletype=[]
xtdenginetype=[]

if (xLableName=="NUM_WORKER"):
    xticks=np.arange(0,int(len(np.unique(arrt[4])))*2,2)
elif (xLableName=="BATCH_SIZE"):
    xticks=np.arange(0,int(len(np.unique(arrt[3])))*2,2)
elif (xLableName=="SCALE"):
    xticks=np.arange(0,int(len(np.unique(arrt[2])))*2,2)
            
print(nshape)
for i in range(nshape):
    if(arr[i][0]=="timescaledb"):
        timescaledbMetrics.append(arr[i][7])
        if (xLableName=="NUM_WORKER"):
            xtimescaletype.append("%d  devices x 10 metrics" % arr[i][4])
        elif (xLableName=="BATCH_SIZE"):
            xtimescaletype.append("%d  devices x 10 metrics" % arr[i][3])
        elif (xLableName=="SCALE"):
            xtimescaletype.append("%d  devices x 10 metrics" % arr[i][2])
        # print(timescaledbMetrics)
    elif(arr[i][0]=="influx"):
        influxMetrics.append(arr[i][7])
        if (xLableName=="NUM_WORKER"):
            xinfluxtype.append(arr[i][4])
        elif (xLableName=="BATCH_SIZE"):
            xinfluxtype.append(arr[i][3])
        elif (xLableName=="SCALE"):
            xinfluxtype.append(arr[i][2])
    elif(arr[i][0]=="TDengine"):
        tdengineMetrics.append(arr[i][7])
        if (xLableName=="NUM_WORKER"):
            xtdenginetype.append(arr[i][4])
        elif (xLableName=="BATCH_SIZE"):
            xtdenginetype.append(arr[i][3])
        elif (xLableName=="SCALE"):
            xtdenginetype.append(arr[i][2])
print(xticks)
print(timescaledbMetrics)
print(influxMetrics)
print(timescaledbMetrics)
print(arrt)

if( "influx" in arrt ):
    ax.barh(xticks+2*bar_width, influxMetrics, height=bar_width, label="influx")
if( "timescaledb" in arrt ):
    ax.barh(xticks+bar_width, timescaledbMetrics, height=bar_width, label="timescaledb")     
if( "TDengine" in arrt ):
    ax.barh(xticks, tdengineMetrics, height=bar_width, label="TDengine")


for a,b in zip(xticks+bar_width*2,influxMetrics):   #柱子上的数字显示
    ax.text(b,a,'%.0f'%b,ha='left',va='center',fontsize=8);
for a,b in zip(xticks+bar_width,timescaledbMetrics):   #柱子上的数字显示
    ax.text(b,a,'%.0f'%b,ha='left',va='center',fontsize=8);
for a,b in zip(xticks,tdengineMetrics):   #柱子上的数字显示
    ax.text(b,a,'%.0f'%b,ha='left',va='center',fontsize=8);

# ax.axvline(100, color='gray', linewidth=2)
plt.style.use('Solarize_Light2')
plt.grid(axis="x")

# ax.set_xlabel("%s" % xLableName)  # add x lable
ax.set_xlabel("Metrics ingested per second")  # add x lable
# ax.set_ylabel("%s number * 10 metrics" % xLableName)  #add y lable
ax.set_title("LoadComparisons Ingestion Rate in different %s:Metrics/s"% xLableName)  # Add a title to the axes.
# ax.set_title("QueryComparisons :TDengine/otherDB QPS ratios in different %s "% xLableName)  # Add a title to the axes.

# for i in range(nshape):
#     if(arr[i][0]=="timescaledb"):
#         xtype=xtimescaletype
#     if(arr[i][0]=="influx"):
#         xtype=xinfluxtype
#     if(arr[i][0]=="TDengine"):
#         xtype=xtdenginetype

xtype=xtimescaletype

ax.invert_yaxis() 
print(tuple(xtype),xticks+bar_width)
ax.legend() 
ax.set_yticks(xticks+bar_width)
ax.set_yticklabels(tuple(xtype))

# ax.set_xticklabels(rotation=70)
# plt.yticks(rotation=45)
plt.savefig('%s'% pngName)
plt.close() 