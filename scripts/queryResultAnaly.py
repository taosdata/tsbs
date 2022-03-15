import os,sys
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.pyplot import figure
import numpy as np 
import csv
import pandas as pd
import subprocess

def wc_count(file_name):
    out = subprocess.getoutput("wc -l %s" % file_name)
    return int(out.split()[0])

if( len(sys.argv)>1 ):
    inputfile=sys.argv[1]
else:
    inputfile="/tmp/bulk_result_query/query_input.csv"

fig_names=[]
databasetype=[]
querytype=[]
wcltime=[]
qps=[]

if( len(sys.argv)>2 ):
    xLableName=sys.argv[2]
else:
    xLableName="queryType"

if( len(sys.argv)>3 ):
    pngName=sys.argv[3]
else: 
    pngName="test_query.png"

print("open %s" % inputfile )

with open(inputfile, newline='',encoding = 'utf-8') as csvfile:
    spamreader = csv.reader(csvfile) 
    for row in spamreader:
        databasetype.append(row[0])
        querytype.append(row[2])
        wcltime.append(float(row[6]))
        qps.append(float(row[7]))

xticks = np.arange(0,len(set(querytype))*4,4)
print(xticks)
datacount=wc_count(inputfile)
sortlist=list(set(databasetype))
typeCount=len(sortlist)
bar_width = 1
# timescaledb_x=xticks
# influx_x=timescaledb_x+bar_width
fig=figure(figsize=(12, 10), dpi=300,layout='constrained')    
ax=plt.subplot(1,1,1)
# generate data
for j  in range(typeCount):
    timescdb_querytype=[]
    timescdb_wcltime=[]
    timescdb_qps=[]
    influx_querytype=[]
    influx_wcltime=[]
    influx_qps=[]
    for i in range(datacount):
        if(databasetype[i]=="timescaledb"):
            timescdb_querytype.append(querytype[i])
            timescdb_wcltime.append(wcltime[i])
            timescdb_qps.append(qps[i])
        elif(databasetype[i]=="influx"):
            influx_querytype.append(querytype[i])
            influx_wcltime.append(wcltime[i])
            influx_qps.append(qps[i])
    print(tuple(timescdb_querytype))        
ax.bar(xticks, timescdb_wcltime, width=bar_width, label="timescaledb")
ax.bar(xticks+bar_width, influx_wcltime, width=bar_width, label="influx")   
for a,b in zip(xticks,timescdb_wcltime):   #柱子上的数字显示
    plt.text(a,b,'%.2f'%b,ha='center',va='bottom',fontsize=8);
for a,b in zip(xticks+bar_width,influx_wcltime):   #柱子上的数字显示
    plt.text(a,b,'%.2f'%b,ha='center',va='bottom',fontsize=8);

# ax.set_xlabel("%s" % xLableName)  # add x lable
ax.set_ylabel("spendtime:s")  # add y lable
ax.set_title("QueryComparisons:%s-speed"% xLableName)  # Add a title to the axes.
print(tuple(influx_querytype),xticks)
ax.legend() 
ax.set_xticks(xticks)
ax.set_xticklabels(tuple(influx_querytype))
# ax.set_xticklabels(rotation=70)
plt.xticks(rotation=45)
plt.savefig('%s'% pngName)
plt.close()  

        # elif(databasetype[i]=="TDengine"):
             
# for j  in range(typeCount):
#     newxpoints="newxpoint"+str(j)
#     newspeed_points="newspeed_points"+str(j)
#     newtime_points="newtime_points"+str(j)
#     newxpoints=[]
#     newspeed_points=[]
#     newtime_points=[]
#     lab=sortlist[j]
#     for i in range(datacount):
#         if(fig_names[i]==sortlist[j]):
#             newxpoints.append(xpoints[i])
#             newspeed_points.append(speed_points[i])
#             newtime_points.append(time_points[i])
#     ax1.bar(newxpoints,newspeed_points,marker = 'o',label="%s" % lab ) 
#     ax1.set_xlabel("%s" % xLableName)  # add x lable
#     ax1.set_ylabel("speed:rows/s)")  # add y lable
#     ax1.set_title("LoadComparisons:%s-speed"% xLableName)  # Add a title to the axes.
#     ax1.legend(loc='best')  # display  lable and title
#     ax2.plot(newxpoints,newtime_points,marker = 'o',label="%s" % lab ) 
#     ax2.set_xlabel("%s" % xLableName)  # add y lable 
#     ax2.set_ylabel("spendtime:s)")  # add y lable
#     ax2.set_title("LoadComparisons:%s-spendtime"% xLableName)  # Add a title to the axes.
#     ax2.legend(loc='best')  # display 


