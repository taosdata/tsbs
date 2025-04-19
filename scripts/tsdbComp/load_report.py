import argparse
import sys
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # sets the backend to a non-interactive one
import matplotlib.pyplot as plt
from matplotlib.pyplot import figure

def parse_args():
    """Parse command line arguments。"""
    parser = argparse.ArgumentParser(description='Generate load ingestion rate charts')
    parser.add_argument('--input', '-i', default='/tmp/bulk_result_query/load_input.csv',
                      help='Input CSV file path')
    parser.add_argument('--xlabel', '-x', default='SCALE',
                      help='X-axis label name')
    parser.add_argument('--output', '-o', default='load_chart.png',
                      help='Output PNG file name')
    parser.add_argument('--targets', '-t', default='metrics',
                      help='Targets for the chart (rows or metrics)')
    parser.add_argument('--mode', '-m', choices=['result', 'ratio', 'diskusage'], default='result',
                      help='Mode: "result" to generate result chart, "ratio" to generate ratio chart, "diskusage" to generate diskusage chart')
    return parser.parse_args()

def load_data(file_path):
    """Load and preprocess data from CSV file。"""
    try:
        df = pd.read_csv(file_path, header=None)
        print(f"Data loaded successfully from {file_path}")
        return df
    except Exception as e:
        print(f"Error loading data from {file_path}: {e}")
        sys.exit(1)

def get_color_map():
    """Return the color map for different database types。"""
    return {
        'TDengine': '#1f77b4',       # Muted blue
        'TDengineStmt2': '#1f77b4',  # Muted blue
        'influx': '#ff7f0e',         # Muted orange
        'influx3': '#2ca02c',        # Muted green
        'timescaledb': '#bcbd22'     # Muted yellow-green
    }

def create_result_chart(df, x_label_name, targets_number, output_file):
    """Create horizontal bar chart showing ingestion rates。"""
    arrt = np.array(df.T)
    arr = np.array(df)
    nshape = arr.shape[0]
    sortdbformate = np.unique(arrt[0])
    numformate = int(len(np.unique(arrt[0])))
    numgroup = int(nshape / numformate)

    fig = figure(figsize=(12, 10), dpi=300, layout='constrained')
    ax = plt.subplot(1, 1, 1)
    xticks = []
    metrics = {}
    bar_width = max(0.8 / numformate, 0.5)  # 自适应宽度，最小宽度为0.3
    xtypes = []

    if x_label_name == "NUM_WORKER":
        xticks = np.arange(0, int(len(np.unique(arrt[4]))) * numformate, numformate)
    elif x_label_name == "BATCH_SIZE":
        xticks = np.arange(0, int(len(np.unique(arrt[3]))) * numformate, numformate)
    elif x_label_name == "SCALE":
        xticks = np.arange(0, int(len(np.unique(arrt[2]))) * numformate, numformate)

    for dbtype in sortdbformate:
        metrics[dbtype] = []

    for i in range(nshape):
        dbtype = arr[i][0]
        metrics[dbtype].append(arr[i][targets_number])
        if x_label_name == "NUM_WORKER":
            xtypes.append("%d workers" % arr[i][4])
        elif x_label_name == "BATCH_SIZE":
            xtypes.append("%d batch size" % arr[i][3])
        elif x_label_name == "SCALE":
            xtypes.append("scale=%d " % arr[i][2])

    color_map = get_color_map()

    for idx, dbtype in enumerate(sortdbformate):
        ax.barh(xticks + idx * bar_width, metrics[dbtype], height=bar_width, label=dbtype, color=color_map.get(dbtype, 'gray'))

    for dbtype in sortdbformate:
        for a, b in zip(xticks + bar_width * sortdbformate.tolist().index(dbtype), metrics[dbtype]):
            ax.text(b, a, '%.0f' % b, ha='left', va='center', fontsize=8)

    plt.style.use('Solarize_Light2')
    plt.grid(axis="x")

    ax.set_xlabel("Metrics ingested per second")
    ax.set_title("Load Comparisons Ingestion Rate in different %s:%s/s" % (x_label_name, global_args.targets))

    ax.invert_yaxis()
    ax.legend()
    ax.set_yticks(xticks + bar_width * (len(sortdbformate) - 1) / 2)
    ax.set_yticklabels(tuple(xtypes[:len(xticks)]))

    plt.savefig('%s' % output_file)
    plt.close()
    print(f"Chart saved to {output_file}")

def create_ratio_chart(df, x_label_name, targets_number, output_file):
    """Create horizontal bar chart showing ingestion rate ratios。"""
    arrt = np.array(df.T)
    arr = np.array(df)
    nshape = arr.shape[0]
    sortdbformate = np.unique(arrt[0])
    numformate = int(len(np.unique(arrt[0])))
    numgroup = int(nshape / numformate)

    tdengine_index = np.where((arrt[0] == 'TDengine') | (arrt[0] == 'TDengineStmt2'))[0]
    if len(tdengine_index) == 0:
        print("No TDengine data found, ratio chart will not be generated.")
        return

    tdengine_index = tdengine_index[0]
    ratios = {f'TDengine/{dbtype}': [] for dbtype in sortdbformate if dbtype != 'TDengine' and dbtype != 'TDengineStmt2'}
    scales = sorted(np.unique(arr[:, 2]))  # 获取所有唯一的 scale 并排序

    for scale in scales:
        tdengine_value = arr[((arr[:, 0] == 'TDengine') | (arr[:, 0] == 'TDengineStmt2')) & (arr[:, 2] == scale)][0][targets_number]
        for dbtype in sortdbformate:
            if dbtype != 'TDengine' and dbtype != 'TDengineStmt2':
                db_values = arr[(arr[:, 0] == dbtype) & (arr[:, 2] == scale)]
                if len(db_values) > 0:
                    ratio = 100 * tdengine_value / db_values[0][targets_number]
                    ratios[f'TDengine/{dbtype}'].append(ratio)

    fig = figure(figsize=(12, 10), dpi=300, layout='constrained')
    ax = plt.subplot(1, 1, 1)
    xticks = np.arange(len(scales))
    bar_width = max(0.8 / (numformate - 1), 0.3)  # 自适应宽度，最小宽度为0.3

    color_map = get_color_map()

    for idx, (dbtype, ratio_values) in enumerate(ratios.items()):
        ax.barh(xticks + idx * bar_width, ratio_values, height=bar_width, label=dbtype, color=color_map.get(dbtype.split('/')[1], 'gray'))

    for dbtype, ratio_values in ratios.items():
        for a, b in zip(xticks + bar_width * list(ratios.keys()).index(dbtype), ratio_values):
            ax.text(b, a, '%.0f' % b + "%", ha='left', va='center', fontsize=8)

    ax.axvline(100, color='red', linewidth=2)
    plt.style.use('Solarize_Light2')
    plt.grid(axis="x")

    ax.set_xlabel("ratios:%")
    ax.set_title("Load Comparisons TDengine vs otherDB Ingestion Rate Ratio(%s/s) in different %s : percent" % (global_args.targets, x_label_name))

    ax.invert_yaxis()
    ax.legend()
    ax.set_yticks(xticks + bar_width * (len(ratios) - 1) / 2)
    ax.set_yticklabels(tuple(scales))

    plt.savefig('%s' % output_file)
    plt.close()
    print(f"Chart saved to {output_file}")

def create_diskusage_chart(df, output_file):
    """Create bar chart showing disk space usage comparison"""
    column_idx = 8  # The column index for disk space usage
    db_types = df[0].unique()
    # 提取横坐标对应字段（第3个字段）的唯一值作为类别
    x_categories = df[2].unique()
    num_db_types = len(db_types)
    num_x_categories = len(x_categories)

    width = 0.2  # 柱子宽度
    ind = np.arange(num_x_categories)  # x轴位置

    fig = figure(figsize=(12, 10), dpi=300, layout='constrained')
    ax = plt.subplot(1, 1, 1)

    color_map = get_color_map()
    for i, db_type in enumerate(db_types):
        db_data = []
        for cat in x_categories:
            subset = df[(df[0] == db_type) & (df[2] == cat)]
            if not subset.empty:
                db_data.append(int(subset.iloc[0, column_idx] / 1024))
            else:
                db_data.append(0)
        ax.bar(ind + i * width, db_data, width, label=db_type, color=color_map.get(db_type, 'gray'))

    # 添加数据标注
    for p in ax.patches:
        height = p.get_height()
        ax.annotate('{}'.format(height),
                    xy=(p.get_x() + p.get_width() / 2, height),
                    xytext=(0, 3),  # 3 points vertical offset
                    textcoords="offset points",
                    ha='center', va='bottom')

    ax.set_ylabel('(MB)')
    ax.set_title('Disk Usage Comparison')
    ax.set_xticks(ind + width * (num_db_types - 1) / 2)
    new_x_categories = [f"{cat} DEVICES" for cat in x_categories]
    ax.set_xticklabels(new_x_categories)
    ax.legend()

    plt.savefig(output_file)
    plt.close()
    print(f"Chart saved to {output_file}")
    
global_args = None

def main():
    global global_args
    global_args = parse_args()

    # check if input file exists
    if not os.path.isfile(global_args.input):
        print(f"Error: Input file {global_args.input} does not exist.")
        sys.exit(1)

    df = load_data(global_args.input)
    if df.empty:
        print("Error: No valid data found in the input file")
        sys.exit(1)
        
    # Check if data from only one database is found
    db_types = df[0].unique()
    if global_args.mode == 'ratio' and len(db_types) == 1:
        print("Only one db data found, ratio chart will not be generated.")
        sys.exit(1)

    if global_args.targets == "rows":
        targets_number = 5
    elif global_args.targets == "metrics":
        targets_number = 7

    if global_args.mode == 'ratio':
        output_file = global_args.output.replace('.png', '_ratio.png')
        create_ratio_chart(df, global_args.xlabel, targets_number, output_file)
    elif global_args.mode == 'diskusage':
        output_file = global_args.output.replace('.png', '_diskusage.png')
        create_diskusage_chart(df, output_file)
    else:
        output_file = global_args.output.replace('.png', '_result.png')
        create_result_chart(df, global_args.xlabel, targets_number, output_file)

    print("Processing complete。")

if __name__ == "__main__":
    main()