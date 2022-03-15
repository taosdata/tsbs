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
    inputfile="/tmp/bulk_result_load/load_input.csv"


fig_names=[]
xpoints=[]
speed_points=[]
time_points=[]

if( len(sys.argv)>2 ):
    xLableName=sys.argv[2]
else:
    xLableName="NUM_WORKER"

if( len(sys.argv)>3 ):
    pngName=sys.argv[3]
else: 
    pngName="test_load.png"

print("open %s" % inputfile )
if (sys.argv[2]=="NUM_WORKER"):
    with open(inputfile, newline='',encoding = 'utf-8') as csvfile:
        spamreader = csv.reader(csvfile) 
        for row in spamreader:
            fig_name=row[0] + "_" + row[1] + "_" + row[2] + "_" + row[3]
            fig_names.append(fig_name)
            xpoints.append(int(row[4]))
            speed_points.append(float(row[5]))
            time_points.append(float(row[6]))
elif (sys.argv[2]=="BATCH_SIZE"):
    with open(inputfile, newline='',encoding = 'utf-8') as csvfile:
        spamreader = csv.reader(csvfile) 
        for row in spamreader:
            fig_name=row[0] + "_" + row[1] + "_" + row[2] + "_" + row[4]
            fig_names.append(fig_name)
            xpoints.append(int(row[3]))
            speed_points.append(float(row[5]))
            time_points.append(float(row[6]))   
elif (sys.argv[2]=="SCALE"):
    with open(inputfile, newline='',encoding = 'utf-8') as csvfile:
        spamreader = csv.reader(csvfile) 
        for row in spamreader:
            fig_name=row[0] + "_" + row[1] + "_" + row[3] + "_" + row[4]
            fig_names.append(fig_name)
            xpoints.append(int(row[2]))
            speed_points.append(float(row[5]))
            time_points.append(float(row[6]))     




datacount=wc_count(inputfile)
sortlist=list(set(fig_names))
typeCount=len(sortlist)
# fig=figure(num=None, figsize=(40, 7), dpi=300,layout='constrained')    
fig=figure(figsize=(12, 10), dpi=300,layout='constrained')    
ax1=fig.add_subplot(1, 2, 1)    
ax2=fig.add_subplot(1, 2, 2)    

for j  in range(typeCount):
    newxpoints="newxpoint"+str(j)
    newspeed_points="newspeed_points"+str(j)
    newtime_points="newtime_points"+str(j)
    newxpoints=[]
    newspeed_points=[]
    newtime_points=[]
    lab=sortlist[j]
    for i in range(datacount):
        if(fig_names[i]==sortlist[j]):
            newxpoints.append(xpoints[i])
            newspeed_points.append(speed_points[i])
            newtime_points.append(time_points[i])
    ax1.plot(newxpoints,newspeed_points,marker = 'o',label="%s" % lab ) 
    ax1.set_xlabel("%s" % xLableName)  # 添加横轴标签
    ax1.set_ylabel("speed:rows/s")  # 添加纵轴标签
    ax1.set_title("LoadComparisons:%s-speed"% xLableName)  # Add a title to the axes.
    ax1.legend(loc='best')  # 展示图例
    ax2.plot(newxpoints,newtime_points,marker = 'o',label="%s" % lab ) 
    ax2.set_xlabel("%s" % xLableName)  # 添加横轴标签
    ax2.set_ylabel("spendtime:s")  # 添加纵轴标签
    ax2.set_title("LoadComparisons:%s-spendtime"% xLableName)  # Add a title to the axes.
    ax2.legend(loc='best')  # 展示图例

plt.savefig('%s'% pngName)
plt.close()  



# fig2=figure(figsize=(40, 40), dpi=150,layout='constrained')    
# ax21=fig2.add_subplot(1, 2, 1)    
# ax22=fig2.add_subplot(1, 2, 2)    

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
#     ax1.plot(newxpoints,newspeed_points,marker = 'o',label="%s" % lab ) 
#     ax1.set_xlabel("workthread")  # 添加横轴标签
#     # ax1.xaxis.grid(True, which='major')
#     # ax1.set_xticks(minor=False)  # 添加横轴标签
#     ax21.set_ylabel("speed:rows/s)")  # 添加纵轴标签
#     ax21.set_title("LoadComparisons:Worker-speed")  # Add a title to the axes.
#     ax21.legend(loc='best')  # 展示图例
#     ax22.plot(newxpoints,newtime_points,marker = 'o',label="%s" % lab ) 
#     ax22.set_xlabel("workthread")  # 添加横轴标签
#     ax22.set_ylabel("spendtime:s)")  # 添加纵轴标签
#     ax22.set_title("LoadComparisons:Worker-spendtime")  # Add a title to the axes.
#     ax22.legend(loc='best')  # 展示图例
# plt.savefig('test_load.png')
# plt.close()  



# # another way to generate png
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
#     plt.plot(newxpoints,newspeed_points,marker = 'o',label="%s" % lab ) 
#     plt.xlabel("x - workthread")
#     plt.ylabel("y - speed:rows/s")
#     plt.legend(loc='best')
# plt.savefig('test_load_time.png')
