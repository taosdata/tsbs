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

if( len(sys.argv)>4 ):
    targets=sys.argv[4]
else: 
    targets="metrics"

if (targets=="rows"):
    targets_number=5
elif (targets=="metrics"):
    targets_number=7

df = pd.read_csv(inputfile,header=None)  # read file
arrt=np.array(df.T)
arr=np.array(df)



nshape=arr.shape[0]  # arr rows , arr.shape[1] is column
sortdbformate=np.unique(arrt[0])  # sort db formate 
numformate=int(len(np.unique(arrt[0]))) #sort formate length
numgroup=int(nshape/numformate) # group by db formate
print(sortdbformate,numformate,numgroup)

ratio_arr=[]
# print(numformate)
if(numformate>1):
    for j in range(1,numformate):
        for i in range(numgroup):
            k=i+j*numgroup
            ratio=[]
            # if(arr[i][5]>arr[k][5]):
            #     ratio.append(100*arr[i][5]/arr[k][5])
            # elif(arr[i][5]<arr[k][5]):
            #     ratio.append(100*-arr[k][5]/arr[i][5])
            ratio.append(100*arr[i][targets_number]/arr[k][targets_number])
            # print(arr[i][5],arr[k][5],arr[i][5]/arr[k][5])
            # ratio.append(arr[i][5]/arr[k][5])
            # ratio.append(format(arr[i][5]*100/arr[k][5],'.1f'))
            ratio_arr.append(ratio)
else:
    print("result file has only one DB formate, so it can't generate ratio picture ")
    exit()

# print(ratio_arr)

new_arr=np.delete(arr,[range(numgroup)],axis=0)
# print(new_arr)
result_arr=np.append(new_arr,ratio_arr,axis=1)
resultshape=result_arr.shape[0]
# print(result_arr)
result_arrt=np.transpose(result_arr)
result_numformate=int(len(np.unique(result_arrt[0])))

fig=figure(figsize=(12, 10), dpi=300,layout='constrained')    
ax=plt.subplot(1,1,1)
xticks=[]
timescaledbRatio=[]
influxRatio=[]
tdengineRatio=[]
bar_width = 0.5
xinfluxtype=[]
xtimescaletype=[]
xtdenginetype=[]
# timescaledb_scale=[]
# timescaledb_batch=[]
# timescaledb_worker=[]
# influx_scale=[]
# influx_batch=[]
# influx_worker=[]


if (xLableName=="NUM_WORKER"):
    xticks=np.arange(0,int(len(np.unique(result_arrt[4])))*2,2)
elif (xLableName=="BATCH_SIZE"):
    xticks=np.arange(0,int(len(np.unique(result_arrt[3])))*2,2)
elif (xLableName=="SCALE"):
    xticks=np.arange(0,int(len(np.unique(result_arrt[2])))*2,2)
            
print(resultshape)
for i in range(resultshape):
    if(result_arr[i][0]=="timescaledb"):
        timescaledbRatio.append(result_arr[i][-1])
        if (xLableName=="NUM_WORKER"):
            xtimescaletype.append("%d  devices x 10 metrics" % result_arr[i][4])
        elif (xLableName=="BATCH_SIZE"):
            xtimescaletype.append("%d  devices x 10 metrics" % result_arr[i][3])
        elif (xLableName=="SCALE"):
            xtimescaletype.append("%d  devices x 10 metrics" % result_arr[i][2])
        print(timescaledbRatio)
    elif(result_arr[i][0]=="influx"):
        influxRatio.append(result_arr[i][-1])
        if (xLableName=="NUM_WORKER"):
            xinfluxtype.append(result_arr[i][4])
        elif (xLableName=="BATCH_SIZE"):
            xinfluxtype.append(result_arr[i][3])
        elif (xLableName=="SCALE"):
            xinfluxtype.append(result_arr[i][2])
    elif(result_arr[i][0]=="TDengine"):
        tdengineRatio.append(result_arr[i][-1])
        if (xLableName=="NUM_WORKER"):
            xtdenginetype.append(result_arr[i][4])
        elif (xLableName=="BATCH_SIZE"):
            xtdenginetype.append(result_arr[i][3])
        elif (xLableName=="SCALE"):
            xtdenginetype.append(result_arr[i][2])
print(xticks)
# print(timescaledbRatio)
print(influxRatio)
# print(result_arrt)

if( "timescaledb" in result_arrt ):
    ax.barh(xticks, timescaledbRatio, height=bar_width, label="TDengine/timescaledb")
if( "influx" in result_arrt ):
    ax.barh(xticks+bar_width, influxRatio, height=bar_width, label="TDengine/influx")   
if( "TDengine" in result_arrt ):
    ax.barh(xticks+2*bar_width, tdengineRatio, height=bar_width, label="TDengine")


for a,b in zip(xticks,timescaledbRatio):   #柱子上的数字显示
    ax.text(b,a,'%.0f'%b+"%",ha='left',va='center',fontsize=8);
for a,b in zip(xticks+bar_width,influxRatio):   #柱子上的数字显示
    ax.text(b,a,'%.0f'%b+"%",ha='left',va='center',fontsize=8);

ax.axvline(100, color='red', linewidth=2)
plt.style.use('Solarize_Light2')
plt.grid(axis="x")

# ax.set_xlabel("%s" % xLableName)  # add x lable
ax.set_xlabel("ratios:%")  # add y lable
# ax.set_ylabel("%s" % xLableName)  # 添加横轴标签
ax.set_title("LoadComparisons TDengine/otherDB Ingestion Rate Ratio(%s/s) in different %s : percent "% (targets,xLableName),loc='left',fontsize = 12)  # Add a title to the axes.
# ax.set_title("QueryComparisons :TDengine/otherDB QPS ratios in different %s "% xLableName)  # Add a title to the axes.

# for i in range(resultshape):
#     if(result_arr[i][0]=="timescaledb"):
#         xtype=xtimescaletype
#     if(result_arr[i][0]=="influx"):
#         xtype=xinfluxtype
#     if(result_arr[i][0]=="TDengine"):
#         xtype=xtdenginetype

xtype=xtimescaletype
ax.invert_yaxis() 
print(tuple(xtype),xticks)
ax.legend() 
ax.set_yticks(xticks)
ax.set_yticklabels(tuple(xtype))

# ax.set_xticklabels(rotation=70)
# plt.yticks(rotation=45)
plt.savefig('%s'% pngName)
plt.close() 