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
    xLableName="queryType"


if( len(sys.argv)>3 ):
    pngName=sys.argv[3]
else: 
    pngName="test_query.png"

if( len(sys.argv)>4 ):
    queryTimes=sys.argv[4]
else: 
    queryTimes=1000




df = pd.read_csv(inputfile,header=None)  # read file
arrt=np.array(df.T)   #　transpose and  transfer to array
arr=np.array(df)      #　  transfer to array



nshape=arr.shape[0]  # arr rows , arr.shape[1] is column
sortdbformate=np.unique(arrt[0])  # sort db formate 
numformate=int(len(np.unique(arrt[0]))) #sort formate length
numgroup=int(nshape/numformate) # group by db formate

# formate should be sort as "TDengine timescaledb  inlux", the first should be TDengine 
# ratio is ninth column，generate  data except TDengine.TDengine data is numerator db data is denominator
ratio_arr=[]
print(numformate)
if(numformate>1):
    for j in range(1,numformate):
        for i in range(numgroup):  
            k=i+j*numgroup
            ratio=[]
            tempdataTime=100*arr[k][6]/arr[i][6]   
            # tempdataQps=100*arr[i][7]/arr[k][7]   # QPS ratio .if you want to generate times, you should replace 7 with 6
            ratiodataTime=float('%.2f' % tempdataTime ) 
            # ratiodataQps=float('%.2f' % tempdataQps ) 
            ratio.append(ratiodataTime)
            # ratio.append(ratiodataQps)
            # print(i,j,arr[i][7],arr[k][7],ratiodata)
            ratio_arr.append(ratio)
print(ratio_arr)

scaleNum=arrt[3]
scaleLable=list(set(scaleNum))[0]
# print(scaleLable)

new_arr=np.delete(arr,[range(numgroup)],axis=0)  #delete part of  TDengine  data
result_arr=np.append(new_arr,ratio_arr,axis=1)   # add ninth column
resultshape=result_arr.shape[0] # new result arr rows

result_arrt=np.transpose(result_arr)  #　transpose result_arr
result_numformate=int(len(np.unique(result_arrt[0]))) # db formate length

fig=figure(figsize=(12, 12), dpi=300,layout='constrained')    
ax=plt.subplot(1,1,1)
xticks=[]
timescaledbRatio=[]
influxRatio=[]
tdengineRatio=[]
bar_width = 2.5
xinfluxtype=[]
xtimescaletype=[]
xtdenginetype=[]

if (xLableName=="NUM_WORKER"):
    xticks=np.arange(0,int(len(np.unique(result_arrt[5])))*6,6)
elif (xLableName=="QUERY"):
    xticks=np.arange(0,int(len(np.unique(result_arrt[4])))*6,6)
elif (xLableName=="SCALE"):
    xticks=np.arange(0,int(len(np.unique(result_arrt[3])))*6,6)
elif (xLableName=="queryType"):
    xticks=np.arange(0,int(len(np.unique(result_arrt[2])))*6,6)
            
# print(resultshape)
for i in range(resultshape):
    if(result_arr[i][0]=="timescaledb"):
        timescaledbRatio.append(result_arr[i][8])
        if (xLableName=="NUM_WORKER"):
            xtimescaletype.append(result_arr[i][5])
        elif (xLableName=="SCALE"):
            xtimescaletype.append(result_arr[i][3])
        elif (xLableName=="queryType"):
            xtimescaletype.append(result_arr[i][2])
        # print(timescaledbRatio)
    elif(result_arr[i][0]=="influx"):
        influxRatio.append(result_arr[i][8])
        if (xLableName=="NUM_WORKER"):
            xinfluxtype.append(result_arr[i][5])
        elif (xLableName=="SCALE"):
            xinfluxtype.append(result_arr[i][3])
        elif (xLableName=="queryType"):
            xinfluxtype.append(result_arr[i][2])
    elif(result_arr[i][0]=="TDengine"):
        tdengineRatio.append(result_arr[i][8])
        if (xLableName=="NUM_WORKER"):
            xtdenginetype.append(result_arr[i][5])
        elif (xLableName=="SCALE"):
            xtdenginetype.append(result_arr[i][3])
        elif (xLableName=="queryType"):
            xtdenginetype.append(result_arr[i][2])
# print(xticks)
# print(timescaledbRatio)
# print(influxRatio)
# print(result_arrt)
# print(xinfluxtype)

if( "timescaledb" in result_arrt ):
    ax.barh(xticks, timescaledbRatio, height=bar_width, label="timescaledb/TDengine")
    for a,b in zip(xticks,timescaledbRatio):   #柱子上的数字显示
        plt.text(b,a,'%.0f'%b+"%",ha='left',va='center',fontsize=8);
    ax.set_yticks(xticks)
    ax.set_yticklabels(tuple(xtimescaletype))
if( "influx" in result_arrt ):
    ax.barh(xticks+bar_width, influxRatio, height=bar_width, label="influx/TDengine")   
    for a,b in zip(xticks+bar_width,influxRatio):   #柱子上的数字显示
        plt.text(b,a,'%.0f'%b+"%",ha='left',va='center',fontsize=8);
    ax.set_yticks(xticks)
    ax.set_yticklabels(tuple(xinfluxtype))
if( "TDengine" in result_arrt ):
    ax.barh(xticks+2*bar_width, tdengineRatio, height=bar_width, label="TDengine")
    for a,b in zip(xticks+bar_width,tdengineRatio):   #柱子上的数字显示
        plt.text(b,a,'%.0f'%b+"%",ha='left',va='center',fontsize=8);
    ax.set_yticks(xticks)
    ax.set_yticklabels(tuple(xtdenginetype))




ax.invert_yaxis() 
# ax.set_xscale('log')

ax.axvline(100, color='gray', linewidth=2)
# ax.set_xlabel("%s" % xLableName)  # add x lable
# ax.set_ylabel("Query Type")  # add y lable
ax.set_xlabel("spendtime : otherDB/TDengine %")   # add x lable
ax.set_title("QueryComparisons: query response time ratio in different %s on %s device * 10 metrics , the number of queries:%s" % (xLableName,scaleLable,queryTimes),loc='left',fontsize = 8)  # Add a title to the axes.

for i in range(resultshape):
    if(result_arr[i][0]=="timescaledb"):
        xtype=xtimescaletype
    if(result_arr[i][0]=="influx"):
        xtype=xinfluxtype
    if(result_arr[i][0]=="TDengine"):
        xtype=xtdenginetype
        
    
# print(tuple(xtype),xticks)
ax.legend() 
ax.set_yticks(xticks)
ax.set_yticklabels(tuple(xtype))
# ax.set_xticklabels(rotation=70)
# plt.xticks(rotation=45)
plt.savefig('%s'% pngName)
plt.close() 